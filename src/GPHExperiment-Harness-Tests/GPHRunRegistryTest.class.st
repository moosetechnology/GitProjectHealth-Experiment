"
GPHRunRegistry with a runner factory building GPHRunner instances with injected steps and a memory output root. Runs really execute in background processes; durations are kept short (watchdog of 1 s).
"
Class {
	#name : 'GPHRunRegistryTest',
	#superclass : 'TestCase',
	#instVars : [
		'registry',
		'fileSystem',
		'stepsBlock'
	],
	#category : 'GPHExperiment-Harness-Tests-Run',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Run'
}

{ #category : 'helpers' }
GPHRunRegistryTest >> configNamed: aRunId [

	^ (GPHRunConfig
		   repo: 'o/r'
		   mode: #D
		   since: '2026-01-01T00:00:00Z'
		   until: '2026-02-01T00:00:00Z')
		  runId: aRunId;
		  outputRoot: fileSystem root / 'out';
		  cloneRoot: fileSystem root / 'clones';
		  apiBaseUrl: 'http://localhost:9';
		  globalTimeout: 30 seconds;
		  yourself
]

{ #category : 'running' }
GPHRunRegistryTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory.
	stepsBlock := [ :runner | #(  ) ].
	registry := GPHRunRegistry new
		            outputRoot: fileSystem root / 'out';
		            clock: GPHClock new;
		            runnerFactory: [ :config |
				            | runner |
				            runner := GPHRunner on: config.
				            runner
					            tokenProvider:
						            (GPHTokenProvider
							             token: 'SECRET-REGISTRY'
							             source: 'env');
					            steps: (stepsBlock value: runner).
				            runner ];
		            yourself
]

{ #category : 'helpers' }
GPHRunRegistryTest >> sleepingStepsOf: aRunner seconds: aNumber [

	^ {
		  (GPHStep
			   named: 'commits'
			   do: [ (Delay forMilliseconds: (aNumber * 1000) rounded) wait ]).
		  (GPHStep finalization: 'export' do: [ aRunner export ]) }
]

{ #category : 'running' }
GPHRunRegistryTest >> tearDown [
	"Never leave a run or a watchdog process behind."

	registry runIds do: [ :id |
			| handle |
			handle := registry handleAt: id.
			handle watchdog ifNotNil: [ :watchdog | watchdog terminate ].
			handle process ifNotNil: [ :process | process terminate ] ].
	super tearDown
]

{ #category : 'tests' }
GPHRunRegistryTest >> testFailedStateIsPublishedOnlyOnceTheExportIsWritten [
	"A client that waits for a terminal state (waitFor:timeout:) then reads the export must find it. Here the export takes 300 ms, as a large export would: when waitFor: answers state failed, the partial export should already be there."

	| id status directory |
	stepsBlock := [ :runner |
		              {
			              (GPHStep
				               named: 'project'
				               do: [ Error signal: 'boom' ]).
			              (GPHStep finalization: 'export' do: [
					               (Delay forMilliseconds: 300) wait.
					               runner export ]) } ].
	id := registry launch: (self configNamed: 'slow-export-run').

	status := registry waitFor: id timeout: 5 seconds.

	directory := registry outputDirectoryOf: id.
	self assert: (status at: 'state') equals: #failed.
	self
		assert: (directory / 'counts.json') exists
		description:
		'state already failed while the partial export is not written yet'
]

{ #category : 'tests' }
GPHRunRegistryTest >> testFailingRunIsFailed [

	| id status |
	stepsBlock := [ :runner |
		              {
			              (GPHStep
				               named: 'project'
				               do: [
				               GPHRepositoryNotFoundError signal:
					               'Repository not found: o/r' ]).
			              (GPHStep finalization: 'export' do: [ runner export ]) } ].
	id := registry launch: (self configNamed: 'failed-run').

	status := registry waitFor: id timeout: 5 seconds.

	self assert: (status at: 'state') equals: #failed.
	self
		assert: ((status at: 'error') at: 'class')
		equals: #GPHRepositoryNotFoundError
]

{ #category : 'tests' }
GPHRunRegistryTest >> testLaunchAnswersImmediatelyThenCompletes [

	| startMs id launchMs status |
	stepsBlock := [ :runner | self sleepingStepsOf: runner seconds: 0.3 ].
	startMs := Time millisecondClockValue.
	id := registry launch: (self configNamed: 'launch-run').
	launchMs := Time millisecondClockValue - startMs.

	self assert: id equals: 'launch-run'.
	self assert: launchMs < 200.
	self assert: (#( #pending #running ) includes:
			 ((registry statusOf: id) at: 'state')).
	(Delay forMilliseconds: 100) wait.
	self assert: ((registry statusOf: id) at: 'state') equals: #running.
	status := registry waitFor: id timeout: 5 seconds.
	self assert: (status at: 'state') equals: #done.
	self assert: (registry handleAt: id) process isTerminated
]

{ #category : 'tests' }
GPHRunRegistryTest >> testStopMarksTheRunStopped [

	| id status handle |
	stepsBlock := [ :runner | self sleepingStepsOf: runner seconds: 10 ].
	id := registry launch: (self configNamed: 'stopped-run').
	(Delay forMilliseconds: 100) wait.
	self assert: ((registry statusOf: id) at: 'state') equals: #running.

	registry stop: id.

	status := registry statusOf: id.
	handle := registry handleAt: id.
	self assert: (status at: 'state') equals: #stopped.
	self assert: handle process isTerminated.
	self assert: (self waitForFile: handle outputDirectory / 'meta.json')
]

{ #category : 'tests' }
GPHRunRegistryTest >> testUnknownRunIdSignalsError [

	self
		should: [ registry statusOf: 'no-such-run' ]
		raise: GPHUnknownRunError.
	self
		should: [ registry stop: 'no-such-run' ]
		raise: GPHUnknownRunError.
	self
		should: [ registry waitFor: 'no-such-run' timeout: 1 second ]
		raise: GPHUnknownRunError
]

{ #category : 'tests' }
GPHRunRegistryTest >> testWatchdogTimesOutALongStep [
	"globalTimeout of 1 s on a step sleeping 10 s: the watchdog terminates the run process, the state is timeout in less than 3 s, and the partial export is written."

	| startMs id status elapsedMs handle runner |
	stepsBlock := [ :aRunner | self sleepingStepsOf: aRunner seconds: 10 ].
	startMs := Time millisecondClockValue.
	id := registry launch: ((self configNamed: 'watchdog-run')
			       globalTimeout: 1 second;
			       yourself).

	status := registry waitFor: id timeout: 3 seconds.
	elapsedMs := Time millisecondClockValue - startMs.

	self assert: (status at: 'state') equals: #timeout.
	self assert: elapsedMs < 3000.
	handle := registry handleAt: id.
	runner := handle runner.
	self assert: handle process isTerminated.
	self
		assert: ((status at: 'error') at: 'message')
		equals: 'global timeout of 1000 ms exceeded'.
	self assert:
		(self waitForFile: runner outputDirectory / 'counts.json').
	self assert: (runner outputDirectory / 'meta.json') exists.
	self
		assert:
			((GPHJsonFile read: runner outputDirectory / 'meta.json') at:
				 'stateAtExport')
		equals: 'timeout'.
	self
		assert:
		(runner timings detect: [ :timing | timing name = 'commits' ])
			outcome
		equals: #interrupted
]

{ #category : 'helpers' }
GPHRunRegistryTest >> waitForFile: aFileReference [
	"The interrupter writes the partial export right after recording the terminal state."

	| deadline |
	deadline := Time millisecondClockValue + 2000.
	[
	aFileReference exists or: [ Time millisecondClockValue > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	^ aFileReference exists
]
