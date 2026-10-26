"
Tests of the release of the in-memory model of a run: GPHRunner>>#releaseModel / #forceReleaseModel, GPHRunHandle>>#releaseModelIfNotRunning and GPHRunRegistry>>#releaseModelOf: / #releaseFinishedModels.
Nothing is launched: runners are put in a state with #changeState: (or run synchronously with an export step only), handles are registered directly in a fresh (non-default) registry, and a live run process is simulated by a never-resumed process (#newProcess), terminated in tearDown. No garbage collection is triggered.
"
Class {
	#name : 'GPHModelReleaseTest',
	#superclass : 'TestCase',
	#instVars : [
		'fileSystem',
		'registry',
		'dummyProcesses'
	],
	#category : 'GPHExperiment-Harness-Tests-Run',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Run'
}

{ #category : 'helpers' }
GPHModelReleaseTest >> assertModelIntactIn: aRunner [

	self deny: aRunner modelReleased.
	self assert: aRunner importers notNil.
	self assert: aRunner project notNil.
	self assert: aRunner localRepository notNil.
	self assert: aRunner windowCommits size equals: 2.
	self assert: aRunner windowShas size equals: 2.
	self assert: aRunner windowAuthors size equals: 1.
	self assert: aRunner pullRequests size equals: 1.
	self assert: aRunner resolutions size equals: 1.
	self assert: aRunner branchesBySha size equals: 1.
	self assert: aRunner headResolvable size equals: 1.
	self assert: aRunner fallbacks size equals: 2
]

{ #category : 'helpers' }
GPHModelReleaseTest >> assertModelReleasedIn: aRunner [
	"The imported data is dropped; the fallbacks observed before the release are still reported."

	self assert: aRunner modelReleased.
	self assert: aRunner importers isNil.
	self assert: aRunner project isNil.
	self assert: aRunner localRepository isNil.
	self assert: aRunner windowCommits isEmpty.
	self assert: aRunner windowShas isEmpty.
	self assert: aRunner windowAuthors isEmpty.
	self assert: aRunner pullRequests isEmpty.
	self assert: aRunner resolutions isEmpty.
	self assert: aRunner branchesBySha isEmpty.
	self assert: aRunner headResolvable isEmpty.
	self assert: aRunner fallbacks size equals: 2
]

{ #category : 'helpers' }
GPHModelReleaseTest >> liveProcess [
	"A process that is alive (not terminated) but never resumed; terminated in tearDown."

	^ dummyProcesses add: [ ] newProcess
]

{ #category : 'helpers' }
GPHModelReleaseTest >> newRunner: aRunId [
	"A runner whose files go to the in-memory output root; never run against GitHub."

	^ (GPHRunner on: ((GPHRunConfig
				     repo: 'o/r'
				     mode: #D
				     since: '2026-01-01T00:00:00Z'
				     until: '2026-02-01T00:00:00Z')
				    runId: aRunId;
				    outputRoot: fileSystem root / 'out';
				    cloneRoot: fileSystem root / 'clones';
				    apiBaseUrl: 'http://localhost:9';
				    yourself))
		  clock: GPHFakeClock new;
		  tokenProvider:
		  (GPHTokenProvider token: 'SECRET-RELEASE' source: 'env');
		  yourself
]

{ #category : 'helpers' }
GPHModelReleaseTest >> populate: aRunner [
	"Simulate imported data: an importer set whose local importer observed 2 fallbacks, a project, an opened clone and non-empty collections. The collections without a setter are injected with instVarNamed:put:."

	| local |
	local := GPHObservedLocalModelImporter new.
	local
		recordFallback: #importDiffOfCommit: sha: 'aaaa' error: Error new;
		recordFallback: #importCommit:ofProject:
		sha: 'bbbb'
		error: Error new.
	aRunner
		importers: (GPHImporterSet new
				 local: local;
				 yourself);
		project: Object new;
		localRepository: Object new;
		pullRequests: { Object new }.
	aRunner instVarNamed: 'windowCommits' put: {
			Object new.
			Object new }.
	aRunner instVarNamed: 'windowShas' put: #( 'aaaa' 'bbbb' ) asSet.
	aRunner instVarNamed: 'windowAuthors' put: { Object new }.
	aRunner instVarNamed: 'resolutions' put: (IdentityDictionary new
			 at: Object new put: #merged;
			 yourself).
	aRunner instVarNamed: 'branchesBySha' put: (Dictionary new
			 at: 'aaaa' put: #( 'main' );
			 yourself).
	aRunner instVarNamed: 'headResolvable' put: (Dictionary new
			 at: 'aaaa' put: true;
			 yourself).
	^ aRunner
]

{ #category : 'helpers' }
GPHModelReleaseTest >> register: aRunner process: aRunProcess watchdog: aWatchdogProcess [
	"Register a handle of aRunner in the test registry with the given (simulated) run and watchdog processes, each possibly nil; nothing is started."

	| handle |
	handle := GPHRunHandle registry: registry runner: aRunner.
	handle instVarNamed: 'process' put: aRunProcess.
	handle instVarNamed: 'watchdog' put: aWatchdogProcess.
	registry register: handle as: aRunner runId.
	^ handle
]

{ #category : 'helpers' }
GPHModelReleaseTest >> runner: aRunId inState: aState [
	"A populated runner put in aState without running anything (#pending is the initial state)."

	| runner |
	runner := self populate: (self newRunner: aRunId).
	aState = #pending ifFalse: [ runner changeState: aState ].
	^ runner
]

{ #category : 'running' }
GPHModelReleaseTest >> setUp [
	"A fresh registry (never GPHRunRegistry default) whose factory refuses any launch: these tests register their handles directly."

	super setUp.
	fileSystem := FileSystem memory.
	dummyProcesses := OrderedCollection new.
	registry := GPHRunRegistry new
		            outputRoot: fileSystem root / 'out';
		            clock: GPHClock new;
		            runnerFactory: [ :config |
			            self error: 'no run is launched in these tests' ];
		            yourself
]

{ #category : 'running' }
GPHModelReleaseTest >> tearDown [
	"The simulated run and watchdog processes were never resumed; terminate them."

	dummyProcesses do: [ :process | process terminate ].
	super tearDown
]

{ #category : 'helpers' }
GPHModelReleaseTest >> terminatedProcess [

	| process |
	process := [ ] newProcess.
	process terminate.
	^ process
]

{ #category : 'tests - runner' }
GPHModelReleaseTest >> testFallbacksSoFarIsUnchangedByTheRelease [
	"The status keeps reporting the fallbacks observed before the release (copied in releasedFallbacks)."

	| runner before after |
	runner := self runner: 'run-done' inState: #done.
	before := runner statusDictionary.

	runner releaseModel.
	after := runner statusDictionary.

	self assert: (before at: 'fallbacksSoFar') equals: 2.
	self assert: (after at: 'fallbacksSoFar') equals: 2.
	self assert: (after at: 'state') equals: #done
]

{ #category : 'tests - handle' }
GPHModelReleaseTest >> testHandleRefusesPendingOrFinalizingRun [
	"Without any live process, a pending run (nothing imported yet) or a run being finalized is left alone."

	| pending finalizing pendingHandle finalizingHandle |
	pending := self runner: 'run-pending' inState: #pending.
	pendingHandle := self register: pending process: nil watchdog: nil.
	finalizing := self runner: 'run-finalizing' inState: #finalizing.
	finalizingHandle := self
		                    register: finalizing
		                    process: self terminatedProcess
		                    watchdog: nil.

	self deny: pendingHandle hasLiveProcess.
	self deny: pendingHandle releaseModelIfNotRunning.
	self deny: finalizingHandle releaseModelIfNotRunning.

	self assertModelIntactIn: pending.
	self assertModelIntactIn: finalizing
]

{ #category : 'tests - handle' }
GPHModelReleaseTest >> testHandleRefusesWhileARunOrWatchdogProcessIsLive [
	"A live run process, or a live watchdog (which finalizes a timed-out run), protects the model, even when the runner is already terminal."

	| running finishedWithWatchdog runningHandle watchdogHandle |
	running := self runner: 'run-live' inState: #running.
	runningHandle := self
		                 register: running
		                 process: self liveProcess
		                 watchdog: nil.
	finishedWithWatchdog := self runner: 'run-watchdog' inState: #timeout.
	watchdogHandle := self
		                  register: finishedWithWatchdog
		                  process: self terminatedProcess
		                  watchdog: self liveProcess.

	self assert: runningHandle hasLiveProcess.
	self assert: watchdogHandle hasLiveProcess.
	self deny: runningHandle releaseModelIfNotRunning.
	self deny: watchdogHandle releaseModelIfNotRunning.

	self assertModelIntactIn: running.
	self assertModelIntactIn: finishedWithWatchdog
]

{ #category : 'tests - handle' }
GPHModelReleaseTest >> testHandleReleasesFinishedRunOnce [

	| runner handle |
	runner := self runner: 'run-done' inState: #done.
	handle := self
		          register: runner
		          process: self terminatedProcess
		          watchdog: self terminatedProcess.

	self assert: handle releaseModelIfNotRunning.
	self assertModelReleasedIn: runner.
	self deny: handle releaseModelIfNotRunning.
	"#releaseModel itself stays idempotent on a finished run."
	self assert: handle releaseModel
]

{ #category : 'tests - handle' }
GPHModelReleaseTest >> testHandleReleasesStaleRunningRunOnce [
	"A run still #running whose process was terminated outside the harness can no longer progress: its model is force-released; a second call answers false (already released)."

	| runner handle |
	runner := self runner: 'run-stale' inState: #running.
	handle := self
		          register: runner
		          process: self terminatedProcess
		          watchdog: nil.

	self deny: handle hasLiveProcess.
	self assert: handle releaseModelIfNotRunning.
	self assertModelReleasedIn: runner.
	self assert: runner state equals: #running.
	self assert: (runner statusDictionary at: 'fallbacksSoFar') equals: 2.

	self deny: handle releaseModelIfNotRunning
]

{ #category : 'tests - registry' }
GPHModelReleaseTest >> testRegistryReleaseFinishedModelsSkipsLiveRunsAndComparisons [
	"On a test registry (never the default one): finished runs and a stale running run are released and their ids answered sorted; a live run, a run with a live watchdog, a pending run and a comparison job are skipped. A second call releases nothing."

	| live watchdogged pending compareJob |
	self
		register: (self runner: 'run-b' inState: #done)
		process: self terminatedProcess
		watchdog: nil.
	self
		register: (self runner: 'run-a' inState: #failed)
		process: nil
		watchdog: nil.
	self
		register: (self runner: 'run-f' inState: #running)
		process: self terminatedProcess
		watchdog: nil.
	live := self runner: 'run-c' inState: #running.
	self register: live process: self liveProcess watchdog: nil.
	watchdogged := self runner: 'run-e' inState: #timeout.
	self register: watchdogged process: nil watchdog: self liveProcess.
	pending := self runner: 'run-d' inState: #pending.
	self register: pending process: nil watchdog: nil.
	compareJob := GPHCompareJob new
		              id: 'compare-run-a-vs-run-b-x';
		              yourself.
	registry register: compareJob as: compareJob id.

	self
		assert: registry releaseFinishedModels asArray
		equals: #( 'run-a' 'run-b' 'run-f' ).

	#( 'run-a' 'run-b' 'run-f' ) do: [ :id |
		self assertModelReleasedIn: (registry handleAt: id) runner ].
	self assertModelIntactIn: live.
	self assertModelIntactIn: watchdogged.
	self assertModelIntactIn: pending.
	self deny: compareJob releaseModel.
	self assert: registry releaseFinishedModels isEmpty
]

{ #category : 'tests - registry' }
GPHModelReleaseTest >> testRegistryReleaseModelOfAnswersWhetherReleased [

	| running done |
	running := self runner: 'run-running' inState: #running.
	self register: running process: self liveProcess watchdog: nil.
	done := self runner: 'run-done' inState: #done.
	self register: done process: self terminatedProcess watchdog: nil.

	self deny: (registry releaseModelOf: 'run-running').
	self assertModelIntactIn: running.
	self assert: (registry releaseModelOf: 'run-done').
	self assertModelReleasedIn: done.
	self
		should: [ registry releaseModelOf: 'no-such-run' ]
		raise: GPHUnknownRunError
]

{ #category : 'tests - runner' }
GPHModelReleaseTest >> testRunnerRefusesToReleaseWhileNotFinished [
	"Pending, running or finalizing: releaseModel answers false and leaves every imported datum in place."

	#( #pending #running #finalizing ) do: [ :state |
			| runner |
			runner := self runner: 'run-' , state inState: state.
			self deny: runner releaseModel.
			self assert: runner state equals: state.
			self assertModelIntactIn: runner ]
]

{ #category : 'tests - runner' }
GPHModelReleaseTest >> testRunnerReleaseIsIdempotent [
	"A second release still answers true and does not lose the fallbacks copied by the first one."

	| runner |
	runner := self runner: 'run-done' inState: #done.

	self assert: runner releaseModel.
	self assert: runner releaseModel.

	self assertModelReleasedIn: runner.
	self
		assert:
		(runner fallbacks collect: [ :fallback | fallback sha ]) asArray
		equals: #( 'aaaa' 'bbbb' )
]

{ #category : 'tests - runner' }
GPHModelReleaseTest >> testRunnerReleasesAfterARealSynchronousRun [
	"A runner run synchronously (export step only, in-memory files) ends done; its export is on disk and its model can be released."

	| runner |
	runner := self newRunner: 'run-sync'.
	runner steps:
		{ (GPHStep finalization: 'export' do: [ runner export ]) }.
	self deny: runner modelReleased.

	runner run.

	self assert: runner state equals: #done.
	self assert: (runner outputDirectory / 'counts.json') exists.
	self assert: runner releaseModel.
	self assert: runner modelReleased.
	self assert: runner importers isNil.
	self assert: (runner statusDictionary at: 'fallbacksSoFar') equals: 0
]

{ #category : 'tests - runner' }
GPHModelReleaseTest >> testRunnerReleasesInEveryTerminalState [
	"done, failed, timeout and stopped: releaseModel answers true, drops the imported data and keeps the state, configuration, recorder, timings and dates."

	self
		assert: GPHRunner terminalStates asArray
		equals: #( #done #failed #timeout #stopped ).
	GPHRunner terminalStates do: [ :state |
			| runner config recorder timings startedAt endedAt |
			runner := self runner: 'run-' , state inState: state.
			config := runner config.
			recorder := runner recorder.
			timings := runner timings.
			startedAt := runner startedAt.
			endedAt := runner endedAt.
			self assert: endedAt notNil.

			self assert: runner releaseModel.

			self assertModelReleasedIn: runner.
			self assert: runner state equals: state.
			self assert: runner isFinished.
			self assert: runner config identicalTo: config.
			self assert: runner recorder identicalTo: recorder.
			self assert: runner timings identicalTo: timings.
			self assert: runner startedAt equals: startedAt.
			self assert: runner endedAt equals: endedAt ]
]
