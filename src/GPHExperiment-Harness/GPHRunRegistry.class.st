"
I launch runs in background processes and keep track of them.

	GPHRunRegistry default launch: aConfig.		""""answers the runId immediately""""
	GPHRunRegistry default statusOf: runId.		""""a Dictionary""""
	GPHRunRegistry default stop: runId.
	GPHRunRegistry default compare: runIdD with: runIdH.	""""answers a comparison id""""

The default instance is replaceable (#default:, #resetDefault). The runner factory (a block config -> runner) and the clock are injectable.
"
Class {
	#name : 'GPHRunRegistry',
	#superclass : 'Object',
	#instVars : [
		'handles',
		'mutex',
		'runnerFactory',
		'clock',
		'outputRoot'
	],
	#classInstVars : [
		'default'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'accessing' }
GPHRunRegistry class >> default [

	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
GPHRunRegistry class >> default: aRegistry [
	"Replace the default registry (e.g. with one using fake runners in tests)."

	default := aRegistry
]

{ #category : 'initialization' }
GPHRunRegistry class >> resetDefault [

	default := nil
]

{ #category : 'accessing' }
GPHRunRegistry >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHRunRegistry >> clock: aClock [
	"The clock used by the watchdogs (#sleepSeconds:)."

	clock := aClock
]

{ #category : 'running' }
GPHRunRegistry >> compare: aRunIdD with: aRunIdH [
	"Compare the exports of two runs in a background process; answer the comparison id. consistency.json is written in outputRoot/<comparison id>."

	| job |
	job := GPHCompareJob new
		       id: ('-' join: {
						        'compare'.
						        aRunIdD.
						        'vs'.
						        aRunIdH.
						        (GPHTime compactStamp: clock now) });
		       directoryD: (self outputDirectoryOf: aRunIdD);
		       directoryH: (self outputDirectoryOf: aRunIdH);
		       comparator: GPHRunComparator new;
		       yourself.
	job outputDirectory: outputRoot / job id.
	self register: job as: job id.
	job start.
	^ job id
]

{ #category : 'querying' }
GPHRunRegistry >> handleAt: anId [

	^ mutex critical: [
			  handles
				  at: anId
				  ifAbsent: [
				  GPHUnknownRunError signal: 'Unknown run: ' , anId asString ] ]
]

{ #category : 'initialization' }
GPHRunRegistry >> initialize [

	super initialize.
	handles := Dictionary new.
	mutex := Mutex new.
	clock := GPHClock new.
	outputRoot := FileSystem workingDirectory / 'gph-exp-out'.
	runnerFactory := [ :config | GPHRunner on: config ]
]

{ #category : 'running' }
GPHRunRegistry >> launch: aRunConfig [
	"Start the run in a background process named 'GPH-<runId>' and answer its runId immediately."

	| runId handle |
	aRunConfig validate.
	runId := aRunConfig runId.
	handle := GPHRunHandle
		          registry: self
		          runner: (runnerFactory value: aRunConfig).
	self register: handle as: runId.
	handle start.
	^ runId
]

{ #category : 'querying' }
GPHRunRegistry >> outputDirectoryOf: aRunId [
	"Directory of a known run, or outputRoot/<runId> for a run launched before (e.g. in a previous session)."

	^ mutex critical: [
			  handles
				  at: aRunId
				  ifPresent: [ :handle | handle outputDirectory ]
				  ifAbsent: [ outputRoot / aRunId ] ]
]

{ #category : 'accessing' }
GPHRunRegistry >> outputRoot [

	^ outputRoot
]

{ #category : 'accessing' }
GPHRunRegistry >> outputRoot: aFileReference [
	"Where comparisons are written, and where unknown run ids are looked up."

	outputRoot := aFileReference
]

{ #category : 'private' }
GPHRunRegistry >> register: aHandle as: anId [

	mutex critical: [
			(handles includesKey: anId) ifTrue: [
				GPHConfigurationError signal: 'Run id already used: ' , anId ].
			handles at: anId put: aHandle ]
]

{ #category : 'memory' }
GPHRunRegistry >> releaseFinishedModels [
	"Release the models of every run that no live process can still use: finished runs, and runs whose process is terminated or absent (see GPHRunHandle>>#releaseModelIfNotRunning). Runs whose run or watchdog process is alive are not touched. Answer the sorted ids of the runs released by this call."

	| candidates |
	candidates := mutex critical: [ handles associations ].
	^ (candidates
		   select: [ :each | each value releaseModelIfNotRunning ]
		   thenCollect: [ :each | each key ]) sorted
]

{ #category : 'memory' }
GPHRunRegistry >> releaseModelOf: aRunId [
	"Release the in-memory model of a finished run (its exports stay on disk); answer whether it is released. A run that is not finished is left untouched (false)."

	^ (self handleAt: aRunId) releaseModel
]

{ #category : 'querying' }
GPHRunRegistry >> runIds [

	^ mutex critical: [ handles keys sorted ]
]

{ #category : 'accessing' }
GPHRunRegistry >> runnerFactory: aBlock [
	"aBlock answers a runner for a GPHRunConfig."

	runnerFactory := aBlock
]

{ #category : 'running' }
GPHRunRegistry >> statusOf: anId [
	"Answer the status Dictionary of a run or of a comparison."

	^ (self handleAt: anId) status
]

{ #category : 'running' }
GPHRunRegistry >> stop: anId [
	"Terminate a run (state stopped, partial export written) or a comparison."

	(self handleAt: anId) stop
]

{ #category : 'running' }
GPHRunRegistry >> waitFor: anId timeout: aDuration [
	"Poll until the run or comparison is finished or aDuration elapsed; answer its status. Convenient for tests and scripts."

	| handle deadline |
	handle := self handleAt: anId.
	deadline := DateAndTime now + aDuration.
	[ handle isFinished or: [ DateAndTime now > deadline ] ] whileFalse: [
		(Delay forMilliseconds: 20) wait ].
	^ handle status
]
