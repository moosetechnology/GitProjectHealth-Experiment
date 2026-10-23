"
GPHRunner with injected steps, a fake clock and an output root in a memory file system: states, per-step timings, status.json, failure handling with token redaction, partial export, and exclusion of rate-limit waits from net durations.
"
Class {
	#name : 'GPHRunnerTest',
	#superclass : 'TestCase',
	#instVars : [
		'clock',
		'runner',
		'outputRoot'
	],
	#category : 'GPHExperiment-Harness-Tests-Run',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Run'
}

{ #category : 'helpers' }
GPHRunnerTest >> exportStep [

	^ GPHStep finalization: 'export' do: [ runner export ]
]

{ #category : 'running' }
GPHRunnerTest >> setUp [

	super setUp.
	clock := GPHFakeClock new.
	outputRoot := FileSystem memory root / 'out'.
	runner := GPHRunner on: ((GPHRunConfig
			            repo: 'o/r'
			            mode: #D
			            since: '2026-01-01T00:00:00Z'
			            until: '2026-02-01T00:00:00Z')
			           runId: 'runner-test';
			           outputRoot: outputRoot;
			           cloneRoot: FileSystem memory root / 'clones';
			           apiBaseUrl: 'http://localhost:9';
			           yourself).
	runner
		clock: clock;
		tokenProvider: (GPHTokenProvider token: self token source: 'env')
]

{ #category : 'helpers' }
GPHRunnerTest >> step: aName lasting: aNumberOfSeconds [

	^ GPHStep named: aName do: [ clock advanceSeconds: aNumberOfSeconds ]
]

{ #category : 'tests' }
GPHRunnerTest >> testFailingStepIsRedactedAndPartiallyExported [
	"A step fails with the token in its message: the run is failed, the error class is kept, the message is redacted, the remaining measured steps are skipped, the export still runs, and no written file contains the token."

	| status files |
	runner steps: {
			(self step: 'build' lasting: 1).
			(GPHStep named: 'commits' do: [
				 Error signal:
					 'request failed with token ' , self token , ' in header' ]).
			(self step: 'diffs' lasting: 1).
			self exportStep }.

	runner run.

	self assert: runner state equals: #failed.
	self assert: runner errorClassName equals: #Error.
	self assert: (runner errorMessage includesSubstring: '[REDACTED]').
	self deny: (runner errorMessage includesSubstring: self token).
	self assert: (self timingNamed: 'commits') outcome equals: #failed.
	self deny:
		(runner timings anySatisfy: [ :timing | timing name = 'diffs' ]).
	status := GPHJsonFile read: runner outputDirectory / 'status.json'.
	self assert: (status at: 'state') equals: 'failed'.
	self assert: ((status at: 'error') at: 'class') equals: 'Error'.
	self assert:
		(((status at: 'error') at: 'message') includesSubstring:
			 '[REDACTED]').
	#( 'meta.json' 'timings.json' 'api-calls.json' 'commits.json'
	   'diffs.json' 'prs.json' 'counts.json' ) do: [ :name |
			self
				assert: (runner outputDirectory / name) exists
				description: name , ' missing from the partial export' ].
	files := outputRoot allFiles.
	self assert: files size >= 8.
	files do: [ :file |
			self
				deny: (file contents includesSubstring: self token)
				description: file fullName , ' contains the token' ]
]

{ #category : 'tests' }
GPHRunnerTest >> testRateLimitWaitIsExcludedFromNetDuration [
	"A 3 s rate-limit wait recorded during the sub-step commits.walk is subtracted from the net duration of commits.walk and of its parent step commits."

	| commits walk |
	runner steps: { (GPHStep named: 'commits' do: [
				 clock advanceSeconds: 1.
				 runner substep: 'commits.walk' do: [
						 clock advanceSeconds: 4.
						 runner recorder recordRateLimitWait: (GPHRateLimitWait new
								  step: runner recorder currentStep;
								  endpoint: 'commits';
								  status: 403;
								  startedAt: clock now;
								  plannedSeconds: 3;
								  waitedMs: 3000;
								  yourself) ] ]) }.

	runner run.

	self assert: runner state equals: #done.
	commits := self timingNamed: 'commits'.
	walk := self timingNamed: 'commits.walk'.
	self assert: walk parent equals: 'commits'.
	self assert: commits durationMs equals: 5000.
	self assert: commits rateLimitWaitMs equals: 3000.
	self assert: commits netDurationMs equals: commits durationMs - 3000.
	self assert: walk durationMs equals: 4000.
	self assert: walk netDurationMs equals: 1000
]

{ #category : 'tests' }
GPHRunnerTest >> testSuccessfulRunIsDoneWithOneTimingPerStep [

	| status |
	runner steps: {
			(self step: 'build' lasting: 1).
			(self step: 'commits' lasting: 2).
			self exportStep }.

	runner run.

	self assert: runner state equals: #done.
	self
		assert: (runner timings collect: [ :timing | timing name ]) asArray
		equals: #( 'build' 'commits' 'export' ).
	self assert: (self timingNamed: 'build') durationMs equals: 1000.
	self assert: (self timingNamed: 'commits') durationMs equals: 2000.
	self assert:
		(runner timings allSatisfy: [ :timing | timing outcome = #ok ]).
	self assert: (self timingNamed: 'export') measured not.
	status := GPHJsonFile read: runner outputDirectory / 'status.json'.
	self assert: (status at: 'state') equals: 'done'.
	self assert: (status at: 'runId') equals: 'runner-test'.
	self assert: (status at: 'error') isNil.
	self assert: (runner outputDirectory / 'meta.json') exists.
	self assert: runner finalizationErrors isEmpty
]

{ #category : 'tests' }
GPHRunnerTest >> testUnexpectedErrorMarksTheRunAsAnomaly [
	"Any unexpected error recorded by the client during a step sets anomaly: true in status.json and meta.json, without failing the run."

	runner steps: {
			(GPHStep named: 'prs' do: [
					 runner recorder recordUnexpectedError:
						 (GPHUnexpectedResponse new
							  step: runner recorder currentStep;
							  endpoint: 'pulls';
							  path: '/repos/o/r/pulls';
							  status: 404;
							  occurredAt: clock now;
							  yourself) ]).
			self exportStep }.

	runner run.

	self assert: runner state equals: #done.
	self assert:
		((GPHJsonFile read: runner outputDirectory / 'status.json') at:
			 'anomaly').
	self assert:
		((GPHJsonFile read: runner outputDirectory / 'meta.json') at:
			 'anomaly').
	self
		assert:
			((GPHJsonFile read: runner outputDirectory / 'api-calls.json') at:
				 'unexpectedErrors') size
		equals: 1
]

{ #category : 'helpers' }
GPHRunnerTest >> timingNamed: aName [

	^ runner timings detect: [ :timing | timing name = aName ]
]

{ #category : 'helpers' }
GPHRunnerTest >> token [

	^ 'SECRET-RUNNER-TOKEN-42'
]
