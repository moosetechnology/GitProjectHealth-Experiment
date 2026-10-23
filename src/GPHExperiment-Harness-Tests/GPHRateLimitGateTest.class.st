"
Tests of GPHRateLimitGate against a local /rate_limit endpoint, with a fake clock (no real wait). Also checks that the gate request is never counted by the recorder of the run.
"
Class {
	#name : 'GPHRateLimitGateTest',
	#superclass : 'GPHLocalServerTestCase',
	#instVars : [
		'clock',
		'remaining',
		'resetIn'
	],
	#category : 'GPHExperiment-Harness-Tests-Http',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Http'
}

{ #category : 'helpers' }
GPHRateLimitGateTest >> newGate [

	^ GPHRateLimitGate new
		  tokenProvider:
			  (GPHTokenProvider token: 'SECRET-GATE' source: 'env');
		  baseUrl: self baseUrl;
		  threshold: 1000;
		  clock: clock;
		  yourself
]

{ #category : 'running' }
GPHRateLimitGateTest >> setUp [

	super setUp.
	clock := self newClock.
	remaining := 0.
	resetIn := 2.
	self respondWith: [ :request :hitCount |
			self jsonResponse: (NeoJSONWriter toString: (Dictionary new
						  at: 'resources' put: (Dictionary new
								   at: 'core' put: (Dictionary new
										    at: 'limit' put: 5000;
										    at: 'remaining' put: remaining;
										    at: 'used' put: 5000 - remaining;
										    at: 'reset' put: clock unixNow + resetIn;
										    yourself);
								   yourself);
						  yourself)) ]
]

{ #category : 'tests' }
GPHRateLimitGateTest >> testExhaustedLimitWaitsUntilResetPlusMargin [
	"remaining = 0 and reset = now + 2: wait 2 + 5 = 7 s through the clock, and record it in the check."

	| check |
	check := self newGate pass.
	self assert: check remaining equals: 0.
	self assert: check waitedSeconds equals: 7.
	self assert: check waitedMilliseconds equals: 7000.
	self assert: clock sleeps asArray equals: #( 7 ).
	self assert: (self hitsOf: '/rate_limit') equals: 1.
	self
		assert: (self received first headers at: 'Authorization')
		equals: 'token SECRET-GATE'
]

{ #category : 'tests' }
GPHRateLimitGateTest >> testGateRequestIsNotRecordedByTheRun [
	"A runner whose only step is the gate: the /rate_limit request reaches the server, but the recorder of the run stays empty; the gate wait is excluded from the net duration of the gate step."

	| runner timing |
	runner := GPHRunner on: ((GPHRunConfig
			            repo: 'o/r'
			            mode: #D
			            since: '2026-01-01T00:00:00Z'
			            until: '2026-02-01T00:00:00Z')
			           runId: 'gate-run';
			           outputRoot: FileSystem memory root / 'out';
			           apiBaseUrl: self baseUrl;
			           rateLimitThreshold: 1000;
			           yourself).
	runner
		clock: clock;
		tokenProvider: (GPHTokenProvider token: 'SECRET-GATE' source: 'env');
		steps:
			{ (GPHStep gate: 'rateLimitGate' do: [ runner passRateLimitGate ]) }.

	runner run.

	self assert: runner state equals: #done.
	self assert: (self hitsOf: '/rate_limit') equals: 1.
	self assert: runner recorder callCount equals: 0.
	self assert: runner recorder calls isEmpty.
	self assert: runner gateCheck waitedSeconds equals: 7.
	timing := runner timings detect: [ :each |
		          each name = 'rateLimitGate' ].
	self assert: timing durationMs equals: 7000.
	self assert: timing rateLimitWaitMs equals: 7000.
	self assert: timing netDurationMs equals: 0
]

{ #category : 'tests' }
GPHRateLimitGateTest >> testRemainingAboveThresholdDoesNotWait [

	| check |
	remaining := 4000.
	check := self newGate pass.
	self assert: check remaining equals: 4000.
	self assert: check waitedSeconds equals: 0.
	self assert: clock sleeps isEmpty
]
