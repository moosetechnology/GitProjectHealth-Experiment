"
Tests of GPHRunBatch on its own GPHRunRegistry (memory file system, fake steps); never touches GPHRunRegistry default.
"
Class {
	#name : 'GPHRunBatchTest',
	#superclass : 'TestCase',
	#instVars : [
		'registry',
		'fileSystem',
		'stepsBlock',
		'factoryBlock',
		'events',
		'batch'
	],
	#category : 'GPHExperiment-Harness-Tests-Run',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Run'
}

{ #category : 'helpers' }
GPHRunBatchTest >> assertStartFailsAndLaunchesNothing [

	self should: [ batch start ] raise: GPHConfigurationError.
	self assert: registry runIds isEmpty.
	self assert: batch state equals: #pending.
	self deny: self statusFile exists.
	self deny: (GPHRunBatch all includesKey: batch batchId).
	self assert: events isEmpty
]

{ #category : 'helpers' }
GPHRunBatchTest >> batchOf: aCollectionOfRunIds [

	batch := GPHRunBatch new
		         batchId: 'gph-batch-test';
		         registry: registry;
		         clock: GPHClock new;
		         redactor: self tokenProvider;
		         configs: (aCollectionOfRunIds collect: [ :runId |
					          self configNamed: runId ]);
		         yourself.
	^ batch
]

{ #category : 'helpers' }
GPHRunBatchTest >> configNamed: aRunId [

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

{ #category : 'helpers' }
GPHRunBatchTest >> failingStepsOf: aRunner [

	^ {
		  (GPHStep named: 'project' do: [
				   events add: 'start:' , aRunner runId.
				   GPHRepositoryNotFoundError signal:
					   'Repository not found: o/r SECRET-BATCH' ]).
		  (GPHStep finalization: 'export' do: [ aRunner export ]) }
]

{ #category : 'helpers' }
GPHRunBatchTest >> newRunnerOn: aRunConfig [

	| runner |
	runner := GPHRunner on: aRunConfig.
	runner
		tokenProvider: self tokenProvider;
		steps: (stepsBlock value: runner).
	^ runner
]

{ #category : 'helpers' }
GPHRunBatchTest >> recordingStepsOf: aRunner milliseconds: aNumber [
	"One measured step recording its start and end in events, then the export."

	^ {
		  (GPHStep named: 'commits' do: [
				   events add: 'start:' , aRunner runId.
				   (Delay forMilliseconds: aNumber) wait.
				   events add: 'end:' , aRunner runId ]).
		  (GPHStep finalization: 'export' do: [ aRunner export ]) }
]

{ #category : 'helpers' }
GPHRunBatchTest >> runStatesIn: aStatus [

	^ (aStatus at: 'runs') collect: [ :run | (run at: 'state') asString ]
]

{ #category : 'running' }
GPHRunBatchTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory.
	events := OrderedCollection new.
	stepsBlock := [ :runner | self recordingStepsOf: runner milliseconds: 50 ].
	factoryBlock := [ :config | self newRunnerOn: config ].
	registry := GPHRunRegistry new
		            outputRoot: fileSystem root / 'out';
		            clock: GPHClock new;
		            runnerFactory: [ :config | factoryBlock value: config ];
		            yourself
]

{ #category : 'helpers' }
GPHRunBatchTest >> statusFile [

	^ fileSystem root / 'out' / 'gph-batch-test' / 'batch-status.json'
]

{ #category : 'running' }
GPHRunBatchTest >> tearDown [
	"Never leave a batch, a run or a watchdog process behind, nor a test batch in the class-side registry. Comparison jobs of these tests end on their own within milliseconds."

	batch ifNotNil: [
			batch process ifNotNil: [ :process | process terminate ].
			(GPHRunBatch all at: batch batchId ifAbsent: [ nil ]) == batch
				ifTrue: [ GPHRunBatch forget: batch batchId ] ].
	registry runIds
		reject: [ :id | id beginsWith: 'compare-' ]
		thenDo: [ :id |
				| handle |
				handle := registry handleAt: id.
				handle watchdog ifNotNil: [ :watchdog | watchdog terminate ].
				handle process ifNotNil: [ :process | process terminate ] ].
	super tearDown
]

{ #category : 'tests' }
GPHRunBatchTest >> testComparisonIsExecutedAfterTheRuns [

	| status comparison |
	self batchOf: #( 'run-d' 'run-h' ).
	batch addComparison: 'run-d' -> 'run-h'.
	batch start.

	self waitForBatch.

	status := GPHJsonFile read: self statusFile.
	self assert: (status at: 'state') equals: 'done'.
	comparison := (status at: 'comparisons') first.
	self assert: (comparison at: 'runIdD') equals: 'run-d'.
	self assert: (comparison at: 'runIdH') equals: 'run-h'.
	self assert: (comparison at: 'state') equals: 'done'.
	self assert: ((comparison at: 'compareId') beginsWith: 'compare-run-d-vs-run-h-').
	self
		assert: (comparison at: 'outputDirectory')
		equals: (fileSystem root / 'out' / (comparison at: 'compareId')) fullName.
	self assert: (fileSystem root / 'out' / (comparison at: 'compareId') / 'consistency.json') exists
]

{ #category : 'tests' }
GPHRunBatchTest >> testDuplicateRunIdLaunchesNothing [

	self batchOf: #( 'run-1' 'run-2' 'run-1' ).

	self assertStartFailsAndLaunchesNothing
]

{ #category : 'tests' }
GPHRunBatchTest >> testExistingOutputFolderLaunchesNothing [

	(fileSystem root / 'out' / 'run-2') ensureCreateDirectory.
	self batchOf: #( 'run-1' 'run-2' ).

	self assertStartFailsAndLaunchesNothing
]

{ #category : 'tests' }
GPHRunBatchTest >> testFailedRunDoesNotStopTheBatch [

	| status |
	stepsBlock := [ :runner |
		runner runId = 'run-2'
			ifTrue: [ self failingStepsOf: runner ]
			ifFalse: [ self recordingStepsOf: runner milliseconds: 50 ] ].
	(self batchOf: #( 'run-1' 'run-2' 'run-3' )) start.

	self waitForBatch.

	status := GPHJsonFile read: self statusFile.
	self assert: (status at: 'state') equals: 'done'.
	self assert: (self runStatesIn: status) asArray equals: #( 'done' 'failed' 'done' ).
	self
		assert: (((status at: 'runs') second at: 'error') at: 'class')
		equals: 'GPHRepositoryNotFoundError'.
	self assert: (events select: [ :event | event = 'start:run-2' ]) size equals: 1
]

{ #category : 'tests' }
GPHRunBatchTest >> testInvalidConfigLaunchesNothing [

	self batchOf: #( 'run-1' 'run-2' ).
	batch configs last repo: 'not-a-repo'.

	self assertStartFailsAndLaunchesNothing
]

{ #category : 'tests' }
GPHRunBatchTest >> testNoTokenInBatchStatus [

	| contents |
	stepsBlock := [ :runner | self failingStepsOf: runner ].
	(self batchOf: #( 'run-1' 'run-2' )) start.

	self waitForBatch.

	contents := self statusFile contents.
	self deny: (contents includesSubstring: 'SECRET-BATCH').
	self deny: (contents includesSubstring: 'token').
	self assert: (contents includesSubstring: '[REDACTED]')
]

{ #category : 'tests' }
GPHRunBatchTest >> testRunsAreExecutedStrictlyInOrder [

	| status |
	(self batchOf: #( 'run-1' 'run-2' 'run-3' )) start.

	self waitForBatch.

	self assert: events asArray equals: #( 'start:run-1' 'end:run-1' 'start:run-2' 'end:run-2' 'start:run-3' 'end:run-3' ).
	self assert: batch state equals: #done.
	self assert: batch process isTerminated.
	self assert: (batch process name) equals: 'GPH-batch-gph-batch-test'.
	self assert: (GPHRunBatch named: 'gph-batch-test') identicalTo: batch.
	status := GPHJsonFile read: self statusFile.
	self assert: (status at: 'batchId') equals: 'gph-batch-test'.
	self assert: (status at: 'state') equals: 'done'.
	self assert: (self runStatesIn: status) asArray equals: #( 'done' 'done' 'done' ).
	self assert: ((status at: 'runs') collect: [ :run | run at: 'index' ]) asArray equals: #( 1 2 3 ).
	self assert: ((status at: 'runs') allSatisfy: [ :run |
			 (run at: 'launchedAt') notNil and: [ (run at: 'endedAt') notNil ] ]).
	self assert: ((status at: 'runs') first at: 'repo') equals: 'o/r'.
	self assert: (status at: 'endedAt') notNil.
	self assert: (status at: 'currentRunId') equals: 'run-3'
]

{ #category : 'tests' }
GPHRunBatchTest >> testStopDuringSecondRunSkipsTheRest [

	| status |
	stepsBlock := [ :runner |
		self recordingStepsOf: runner milliseconds: (runner runId = 'run-2'
				 ifTrue: [ 10000 ]
				 ifFalse: [ 50 ]) ].
	(self batchOf: #( 'run-1' 'run-2' 'run-3' )) start.
	self waitUntil: [ events includes: 'start:run-2' ].

	batch stop.

	self assert: batch state equals: #stopped.
	self assert: batch process isTerminated.
	self assert: ((registry statusOf: 'run-2') at: 'state') equals: #stopped.
	self deny: (registry runIds includes: 'run-3').
	status := GPHJsonFile read: self statusFile.
	self assert: (status at: 'state') equals: 'stopped'.
	self assert: (self runStatesIn: status) asArray equals: #( 'done' 'stopped' 'skipped' )
]

{ #category : 'tests' }
GPHRunBatchTest >> testUnexpectedErrorFailsTheBatchRedacted [

	| status contents |
	factoryBlock := [ :config |
		config runId = 'run-2' ifTrue: [ Error signal: 'factory broken SECRET-BATCH' ].
		self newRunnerOn: config ].
	(self batchOf: #( 'run-1' 'run-2' 'run-3' )) start.

	self waitForBatch.

	contents := self statusFile contents.
	status := GPHJsonFile read: self statusFile.
	self assert: batch state equals: #failed.
	self assert: (status at: 'state') equals: 'failed'.
	self assert: ((status at: 'error') includesSubstring: 'factory broken').
	self deny: (contents includesSubstring: 'SECRET-BATCH').
	self assert: (self runStatesIn: status) asArray equals: #( 'done' 'pending' 'pending' ).
	self deny: (registry runIds includes: 'run-2')
]

{ #category : 'tests' }
GPHRunBatchTest >> testUnknownComparisonRunLaunchesNothing [

	self batchOf: #( 'run-1' ).
	batch addComparison: 'run-1' -> 'no-such-run'.

	self assertStartFailsAndLaunchesNothing
]

{ #category : 'helpers' }
GPHRunBatchTest >> tokenProvider [

	^ GPHTokenProvider token: 'SECRET-BATCH' source: 'env'
]

{ #category : 'helpers' }
GPHRunBatchTest >> waitForBatch [
	"Poll the batch until it is finished (at most 5 s)."

	| deadline |
	deadline := Time millisecondClockValue + 5000.
	[ batch isFinished or: [ Time millisecondClockValue > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	self assert: batch isFinished description: 'batch not finished in 5 s'.
	(Delay forMilliseconds: 50) wait
]

{ #category : 'helpers' }
GPHRunBatchTest >> waitUntil: aBlock [

	| deadline |
	deadline := Time millisecondClockValue + 3000.
	[ aBlock value or: [ Time millisecondClockValue > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	self assert: aBlock value
]
