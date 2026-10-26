"
I run an ordered sequence of runs (GPHRunConfig) one after the other in ONE background process named 'GPH-batch-<batchId>', then the comparisons (runIdD -> runIdH pairs) of their exports.

Each run is launched through the registry (#launch:) and awaited in the image (#waitFor:timeout:, with a timeout of its globalTimeout plus waitAllowance for the rate-limit gate). A failed, timed out or stopped run does not stop the batch: it is recorded and the next run is launched. A run is never relaunched.

batch-status.json is written atomically (GPHJsonFile, redacted through redactor) in registry outputRoot / batchId after every state change.

Usage:
	batch := GPHRunBatch new
		batchId: 'my-batch';
		addConfig: configD;
		addConfig: configH;
		addComparison: configD runId -> configH runId;
		yourself.
	batch start.
	GPHRunBatch statusOf: 'my-batch'.
	(GPHRunBatch named: 'my-batch') stop.

The class side keeps the started batches by id (#named:, #all, #statusOf:).
"
Class {
	#name : 'GPHRunBatch',
	#superclass : 'Object',
	#instVars : [
		'batchId',
		'registry',
		'configs',
		'comparisons',
		'pauseBetweenRuns',
		'waitAllowance',
		'comparisonTimeout',
		'clock',
		'redactor',
		'process',
		'stopRequested',
		'state',
		'startedAt',
		'endedAt',
		'currentIndex',
		'currentRunId',
		'runEntries',
		'comparisonEntries',
		'errorMessage',
		'mutex',
		'stopSignal',
		'garbageCollector',
		'memoryProbe'
	],
	#classInstVars : [
		'batches'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'registry' }
GPHRunBatch class >> all [
	"Answer a copy of the started batches, by id."

	^ self batches copy
]

{ #category : 'registry' }
GPHRunBatch class >> batches [
	"Started batches by id, so that an orchestrator can find a running batch."

	^ batches ifNil: [ batches := Dictionary new ]
]

{ #category : 'registry' }
GPHRunBatch class >> forget: aBatchId [
	"Remove a finished batch from the class-side registry (its batch-status.json stays on disk)."

	self batches removeKey: aBatchId ifAbsent: [  ]
]

{ #category : 'registry' }
GPHRunBatch class >> named: aBatchId [

	^ self batches
		  at: aBatchId
		  ifAbsent: [ GPHUnknownRunError signal: 'Unknown batch: ' , aBatchId asString ]
]

{ #category : 'registry' }
GPHRunBatch class >> register: aBatch [

	(self batches includesKey: aBatch batchId) ifTrue: [
		GPHConfigurationError signal: 'Batch id already used: ' , aBatch batchId ].
	self batches at: aBatch batchId put: aBatch
]

{ #category : 'accessing' }
GPHRunBatch class >> statusFileName [

	^ 'batch-status.json'
]

{ #category : 'registry' }
GPHRunBatch class >> statusOf: aBatchId [
	"Answer the in-memory status of a known batch, or read the batch-status.json of a batch of a previous session in the default registry output root."

	^ self batches
		  at: aBatchId
		  ifPresent: [ :batch | batch status ]
		  ifAbsent: [
		  self statusOf: aBatchId in: GPHRunRegistry default outputRoot ]
]

{ #category : 'registry' }
GPHRunBatch class >> statusOf: aBatchId in: anOutputRoot [
	"Read the batch-status.json written in anOutputRoot / aBatchId."

	| file |
	file := anOutputRoot / aBatchId / self statusFileName.
	file exists ifFalse: [
		GPHUnknownRunError signal: 'Unknown batch: ' , aBatchId asString ].
	^ GPHJsonFile read: file
]

{ #category : 'memory' }
GPHRunBatch class >> usedOldSpaceBytes [
	"Bytes in use in the old space: its size (VM parameter 1) minus its free bytes (VM parameter 54). memoryEnd (VM parameter 3) is the end address of the heap, not an amount of used memory."

	| vm |
	vm := Smalltalk vm.
	^ (vm parameterAt: 1) - (vm parameterAt: 54)
]

{ #category : 'accessing' }
GPHRunBatch >> addComparison: anAssociation [
	"anAssociation is runIdD -> runIdH; the comparison runs after all the runs."

	comparisons add: anAssociation
]

{ #category : 'accessing' }
GPHRunBatch >> addConfig: aRunConfig [

	configs add: aRunConfig
]

{ #category : 'running' }
GPHRunBatch >> awaitRunOf: anEntry [
	"Wait in the image until the run is terminal; answer false when it outlived its globalTimeout plus the allowance."

	self registry
		waitFor: anEntry runId
		timeout: anEntry config globalTimeout + waitAllowance.
	^ self isFinished: anEntry runId
]

{ #category : 'accessing' }
GPHRunBatch >> batchId [

	^ batchId
]

{ #category : 'accessing' }
GPHRunBatch >> batchId: aString [

	batchId := aString
]

{ #category : 'status' }
GPHRunBatch >> changeState: aState [

	mutex critical: [
		state := aState.
		self writeStatus ]
]

{ #category : 'accessing' }
GPHRunBatch >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHRunBatch >> clock: aClock [

	clock := aClock
]

{ #category : 'accessing' }
GPHRunBatch >> comparisonEntries [

	^ comparisonEntries
]

{ #category : 'accessing' }
GPHRunBatch >> comparisonTimeout [

	^ comparisonTimeout
]

{ #category : 'accessing' }
GPHRunBatch >> comparisonTimeout: aDuration [

	comparisonTimeout := aDuration
]

{ #category : 'accessing' }
GPHRunBatch >> comparisons [

	^ comparisons
]

{ #category : 'accessing' }
GPHRunBatch >> comparisons: aCollectionOfAssociations [
	"Each element is runIdD -> runIdH."

	comparisons := aCollectionOfAssociations asOrderedCollection
]

{ #category : 'accessing' }
GPHRunBatch >> configs [

	^ configs
]

{ #category : 'accessing' }
GPHRunBatch >> configs: aCollectionOfRunConfigs [

	configs := aCollectionOfRunConfigs asOrderedCollection
]

{ #category : 'running' }
GPHRunBatch >> failWith: anError [
	"Record an unexpected error of the batch loop (redacted). The run in progress, if any, is not stopped: it keeps its own status and is flagged in the batch status."

	mutex critical: [
		errorMessage := redactor redact: anError description.
		runEntries
			select: [ :entry | entry isRunning ]
			thenDo: [ :entry |
				entry noteError:
					'batch failed while this run was in progress; the run was not stopped' ].
		state := #failed.
		endedAt := clock now.
		self writeStatusAfterFailure ]
]

{ #category : 'running' }
GPHRunBatch >> finish [
	"End of the sequence: done, or stopped when a stop was requested meanwhile (whichever of the batch process and #stop gets there first records the stopped entries)."

	mutex critical: [
		stopRequested
			ifTrue: [
				self recordStoppedEntries.
				self finishWith: #stopped ]
			ifFalse: [ self finishWith: #done ] ]
]

{ #category : 'running' }
GPHRunBatch >> finishWith: aState [
	"Publish a terminal state once; a stopped or failed batch is never turned into done."

	mutex critical: [
		self isFinished ifFalse: [
			state := aState.
			endedAt := clock now.
			self writeStatus ] ]
]

{ #category : 'accessing' }
GPHRunBatch >> garbageCollector [
	"A block run after each run, once its model is released; a full garbage collection by default."

	^ garbageCollector ifNil: [
		  garbageCollector := [ Smalltalk garbageCollect ] ]
]

{ #category : 'accessing' }
GPHRunBatch >> garbageCollector: aBlock [
	"Injection point, mainly for tests (e.g. an empty block to avoid full garbage collections)."

	garbageCollector := aBlock
]

{ #category : 'initialization' }
GPHRunBatch >> initialize [

	super initialize.
	configs := OrderedCollection new.
	comparisons := OrderedCollection new.
	pauseBetweenRuns := Duration zero.
	waitAllowance := 2 hours.
	comparisonTimeout := 1 hour.
	clock := GPHClock new.
	redactor := GPHTokenProvider new.
	stopRequested := false.
	state := #pending.
	runEntries := #(  ).
	comparisonEntries := #(  ).
	mutex := Mutex new.
	stopSignal := Semaphore new
]

{ #category : 'testing' }
GPHRunBatch >> isFinished [

	^ #( #done #stopped #failed ) includes: state
]

{ #category : 'testing' }
GPHRunBatch >> isFinished: anId [
	"Whether the run or comparison anId of the registry reached a terminal state."

	^ (self registry handleAt: anId) isFinished
]

{ #category : 'testing' }
GPHRunBatch >> isStopRequested [

	^ stopRequested
]

{ #category : 'running' }
GPHRunBatch >> launch: anEntry [
	"Launch under the mutex, so that a concurrent #stop either prevents the launch or sees the run as running and stops it. The memory in use is read just before the launch."

	mutex critical: [
			stopRequested ifTrue: [ ^ self ].
			anEntry recordMemoryBeforeLaunch: self memoryProbe value.
			self registry launch: anEntry config.
			currentIndex := anEntry index.
			currentRunId := anEntry runId.
			anEntry markLaunchedAt: clock now.
			self writeStatus ]
]

{ #category : 'accessing' }
GPHRunBatch >> memoryProbe [
	"A block answering the memory in use, in bytes; old-space bytes in use by default (GPHRunBatch class>>#usedOldSpaceBytes)."

	^ memoryProbe ifNil: [
		  memoryProbe := [ self class usedOldSpaceBytes ] ]
]

{ #category : 'accessing' }
GPHRunBatch >> memoryProbe: aBlock [
	"Injection point, mainly for tests."

	memoryProbe := aBlock
]

{ #category : 'accessing' }
GPHRunBatch >> outputDirectory [

	^ self registry outputRoot / batchId
]

{ #category : 'running' }
GPHRunBatch >> pause [
	"Wait pauseBetweenRuns; #stop wakes the batch up."

	stopRequested ifTrue: [ ^ self ].
	pauseBetweenRuns > Duration zero ifFalse: [ ^ self ].
	stopSignal waitTimeoutMilliseconds: pauseBetweenRuns asMilliSeconds
]

{ #category : 'accessing' }
GPHRunBatch >> pauseBetweenRuns [

	^ pauseBetweenRuns
]

{ #category : 'accessing' }
GPHRunBatch >> pauseBetweenRuns: aDuration [

	pauseBetweenRuns := aDuration
]

{ #category : 'running' }
GPHRunBatch >> prepareEntries [

	runEntries := configs asArray withIndexCollect: [ :config :index |
		              GPHBatchRunEntry index: index config: config ].
	comparisonEntries := comparisons asArray collect: [ :pair |
		                     GPHBatchComparisonEntry
			                     runIdD: pair key
			                     runIdH: pair value ]
]

{ #category : 'running' }
GPHRunBatch >> prepareRedactor [
	"Resolve the token once so that it can be redacted from the status; without a token there is nothing to redact."

	[ redactor token ]
		on: GPHMissingTokenError
		do: [ :missing | missing return: nil ]
]

{ #category : 'accessing' }
GPHRunBatch >> process [

	^ process
]

{ #category : 'running' }
GPHRunBatch >> recordComparison: anEntry [

	| comparisonStatus |
	comparisonStatus := self registry statusOf: anEntry compareId.
	mutex critical: [
		anEntry isRunning ifTrue: [ anEntry recordStatus: comparisonStatus ].
		self writeStatus ]
]

{ #category : 'running' }
GPHRunBatch >> recordOutcomeOf: anEntry [

	| runStatus |
	runStatus := self registry statusOf: anEntry runId.
	mutex critical: [
		anEntry isRunning ifTrue: [
			anEntry recordStatus: runStatus at: clock now ].
		self writeStatus ]
]

{ #category : 'running' }
GPHRunBatch >> recordStoppedEntries [
	"Record the runs and comparisons already ended by the stop and skip the pending ones. One still finalizing stays running: the batch process records it as soon as it is terminal."

	runEntries do: [ :entry |
			(entry isRunning and: [ self isFinished: entry runId ]) ifTrue: [
					entry
						recordStatus: (self registry statusOf: entry runId)
						at: clock now ].
			entry isPending ifTrue: [ entry markSkipped ] ].
	comparisonEntries do: [ :entry |
			(entry isRunning and: [ self isFinished: entry compareId ])
				ifTrue: [
				entry recordStatus: (self registry statusOf: entry compareId) ].
			entry isPending ifTrue: [ entry markSkipped ] ]
]

{ #category : 'accessing' }
GPHRunBatch >> redactor [

	^ redactor
]

{ #category : 'accessing' }
GPHRunBatch >> redactor: aTokenProvider [
	"Every batch-status.json is passed through aTokenProvider (#redact:) before being written."

	redactor := aTokenProvider
]

{ #category : 'accessing' }
GPHRunBatch >> registry [
	"The registry that launches the runs; GPHRunRegistry default unless one was given."

	^ registry ifNil: [ registry := GPHRunRegistry default ]
]

{ #category : 'accessing' }
GPHRunBatch >> registry: aRunRegistry [

	registry := aRunRegistry
]

{ #category : 'running' }
GPHRunBatch >> releaseModelOf: anEntry [
	"Release the in-memory model of the run (refused by the registry while the run is not terminal), run the garbage collector, and record the outcome, the memory in use after the collection and the collection duration. A failure of the release is recorded as not released and never fails the batch."

	| released gcMilliseconds memoryAfter |
	released := [ self registry releaseModelOf: anEntry runId ]
		            on: Error
		            do: [ :anError | anError return: false ].
	gcMilliseconds := Time millisecondsToRun: self garbageCollector.
	memoryAfter := self memoryProbe value.
	mutex critical: [
			anEntry
				recordModelReleased: released
				memoryAfterRelease: memoryAfter
				gcMs: gcMilliseconds.
			self writeStatus ]
]

{ #category : 'running' }
GPHRunBatch >> runAllEntries [
	"Strictly sequential: a run is launched only once the previous one is terminal. A failed run is recorded, never relaunched."

	runEntries do: [ :entry |
		stopRequested ifTrue: [ ^ self ].
		self runEntry: entry.
		entry == runEntries last ifFalse: [ self pause ] ]
]

{ #category : 'running' }
GPHRunBatch >> runComparison: anEntry [

	self startComparison: anEntry.
	anEntry isRunning ifFalse: [ ^ self ].
	self registry waitFor: anEntry compareId timeout: comparisonTimeout.
	(self isFinished: anEntry compareId) ifFalse: [
		^ self stopOverdueComparison: anEntry ].
	self recordComparison: anEntry
]

{ #category : 'running' }
GPHRunBatch >> runComparisons [

	comparisonEntries do: [ :entry |
		stopRequested ifTrue: [ ^ self ].
		self runComparison: entry ]
]

{ #category : 'accessing' }
GPHRunBatch >> runEntries [

	^ runEntries
]

{ #category : 'running' }
GPHRunBatch >> runEntry: anEntry [
	"Launch the run, wait for it (its export is written once it is terminal), record its outcome, then release its model and collect garbage, outside any measured step and before the pause and the next launch."

	self launch: anEntry.
	anEntry isRunning ifFalse: [ ^ self ].
	(self awaitRunOf: anEntry)
		ifTrue: [ self recordOutcomeOf: anEntry ]
		ifFalse: [ self stopOverdueRun: anEntry ].
	self releaseModelOf: anEntry
]

{ #category : 'running' }
GPHRunBatch >> runToCompletion [
	"Body of the batch process. An unexpected error fails the batch but never stops the run in progress."

	[
	self runAllEntries.
	self runComparisons.
	self finish ]
		on: Error
		do: [ :anError | self failWith: anError ]
]

{ #category : 'running' }
GPHRunBatch >> runningIds [

	^ (runEntries
		   select: [ :entry | entry isRunning ]
		   thenCollect: [ :entry | entry runId ]) asOrderedCollection
		  addAll: (comparisonEntries
				   select: [ :entry | entry isRunning ]
				   thenCollect: [ :entry | entry compareId ]);
		  yourself
]

{ #category : 'running' }
GPHRunBatch >> start [
	"Validate everything first (nothing is launched when a check fails), write the running status, then run the whole sequence in one background process."

	self validate.
	self prepareRedactor.
	self prepareEntries.
	startedAt := clock now.
	self changeState: #running.
	self class register: self.
	process := [ self runToCompletion ]
		           forkAt: Processor userBackgroundPriority
		           named: 'GPH-batch-' , batchId
]

{ #category : 'running' }
GPHRunBatch >> startComparison: anEntry [

	mutex critical: [
		| compareId |
		stopRequested ifTrue: [ ^ self ].
		compareId := self registry compare: anEntry runIdD with: anEntry runIdH.
		anEntry
			markStartedAs: compareId
			outputDirectory: (self registry outputDirectoryOf: compareId).
		self writeStatus ]
]

{ #category : 'accessing' }
GPHRunBatch >> state [

	^ state
]

{ #category : 'status' }
GPHRunBatch >> status [
	"The status Dictionary, as written in batch-status.json."

	^ mutex critical: [
		  OrderedDictionary new
			  at: 'batchId' put: batchId;
			  at: 'state' put: state;
			  at: 'startedAt' put: (GPHTime iso: startedAt);
			  at: 'updatedAt' put: (GPHTime iso: clock now);
			  at: 'endedAt' put: (GPHTime iso: endedAt);
			  at: 'currentIndex' put: currentIndex;
			  at: 'currentRunId' put: currentRunId;
			  at: 'error' put: errorMessage;
			  at: 'runs'
			  put: (runEntries collect: [ :entry | entry asDictionary ]);
			  at: 'comparisons'
			  put: (comparisonEntries collect: [ :entry | entry asDictionary ]);
			  yourself ]
]

{ #category : 'accessing' }
GPHRunBatch >> statusFile [

	^ self outputDirectory / self class statusFileName
]

{ #category : 'running' }
GPHRunBatch >> stop [
	"Stop the run (or comparison) in progress through the registry, skip the remaining ones, publish the stopped state, then wait for the batch process to end."

	| running |
	mutex critical: [
		state = #running ifFalse: [ ^ self ].
		stopRequested := true.
		running := self runningIds ].
	stopSignal signal.
	running do: [ :id | self registry stop: id ].
	mutex critical: [
		self recordStoppedEntries.
		self finishWith: #stopped ].
	self waitForProcessEnd
]

{ #category : 'running' }
GPHRunBatch >> stopOverdueComparison: anEntry [

	self registry stop: anEntry compareId.
	self recordComparison: anEntry.
	mutex critical: [
		anEntry noteError: 'comparison wait of '
			, comparisonTimeout asSeconds printString
			, ' s exceeded; comparison stopped by the batch'.
		self writeStatus ]
]

{ #category : 'running' }
GPHRunBatch >> stopOverdueRun: anEntry [
	"The watchdog should have ended the run long ago: stop it rather than measure two runs concurrently."

	self registry stop: anEntry runId.
	self recordOutcomeOf: anEntry.
	mutex critical: [
		anEntry noteError: 'batch wait of '
			, (anEntry config globalTimeout + waitAllowance) asSeconds
					printString , ' s exceeded; run stopped by the batch'.
		self writeStatus ]
]

{ #category : 'validating' }
GPHRunBatch >> validate [
	"Fail fast before launching anything."

	state = #pending ifFalse: [
		GPHConfigurationError signal: 'Batch already started: ' , batchId asString ].
	(batchId isNil or: [ batchId isEmpty ]) ifTrue: [
		GPHConfigurationError signal: 'batchId is required' ].
	(self class batches includesKey: batchId) ifTrue: [
		GPHConfigurationError signal: 'Batch id already used: ' , batchId ].
	self statusFile exists ifTrue: [
		GPHConfigurationError signal:
			'Batch status already exists: ' , self statusFile fullName ].
	configs ifEmpty: [
		GPHConfigurationError signal: 'A batch needs at least one run config' ].
	configs do: [ :config | self validateConfig: config ].
	self validateRunIds.
	self validateComparisons
]

{ #category : 'validating' }
GPHRunBatch >> validateComparisons [
	"A comparison refers to a run of the batch or to a run already exported."

	| runIds |
	runIds := (configs collect: [ :config | config runId ]) asSet.
	comparisons do: [ :pair |
		{
			pair key.
			pair value } do: [ :runId |
			((runIds includes: runId) or: [
				 (self registry outputDirectoryOf: runId) exists ]) ifFalse: [
				GPHConfigurationError signal:
					'Comparison refers to an unknown run: ' , runId asString ] ] ]
]

{ #category : 'validating' }
GPHRunBatch >> validateConfig: aRunConfig [
	"A valid configuration whose run was never launched and has no output folder yet."

	aRunConfig validate.
	(self registry runIds includes: aRunConfig runId) ifTrue: [
		GPHConfigurationError signal:
			'Run id already launched: ' , aRunConfig runId ].
	aRunConfig outputDirectory exists ifTrue: [
		GPHConfigurationError signal:
			'Output folder already exists: ' , aRunConfig outputDirectory fullName ]
]

{ #category : 'validating' }
GPHRunBatch >> validateRunIds [

	| runIds duplicates |
	runIds := configs collect: [ :config | config runId ].
	duplicates := (runIds select: [ :runId | (runIds occurrencesOf: runId) > 1 ])
		              asSet.
	duplicates ifNotEmpty: [
		GPHConfigurationError signal:
			'Duplicate run ids in batch: ' , (', ' join: duplicates sorted) ]
]

{ #category : 'accessing' }
GPHRunBatch >> waitAllowance [

	^ waitAllowance
]

{ #category : 'accessing' }
GPHRunBatch >> waitAllowance: aDuration [
	"Added to the globalTimeout of a run to bound the in-image wait; covers the rate-limit gate wait that precedes the watchdog."

	waitAllowance := aDuration
]

{ #category : 'running' }
GPHRunBatch >> waitForProcessEnd [
	"The batch process notices the stop within one polling period of #waitFor:timeout:; terminate it only if it does not."

	| deadline |
	(process isNil or: [ process == Processor activeProcess ]) ifTrue: [
		^ self ].
	deadline := Time millisecondClockValue + 5000.
	[ process isTerminated or: [ Time millisecondClockValue > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	process isTerminated ifFalse: [ process terminate ]
]

{ #category : 'status' }
GPHRunBatch >> writeStatus [
	"Atomic write of batch-status.json, redacted from the token."

	GPHJsonFile
		write: self status
		to: self statusFile
		redactor: redactor
]

{ #category : 'running' }
GPHRunBatch >> writeStatusAfterFailure [
	"Last resort: the failure may come from writing the status itself. The status stays readable in memory (#status, GPHRunBatch class>>#statusOf:)."

	[ self writeStatus ]
		on: Error
		do: [ :writeError | writeError return: nil ]
]
