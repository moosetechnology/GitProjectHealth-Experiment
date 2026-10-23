"
I am a ZnClient that records every exchange in a GPHApiCallRecorder.

- #execute is one logical request; #executeRequestResponse is one real exchange (attempt).
- I retry at most #numberOfRetries times on timeout, network error or 5xx answers, tagging each retry with its reason (#timeout #network #http5xx #connectionReuse #rateLimit).
- On a rate-limited answer (403/429 with X-RateLimit-Remaining: 0 or Retry-After) I wait until X-RateLimit-Reset + 5 s through the injected clock, record the wait, and replay the request once.
- Statuses >= 400 that are not tolerated are recorded as unexpected errors.

I never read nor record request headers (they hold the token).
"
Class {
	#name : 'GPHInstrumentedZnClient',
	#superclass : 'ZnClient',
	#instVars : [
		'recorder',
		'clock',
		'normalizer',
		'logicalId',
		'attempt',
		'pendingRetryReason',
		'failedOnReusedConnection'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'accessing' }
GPHInstrumentedZnClient class >> defaultRateLimitWaitSeconds [
	"Wait used when Retry-After cannot be read and X-RateLimit-Reset is missing."

	^ 60
]

{ #category : 'accessing' }
GPHInstrumentedZnClient class >> rateLimitHeaderNames [

	^ #( 'X-RateLimit-Limit' 'X-RateLimit-Remaining'
	     'X-RateLimit-Used' 'X-RateLimit-Reset' 'X-RateLimit-Resource' )
]

{ #category : 'accessing' }
GPHInstrumentedZnClient class >> resetMarginSeconds [

	^ 5
]

{ #category : 'accessing' }
GPHInstrumentedZnClient class >> toleratedNotFoundEndpoints [

	^ #( 'commits/:sha' 'users/:login' )
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> beginLogicalRequest [

	logicalId := recorder nextLogicalId.
	attempt := 0.
	pendingRetryReason := nil.
	failedOnReusedConnection := false
]

{ #category : 'accessing' }
GPHInstrumentedZnClient >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHInstrumentedZnClient >> clock: aClock [
	"aClock answers #now, #milliseconds and #sleepSeconds: (the injectable sleeper)."

	clock := aClock
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> complete: anApiCall durationMs: milliseconds [

	anApiCall
		durationMs: milliseconds;
		status: response code;
		bytes: self responseByteCount;
		rateLimitHeaders: self rateLimitHeaders;
		linkNext: self hasNextLink
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> consumeRetryReason [

	| reason |
	reason := pendingRetryReason.
	pendingRetryReason := nil.
	^ reason
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> currentEndpoint [

	^ normalizer normalize: request url pathPrintString
]

{ #category : 'operations' }
GPHInstrumentedZnClient >> execute [
	"One logical request. It may span several real exchanges: Zinc retries, silent replays on a reused connection, and one replay after a rate-limit wait (D4)."

	| result |
	self beginLogicalRequest.
	result := self executeLogicalRequest.
	self isRateLimitedResponse ifTrue: [
			self waitForRateLimitReset.
			pendingRetryReason := #rateLimit.
			result := self executeLogicalRequest ].
	self recordUnexpectedStatus.
	^ result
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> executeLogicalRequest [

	^ [ super execute ]
		  on: Error
		  do: [ :error |
				  self recordFailedLogicalRequest: error.
				  error pass ]
]

{ #category : 'private protocol' }
GPHInstrumentedZnClient >> executeOnReusedConnection [
	"A kept-alive connection may have gone stale: whatever the failure, close the connection and let #executeWithRetriesRemaining: decide on a retry (reason #connectionReuse, or #timeout)."

	^ [
		  self
			  executeRequestResponse;
			  cleanupConnection ]
		  on: Error
		  do: [ :error |
				  failedOnReusedConnection := true.
				  self close.
				  error pass ]
]

{ #category : 'private protocol' }
GPHInstrumentedZnClient >> executeRequestResponse [
	"One real exchange on the wire: record it, whether it succeeds or fails."

	| call startMs |
	call := self newCallRecord.
	startMs := clock milliseconds.
	[ super executeRequestResponse ]
		on: Error
		do: [ :error |
				self record: call failedWith: error startMs: startMs.
				error pass ].
	self complete: call durationMs: clock milliseconds - startMs.
	recorder recordCall: call
]

{ #category : 'private protocol' }
GPHInstrumentedZnClient >> executeWithRetriesRemaining: retryCount [
	"Replaces the Zinc retry loop and its silent replay on reused connections: the same exception set, plus any failure on a reused connection, plus a retry on 5xx answers (which Zinc does not signal). Each retry is tagged with its reason and waits through the injected clock. At most retryCount retries in total, whatever their reasons."

	| result |
	result := [
	          self executeWithRedirectsRemaining:
		          self maxNumberOfRedirects ]
		          on: Error
		          do: [ :exception |
				          ((self isRetryable: exception) and: [ retryCount > 0 ])
					          ifFalse: [ exception pass ].
				          self prepareRetry: (self retryReasonOf: exception).
				          ^ self executeWithRetriesRemaining: retryCount - 1 ].
	(self isServerErrorResponse and: [ retryCount > 0 ]) ifTrue: [
			self prepareRetry: #http5xx.
			^ self executeWithRetriesRemaining: retryCount - 1 ].
	^ result
]

{ #category : 'private protocol' }
GPHInstrumentedZnClient >> getConnectionAndExecute [
	"Like ZnClient>>#getConnectionAndExecute, without its silent replay: a failure on a reused connection closes it and propagates to #executeWithRetriesRemaining:, which counts it against the single retry budget of the logical request. A failure to connect is recorded as an attempt too."

	self canReuseConnection ifTrue: [ ^ self executeOnReusedConnection ].
	self openConnection.
	[ self executeRequestResponse ] ensure: [ self cleanupConnection ]
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> hasNextLink [

	^ (self responseHeader: 'Link')
		  ifNil: [ false ]
		  ifNotNil: [ :link | link includesSubstring: 'rel="next"' ]
]

{ #category : 'initialization' }
GPHInstrumentedZnClient >> initialize [

	super initialize.
	self
		timeout: 60;
		numberOfRetries: 2;
		retryDelay: 2;
		logLevel: 0.
	recorder := GPHApiCallRecorder new.
	clock := GPHClock new.
	normalizer := GPHEndpointNormalizer new.
	attempt := 0.
	failedOnReusedConnection := false
]

{ #category : 'testing' }
GPHInstrumentedZnClient >> isRateLimitedResponse [
	"D4: a 403 or 429 with X-RateLimit-Remaining: 0, or with a Retry-After header."

	(response notNil and: [ #( 403 429 ) includes: response code ])
		ifFalse: [ ^ false ].
	^ (self responseHeader: 'X-RateLimit-Remaining') = '0' or: [
		  (self responseHeader: 'Retry-After') notNil ]
]

{ #category : 'testing' }
GPHInstrumentedZnClient >> isRetryable: anException [
	"The Zinc retry exception set, or any failure on a reused connection (Zinc would have replayed it)."

	^ failedOnReusedConnection or: [
		  self retryExceptionSet handles: anException ]
]

{ #category : 'testing' }
GPHInstrumentedZnClient >> isServerErrorResponse [

	^ response notNil and: [ response code >= 500 ]
]

{ #category : 'testing' }
GPHInstrumentedZnClient >> isUnexpectedStatus: aCode [
	"Any status >= 400 is unexpected, except 404 on commits/:sha and users/:login which the tool legitimately turns into nil."

	aCode < 400 ifTrue: [ ^ false ].
	^ (aCode = 404 and: [
		   self class toleratedNotFoundEndpoints includes:
			   self currentEndpoint ]) not
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> newCallRecord [
	"Only the request method and URL are read; request headers are never touched."

	| url |
	url := request url.
	attempt := attempt + 1.
	^ GPHApiCall new
		  seq: recorder nextSeq;
		  logicalId: logicalId;
		  attempt: attempt;
		  retryReason: self consumeRetryReason;
		  method: request method;
		  path: url pathPrintString;
		  endpoint: (normalizer normalize: url pathPrintString);
		  query: (self queryOf: url);
		  page:
			  ((url queryAt: 'page' ifAbsent: [ nil ]) ifNotNil: [ :page |
					   page asInteger ]);
		  step: recorder currentStep;
		  startedAt: clock now;
		  yourself
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> newUnexpectedResponse [

	^ GPHUnexpectedResponse new
		  step: recorder currentStep;
		  logicalId: logicalId;
		  endpoint: self currentEndpoint;
		  path: request url pathPrintString;
		  occurredAt: clock now;
		  yourself
]

{ #category : 'private protocol' }
GPHInstrumentedZnClient >> openConnection [
	"Connecting (refused connection, connection timeout, DNS failure) happens before any exchange: a failure there is still an attempt. It is recorded once, here, then propagated to the retry loop."

	| startedAt startMs |
	startedAt := clock now.
	startMs := clock milliseconds.
	[ self newConnectionTo: request url ]
		on: Error
		do: [ :error |
				self
					record: (self newCallRecord
							 startedAt: startedAt;
							 yourself)
					failedWith: error
					startMs: startMs.
				error pass ]
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> prepareRetry: aReason [
	"Same as ZnClient>>#handleRetry: but the delay goes through the injected clock. The retry always opens a fresh connection."

	pendingRetryReason := aReason.
	failedOnReusedConnection := false.
	self close.
	clock sleepSeconds: self retryDelay
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> queryOf: aUrl [

	| query |
	query := OrderedDictionary new.
	aUrl hasQuery ifTrue: [
			aUrl query keysAndValuesDo: [ :key :value |
				query at: key asString put: value asString ] ].
	^ query
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> rateLimitHeaders [
	"Answer the white-listed X-RateLimit-* headers of the response."

	| headers |
	headers := OrderedDictionary new.
	self class rateLimitHeaderNames do: [ :name |
			(self responseHeader: name) ifNotNil: [ :value |
				headers at: name put: value ] ].
	^ headers
]

{ #category : 'private - rate limit' }
GPHInstrumentedZnClient >> rateLimitWaitSeconds [
	"Wait until X-RateLimit-Reset (epoch seconds) or for Retry-After, whichever is later, plus a 5 s margin. A Retry-After that is neither delta-seconds nor an HTTP date is ignored: X-RateLimit-Reset decides alone, or the default wait applies when it is missing too."

	| untilReset retryAfter |
	untilReset := self secondsUntilRateLimitResetIfAbsent: [ 0 ].
	retryAfter := (self responseHeader: 'Retry-After')
		              ifNil: [ 0 ]
		              ifNotNil: [ :value |
				              self retryAfterSecondsFrom: value ifUnreadable: [
						              self secondsUntilRateLimitResetIfAbsent: [
							              self class defaultRateLimitWaitSeconds ] ] ].
	^ ((untilReset max: retryAfter) max: 0)
	  + self class resetMarginSeconds
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> record: anApiCall failedWith: anError startMs: startMs [
	"An attempt that ended with an exception: no status, the error class and the time spent."

	anApiCall
		errorClass: anError class name;
		durationMs: clock milliseconds - startMs.
	recorder recordCall: anApiCall
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> recordFailedLogicalRequest: anError [
	"The logical request ended with an exception (e.g. network failure after the retries)."

	recorder recordUnexpectedError: (self newUnexpectedResponse
			 errorClass: anError class name;
			 errorMessage: (anError messageText asString truncateTo: 500);
			 yourself)
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> recordUnexpectedStatus [
	"Called once per logical request, on its final response."

	(self isUnexpectedStatus: response code) ifFalse: [ ^ self ].
	recorder recordUnexpectedError: (self newUnexpectedResponse
			 status: response code;
			 yourself)
]

{ #category : 'accessing' }
GPHInstrumentedZnClient >> recorder [

	^ recorder
]

{ #category : 'accessing' }
GPHInstrumentedZnClient >> recorder: aRecorder [

	recorder := aRecorder
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> responseByteCount [

	^ response entity
		  ifNil: [ 0 ]
		  ifNotNil: [ :entity | entity contentLength ifNil: [ 0 ] ]
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> responseHeader: aName [

	^ response headers at: aName ifAbsent: [ nil ]
]

{ #category : 'private - rate limit' }
GPHInstrumentedZnClient >> retryAfterSecondsFrom: aString ifUnreadable: aBlock [
	"Retry-After is either delta-seconds (digits only) or an HTTP date (RFC 9110, section 10.2.3). Answer aBlock value when it is neither. ZnUtils class>>#parseHttpDate: fails on most malformed dates but turns an unreadable year into 0, hence the epoch check."

	| value date |
	value := aString trimBoth.
	(value notEmpty and: [ value isAllDigits ]) ifTrue: [
		^ value asInteger ].
	date := [ ZnUtils parseHttpDate: value ]
		        on: Error
		        do: [ ^ aBlock value ].
	date year < 1970 ifTrue: [ ^ aBlock value ].
	^ date asUnixTime - clock now asUnixTime
]

{ #category : 'private - instrumentation' }
GPHInstrumentedZnClient >> retryReasonOf: anException [

	(ConnectionTimedOut handles: anException) ifTrue: [ ^ #timeout ].
	^ failedOnReusedConnection
		  ifTrue: [ #connectionReuse ]
		  ifFalse: [ #network ]
]

{ #category : 'private - rate limit' }
GPHInstrumentedZnClient >> secondsUntilRateLimitResetIfAbsent: aBlock [
	"X-RateLimit-Reset is an epoch time in seconds; answer aBlock value when the header is missing or is not made of digits only."

	| reset |
	reset := (self responseHeader: 'X-RateLimit-Reset') ifNil: [ '' ].
	(reset notEmpty and: [ reset isAllDigits ]) ifFalse: [
		^ aBlock value ].
	^ reset asInteger - clock now asUnixTime
]

{ #category : 'private - rate limit' }
GPHInstrumentedZnClient >> waitForRateLimitReset [
	"Sleep through the injected clock and record the wait so that it is excluded from step durations."

	| seconds startedAt startMs |
	seconds := self rateLimitWaitSeconds.
	startedAt := clock now.
	startMs := clock milliseconds.
	clock sleepSeconds: seconds.
	recorder recordRateLimitWait: (GPHRateLimitWait new
			 step: recorder currentStep;
			 logicalId: logicalId;
			 endpoint: self currentEndpoint;
			 status: response code;
			 startedAt: startedAt;
			 plannedSeconds: seconds;
			 waitedMs: clock milliseconds - startMs;
			 yourself)
]
