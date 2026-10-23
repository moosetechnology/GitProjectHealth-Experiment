"
Tests of GPHInstrumentedZnClient against a local ZnServer: counting of real exchanges and logical requests, retries (#http5xx, #timeout), rate-limit wait and single replay (D4), classification of unexpected statuses, and absence of the token in what the recorder serializes. The retry delays and rate-limit waits go through a GPHFakeClock, so no test really sleeps except the timeout test (socket timeout of 1 s).
"
Class {
	#name : 'GPHInstrumentedZnClientTest',
	#superclass : 'GPHLocalServerTestCase',
	#instVars : [
		'clock',
		'recorder',
		'client'
	],
	#category : 'GPHExperiment-Harness-Tests-Http',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Http'
}

{ #category : 'helpers' }
GPHInstrumentedZnClientTest >> exhaustedHeadersResetIn: aNumberOfSeconds [
	"Headers of a 403 answered when the core rate limit is exhausted."

	^ Dictionary new
		  at: 'X-RateLimit-Limit' put: '5000';
		  at: 'X-RateLimit-Remaining' put: '0';
		  at: 'X-RateLimit-Used' put: '5000';
		  at: 'X-RateLimit-Reset'
		  put: (clock unixNow + aNumberOfSeconds) printString;
		  at: 'X-RateLimit-Resource' put: 'core';
		  yourself
]

{ #category : 'helpers' }
GPHInstrumentedZnClientTest >> get: aPathAndQuery [
	"One logical GET through the instrumented client."

	^ client
		  url: (self urlFor: aPathAndQuery);
		  get
]

{ #category : 'helpers' }
GPHInstrumentedZnClientTest >> rateLimitHeadersRemaining: aRemaining [
	"X-RateLimit-* headers as sent by GitHub."

	^ Dictionary new
		  at: 'X-RateLimit-Limit' put: '5000';
		  at: 'X-RateLimit-Remaining' put: aRemaining printString;
		  at: 'X-RateLimit-Used' put: (5000 - aRemaining) printString;
		  at: 'X-RateLimit-Reset' put: (clock unixNow + 3600) printString;
		  at: 'X-RateLimit-Resource' put: 'core';
		  yourself
]

{ #category : 'running' }
GPHInstrumentedZnClientTest >> setUp [

	super setUp.
	clock := self newClock.
	recorder := GPHApiCallRecorder new.
	client := GPHInstrumentedZnClient new
		          recorder: recorder;
		          clock: clock;
		          yourself
]

{ #category : 'running' }
GPHInstrumentedZnClientTest >> tearDown [

	client ifNotNil: [ :instrumented | instrumented close ].
	super tearDown
]

{ #category : 'tests - configuration' }
GPHInstrumentedZnClientTest >> testDefaultTimeoutAndRetries [
	"Specified defaults: 60 s timeout and at most 2 retries."

	| fresh |
	fresh := GPHInstrumentedZnClient new.
	[
		self assert: fresh timeout equals: 60.
		self assert: fresh numberOfRetries equals: 2 ] ensure: [
		fresh close ]
]

{ #category : 'tests - rate limit' }
GPHInstrumentedZnClientTest >> testDoubleRateLimitReplaysOnlyOnce [
	"D4: a second 403 after the wait is not replayed again; it is answered and counted as an unexpected error."

	self respondWith: [ :request :hitCount |
			self
				jsonResponse: '{"message":"API rate limit exceeded"}'
				status: 403
				headers: (self exhaustedHeadersResetIn: 2) ].

	self get: '/limited'.

	self assert: client response code equals: 403.
	self assert: (self hitsOf: '/limited') equals: 2.
	self assert: recorder calls size equals: 2.
	self assert: recorder rateLimitWaits size equals: 1.
	self assert: clock sleeps size equals: 1.
	self assert: recorder unexpectedErrors size equals: 1.
	self assert: recorder unexpectedErrors first status equals: 403.
	self
		assert: recorder unexpectedErrors first endpoint
		equals: 'limited'
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testDroppedConnectionsAreRetriedForNetwork [
	"/drop: the server worker dies without answering twice (the client reads a closed connection), then answers 200. Each exchange is recorded; the retries are tagged #network."

	| calls |
	self respondWith: [ :request :hitCount |
			hitCount < 3 ifTrue: [ Processor activeProcess terminate ].
			self jsonResponse: '{"ok":true}' ].

	self get: '/drop'.

	self assert: client response code equals: 200.
	self assert: (self hitsOf: '/drop') equals: 3.
	calls := recorder calls.
	self assert: calls size equals: 3.
	self
		assert: (calls collect: [ :call | call retryReason ]) asArray
		equals: #( nil #network #network ).
	self assert: ((calls first: 2) allSatisfy: [ :call |
			 call errorClass notNil and: [ call status isNil ] ]).
	self assert: recorder unexpectedErrors isEmpty
]

{ #category : 'tests - statuses' }
GPHInstrumentedZnClientTest >> testNotFoundOnCommitShaOrUserIsTolerated [
	"404 on commits/:sha and users/:login is a legitimate answer (the tool turns it into nil): no unexpected error."

	| sha |
	sha := 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678'.
	self respondWith: [ :request :hitCount |
			self
				jsonResponse: '{"message":"Not Found"}'
				status: 404
				headers: Dictionary new ].

	self get: '/repos/o/r/commits/' , sha.
	self get: '/users/ghost-user'.

	self
		assert: (recorder calls collect: [ :call | call endpoint ]) asArray
		equals: #( 'commits/:sha' 'users/:login' ).
	self
		assert: (recorder calls collect: [ :call | call status ]) asArray
		equals: #( 404 404 ).
	self assert: recorder unexpectedErrors isEmpty.
	self deny: recorder hasUnexpectedErrors
]

{ #category : 'tests - statuses' }
GPHInstrumentedZnClientTest >> testNotFoundOnPullsIsUnexpected [
	"404 on any other endpoint (here pulls) is an unexpected error, which makes the run an anomaly."

	self respondWith: [ :request :hitCount |
			self
				jsonResponse: '{"message":"Not Found"}'
				status: 404
				headers: Dictionary new ].

	self get: '/repos/o/r/pulls?state=all'.

	self assert: recorder calls size equals: 1.
	self assert: recorder unexpectedErrors size equals: 1.
	self assert: recorder unexpectedErrors first status equals: 404.
	self assert: recorder unexpectedErrors first endpoint equals: 'pulls'.
	self assert: recorder hasUnexpectedErrors
]

{ #category : 'tests - counting' }
GPHInstrumentedZnClientTest >> testPaginatedRequestsAreCountedWithHeaders [
	"Two pages of commits are two logical requests and two exchanges; only page 2 is a pagination request. The white-listed X-RateLimit-* headers are kept, the endpoint is normalized."

	| calls |
	self respondWith: [ :request :hitCount |
			self
				jsonResponse: '[]'
				status: 200
				headers: (self rateLimitHeadersRemaining: 4999 - hitCount) ].

	self get: '/repos/o/r/commits?page=1'.
	self get: '/repos/o/r/commits?page=2'.

	calls := recorder calls.
	self assert: calls size equals: 2.
	self
		assert: (calls collect: [ :call | call endpoint ]) asArray
		equals: #( 'commits' 'commits' ).
	self
		assert: (calls collect: [ :call | call page ]) asArray
		equals: #( 1 2 ).
	self deny: calls first isPagination.
	self assert: calls second isPagination.
	self deny: calls first logicalId equals: calls second logicalId.
	self assert: (calls allSatisfy: [ :call |
			 call attempt = 1 and: [ call isRetry not ] ]).
	self
		assert: (calls collect: [ :call | call status ]) asArray
		equals: #( 200 200 ).
	self assert: calls first rateLimitHeaders size equals: 5.
	self
		assert: (calls first rateLimitHeaders at: 'X-RateLimit-Remaining')
		equals: '4998'.
	self
		assert: (calls second rateLimitHeaders at: 'X-RateLimit-Remaining')
		equals: '4997'.
	self
		assert: (calls first rateLimitHeaders at: 'X-RateLimit-Resource')
		equals: 'core'.
	self assert: (calls second query at: 'page') equals: '2'.
	self
		assert: ((recorder aggregates at: 'totals') at: 'logicalRequests')
		equals: 2.
	self
		assert:
		((recorder aggregates at: 'totals') at: 'paginationRequests')
		equals: 1.
	self
		assert: ((recorder aggregates at: 'totals') at: 'minRemaining')
		equals: 4997.
	self assert: recorder unexpectedErrors isEmpty
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testPersistentServerErrorIsAnsweredAndCountedAsUnexpected [
	"/always500: at most 2 retries (3 exchanges), then the 500 is answered without exception and counted once in unexpectedErrors."

	| calls |
	self respondWith: [ :request :hitCount |
			self
				jsonResponse: '{"message":"boom"}'
				status: 500
				headers: Dictionary new ].

	self shouldnt: [ self get: '/always500' ] raise: Error.

	self assert: client response code equals: 500.
	self assert: (self hitsOf: '/always500') equals: 3.
	calls := recorder calls.
	self assert: calls size equals: 3.
	self
		assert: (calls collect: [ :call | call retryReason ]) asArray
		equals: #( nil #http5xx #http5xx ).
	self assert: recorder unexpectedErrors size equals: 1.
	self assert: recorder unexpectedErrors first status equals: 500.
	self
		assert: recorder unexpectedErrors first endpoint
		equals: 'always500'.
	self assert: recorder hasUnexpectedErrors.
	self assert: (recorder aggregates at: 'unexpectedErrors') equals: 1
]

{ #category : 'tests - rate limit' }
GPHInstrumentedZnClientTest >> testRateLimitWaitIsExcludedFromStepNetDuration [
	"D4 end to end: the client shares the recorder and the fake clock of a runner; the 7 s wait recorded during step commits is subtracted from its net duration."

	| runner timing |
	self respondWith: [ :request :hitCount |
			hitCount = 1
				ifTrue: [
						self
							jsonResponse: '[]'
							status: 403
							headers: (self exhaustedHeadersResetIn: 2) ]
				ifFalse: [ self jsonResponse: '[]' ] ].
	runner := GPHRunner on: ((GPHRunConfig
			            repo: 'o/r'
			            mode: #D
			            since: '2026-01-01T00:00:00Z'
			            until: '2026-02-01T00:00:00Z')
			           runId: 'd4-run';
			           outputRoot: FileSystem memory root / 'out';
			           apiBaseUrl: self baseUrl;
			           yourself).
	runner
		clock: clock;
		recorder: recorder;
		tokenProvider: (GPHTokenProvider token: 'SECRET-D4' source: 'env');
		steps: { (GPHStep
				 named: 'commits'
				 do: [ self get: '/repos/o/r/commits?page=1' ]) }.

	runner run.

	timing := runner timings detect: [ :each | each name = 'commits' ].
	self assert: runner state equals: #done.
	self assert: recorder rateLimitWaits first step equals: 'commits'.
	self assert: timing rateLimitWaitMs equals: 7000.
	self assert: timing durationMs equals: 7000.
	self assert: timing netDurationMs equals: 0.
	self assert: (runner statusDictionary at: 'rateLimited').
	self deny: (runner statusDictionary at: 'anomaly')
]

{ #category : 'tests - rate limit' }
GPHInstrumentedZnClientTest >> testRateLimitedRequestWaitsThenReplaysOnce [
	"D4: /limited answers 403 with X-RateLimit-Remaining: 0 and a reset 2 s ahead, then 200. The client waits max(reset - now, Retry-After) + 5 s = 7 s through the clock, records the wait, replays once and ends with 200, without unexpected error."

	| waits calls |
	self respondWith: [ :request :hitCount |
			hitCount = 1
				ifTrue: [
						self
							jsonResponse: '{"message":"API rate limit exceeded"}'
							status: 403
							headers: (self exhaustedHeadersResetIn: 2) ]
				ifFalse: [ self jsonResponse: '{"ok":true}' ] ].

	self get: '/limited'.

	self assert: client response code equals: 200.
	self assert: (self hitsOf: '/limited') equals: 2.
	waits := recorder rateLimitWaits.
	self assert: waits size equals: 1.
	self assert: waits first plannedSeconds equals: 7.
	self assert: waits first waitedMs equals: 7000.
	self assert: waits first status equals: 403.
	self assert: waits first endpoint equals: 'limited'.
	self assert: clock sleeps asArray equals: #( 7 ).
	calls := recorder calls.
	self assert: calls size equals: 2.
	self
		assert: (calls collect: [ :call | call status ]) asArray
		equals: #( 403 200 ).
	self assert: calls second retryReason equals: #rateLimit.
	self
		assert: (calls collect: [ :call | call logicalId ]) asSet size
		equals: 1.
	self assert: recorder isRateLimited.
	self assert: (recorder aggregates at: 'rateLimitWaitMs') equals: 7000.
	self assert: recorder unexpectedErrors isEmpty
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testRefusedConnectionsAreCountedAsNetworkRetries [
	"The local server is stopped, so every connection to its port is refused. The client retries twice (#network) and then propagates the error. Expected by the spec: every attempt is visible in the recorder, so that the #network retries are counted."

	| calls |
	server stop.
	server := nil.

	self should: [ self get: '/repos/o/r/commits' ] raise: NetworkError.

	self assert: clock sleeps size equals: 2.
	self assert: recorder unexpectedErrors size equals: 1.
	calls := recorder calls.
	self
		assert: calls size = 3
		description:
			'connection attempts recorded: ' , calls size printString
			, ' (expected 3)'.
	self
		assert: (calls collect: [ :call | call retryReason ]) asArray
		equals: #( nil #network #network )
]

{ #category : 'tests - rate limit' }
GPHInstrumentedZnClientTest >> testRetryAfterIsHonouredWhenLaterThanReset [
	"D4 with a secondary rate limit: 429 with Retry-After: 10 and no reset header gives a 10 + 5 = 15 s wait, then one replay."

	self respondWith: [ :request :hitCount |
			hitCount = 1
				ifTrue: [
						self
							jsonResponse: '{"message":"secondary rate limit"}'
							status: 429
							headers: (Dictionary new
									 at: 'Retry-After' put: '10';
									 yourself) ]
				ifFalse: [ self jsonResponse: '{}' ] ].

	self get: '/repos/o/r/pulls'.

	self assert: client response code equals: 200.
	self assert: recorder rateLimitWaits size equals: 1.
	self assert: recorder rateLimitWaits first plannedSeconds equals: 15.
	self assert: clock sleeps asArray equals: #( 15 ).
	self assert: recorder unexpectedErrors isEmpty
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testServerErrorsAreRetriedUntilSuccess [
	"/flaky answers 500, 500, then 200: one logical request, three exchanges, two #http5xx retries, each delayed by retryDelay through the injected clock."

	| calls |
	self respondWith: [ :request :hitCount |
			hitCount < 3
				ifTrue: [
				self jsonResponse: '{}' status: 500 headers: Dictionary new ]
				ifFalse: [ self jsonResponse: '{"ok":true}' ] ].

	self get: '/flaky'.

	self assert: client response code equals: 200.
	self assert: (self hitsOf: '/flaky') equals: 3.
	calls := recorder calls.
	self assert: calls size equals: 3.
	self
		assert: (calls collect: [ :call | call attempt ]) asArray
		equals: #( 1 2 3 ).
	self
		assert: (calls collect: [ :call | call retryReason ]) asArray
		equals: #( nil #http5xx #http5xx ).
	self
		assert: (calls collect: [ :call | call status ]) asArray
		equals: #( 500 500 200 ).
	self
		assert: (calls collect: [ :call | call logicalId ]) asSet size
		equals: 1.
	self assert: clock sleeps asArray equals: {
			client retryDelay.
			client retryDelay }.
	self
		assert:
			(((recorder aggregates at: 'totals') at: 'retriesByReason') at:
				 #http5xx)
		equals: 2.
	self
		assert: ((recorder aggregates at: 'totals') at: 'logicalRequests')
		equals: 1.
	self
		assert: ((recorder aggregates at: 'totals') at: 'attempts')
		equals: 3.
	self assert: recorder unexpectedErrors isEmpty
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testTimeoutOnReusedConnectionStaysWithinTwoRetries [
	"A first fast request leaves a keep-alive connection open; the next request (/slow) times out on that reused connection. Spec: at most 2 retries in total, whatever their reason (#timeout, #network, #http5xx, #connectionReuse), hence at most 3 exchanges for the logical request."

	| slowCalls |
	self respondWith: [ :request :hitCount |
			request uri pathPrintString = '/slow' ifTrue: [
				(Delay forSeconds: 3) wait ].
			self jsonResponse: '{}' ].
	client timeout: 1.
	self get: '/fast'.

	self should: [ self get: '/slow' ] raise: ConnectionTimedOut.

	slowCalls := recorder calls select: [ :call | call endpoint = 'slow' ].
	self
		assert: slowCalls size <= 3
		description: 'exchanges for /slow: ' , slowCalls size printString
			, ' with retry reasons '
			,
			(slowCalls collect: [ :call | call retryReason ]) asArray
				printString.
	self assert: (slowCalls count: [ :call | call isRetry ]) <= 2
]

{ #category : 'tests - retries' }
GPHInstrumentedZnClientTest >> testTimeoutsAreRetriedThenPropagated [
	"/slow sleeps 3 s while the client waits 1 s: each exchange times out, is retried twice with reason #timeout (the retry delay goes through the fake clock), then the exception propagates and the logical request is an unexpected error. The whole test stays well under 15 s."

	| startMs elapsedMs calls |
	self respondWith: [ :request :hitCount |
			(Delay forSeconds: 3) wait.
			self jsonResponse: '{}' ].
	client timeout: 1.
	startMs := Time millisecondClockValue.

	self should: [ self get: '/slow' ] raise: ConnectionTimedOut.

	elapsedMs := Time millisecondClockValue - startMs.
	self assert: elapsedMs < 15000.
	calls := recorder calls.
	self assert: calls size equals: 3.
	self
		assert: (calls collect: [ :call | call retryReason ]) asArray
		equals: #( nil #timeout #timeout ).
	self assert: (calls allSatisfy: [ :call |
			 call errorClass = #ConnectionTimedOut and: [ call status isNil ] ]).
	self assert: clock sleeps asArray equals: {
			client retryDelay.
			client retryDelay }.
	self assert: recorder unexpectedErrors size equals: 1.
	self
		assert: recorder unexpectedErrors first errorClass
		equals: #ConnectionTimedOut.
	self assert: recorder unexpectedErrors first endpoint equals: 'slow'
]

{ #category : 'tests - token' }
GPHInstrumentedZnClientTest >> testTokenIsSentButNeverRecorded [
	"Through a real GithubApi, the server receives the Authorization header, but nothing the recorder serializes (aggregates, calls, waits, unexpected errors) contains the token or the header name."

	| api authorizations serialized |
	self respondWith: [ :request :hitCount |
			hitCount = 1
				ifTrue: [
						self
							jsonResponse: '[]'
							status: 403
							headers: (self exhaustedHeadersResetIn: 1) ]
				ifFalse: [
				self jsonResponse: '[]' status: 404 headers: Dictionary new ] ].
	api := GithubApi new.
	api
		hostUrl: self baseUrl;
		client: client;
		privateToken: 'SECRET-XYZ'.

	api commits getForRepo: 'r' ofOwner: 'o' withParms: Dictionary new.

	authorizations := self received collect: [ :request |
		                  request headers
			                  at: 'Authorization'
			                  ifAbsent: [ nil ] ].
	self
		assert: authorizations asArray
		equals: #( 'token SECRET-XYZ' 'token SECRET-XYZ' ).
	serialized := String streamContents: [ :stream |
			              stream nextPutAll:
				              (NeoJSONWriter toString: recorder aggregates).
			              recorder calls do: [ :call |
				              stream nextPutAll:
					              (NeoJSONWriter toString: call asDictionary) ].
			              recorder rateLimitWaits do: [ :wait |
				              stream nextPutAll:
					              (NeoJSONWriter toString: wait asDictionary) ].
			              recorder unexpectedErrors do: [ :error |
				              stream nextPutAll:
					              (NeoJSONWriter toString: error asDictionary) ] ].
	self assert: recorder calls size equals: 2.
	self assert: recorder unexpectedErrors size equals: 1.
	self deny: (serialized includesSubstring: 'SECRET-XYZ').
	self deny:
		(serialized includesSubstring: 'Authorization' caseSensitive: false)
]
