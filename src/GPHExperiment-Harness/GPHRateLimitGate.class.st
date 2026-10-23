"
Before a run, I GET /rate_limit with a separate plain ZnClient (not recorded). If core.remaining is below the threshold, I notify my listener (#rateLimitGateWillWait:) and wait until reset + 5 s. #pass answers a GPHRateLimitCheck.
"
Class {
	#name : 'GPHRateLimitGate',
	#superclass : 'Object',
	#instVars : [
		'tokenProvider',
		'baseUrl',
		'threshold',
		'clock',
		'listener'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'accessing' }
GPHRateLimitGate >> baseUrl [

	^ baseUrl
]

{ #category : 'accessing' }
GPHRateLimitGate >> baseUrl: anObject [

	baseUrl := anObject
]

{ #category : 'accessing' }
GPHRateLimitGate >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHRateLimitGate >> clock: anObject [

	clock := anObject
]

{ #category : 'private' }
GPHRateLimitGate >> fetchCoreLimit [
	"GET /rate_limit with a separate, non-instrumented client: this request is not counted."

	| client core |
	client := self newHttpClient.
	core := [
		        ((NeoJSONReader fromString: (client
				           url: baseUrl , '/rate_limit';
				           headerAt: 'Authorization'
				           put: 'token ' , tokenProvider token;
				           get)) at: 'resources') at: 'core' ] ensure: [
		        client close ].
	^ GPHRateLimitCheck new
		  checkedAt: clock now;
		  remaining: (core at: 'remaining');
		  limit: (core at: 'limit');
		  reset: (core at: 'reset');
		  yourself
]

{ #category : 'initialization' }
GPHRateLimitGate >> initialize [

	super initialize.
	baseUrl := 'https://api.github.com'.
	threshold := 1000.
	clock := GPHClock new.
	listener := GPHNullRunListener new
]

{ #category : 'accessing' }
GPHRateLimitGate >> listener [

	^ listener
]

{ #category : 'accessing' }
GPHRateLimitGate >> listener: anObject [

	listener := anObject
]

{ #category : 'private' }
GPHRateLimitGate >> newHttpClient [

	^ ZnClient new
		  timeout: 60;
		  logLevel: 0;
		  enforceHttpSuccess: true;
		  accept: ZnMimeType applicationJson;
		  yourself
]

{ #category : 'running' }
GPHRateLimitGate >> pass [
	"Check the core rate limit; wait until reset + 5 s when it is below the threshold. Answer the GPHRateLimitCheck."

	| check |
	check := self fetchCoreLimit.
	(check isBelow: threshold) ifTrue: [
			listener rateLimitGateWillWait: check.
			check waitedSeconds: (self waitUntilResetOf: check) ].
	^ check
]

{ #category : 'accessing' }
GPHRateLimitGate >> threshold [

	^ threshold
]

{ #category : 'accessing' }
GPHRateLimitGate >> threshold: anObject [

	threshold := anObject
]

{ #category : 'accessing' }
GPHRateLimitGate >> tokenProvider [

	^ tokenProvider
]

{ #category : 'accessing' }
GPHRateLimitGate >> tokenProvider: anObject [

	tokenProvider := anObject
]

{ #category : 'private' }
GPHRateLimitGate >> waitUntilResetOf: aCheck [

	| seconds |
	seconds := (aCheck reset - clock now asUnixTime max: 0)
	           + GPHInstrumentedZnClient resetMarginSeconds.
	clock sleepSeconds: seconds.
	^ seconds
]
