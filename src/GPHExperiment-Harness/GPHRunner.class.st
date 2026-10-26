"
I execute one run synchronously: preparation of the clone directory (H), the measured steps given by #stepsFor: (an ordered list of GPHStep, injectable with #steps:), then the finalization steps (annotate, export) which run even after a failure.

Each step updates the current step of the recorder and status.json, and records a GPHStepTiming whose net duration excludes rate-limit waits. Errors put the run in state failed with the class and the message redacted from the token.

Collaborators are injectable: clock, recorder, tokenProvider, importerFactory, rateLimitGate, exporter, listener, steps.
"
Class {
	#name : 'GPHRunner',
	#superclass : 'Object',
	#instVars : [
		'config',
		'mode',
		'clock',
		'recorder',
		'tokenProvider',
		'importerFactory',
		'rateLimitGate',
		'exporter',
		'listener',
		'steps',
		'importers',
		'project',
		'localRepository',
		'windowCommits',
		'windowShas',
		'windowAuthors',
		'pullRequests',
		'resolutions',
		'branchesBySha',
		'headResolvable',
		'cloneHeadSha',
		'cloneHeadDate',
		'gateCheck',
		'timings',
		'currentTiming',
		'measuredPhaseStarted',
		'state',
		'stepName',
		'stepStartedAt',
		'startedAt',
		'endedAt',
		'errorClassName',
		'errorMessage',
		'finalizationErrors',
		'statusMutex',
		'stateAtExport',
		'modelReleased',
		'releasedFallbacks'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHRunner class >> on: aRunConfig [

	^ self new
		  config: aRunConfig;
		  yourself
]

{ #category : 'accessing' }
GPHRunner class >> terminalStates [

	^ #( #done #failed #timeout #stopped )
]

{ #category : 'finalization' }
GPHRunner >> annotateBranches [
	"Finalization step annotate (H). Uses only the clone already opened by the clone step: never triggers a clone."

	| annotator |
	localRepository ifNil: [ ^ self ].
	annotator := GPHBranchAnnotator
		             on: localRepository
		             since: config since.
	annotator annotate.
	branchesBySha := annotator branchesBySha.
	cloneHeadSha := annotator headSha.
	cloneHeadDate := annotator headDate.
	pullRequests do: [ :pullRequest |
			pullRequest sha ifNotNil: [ :sha |
				headResolvable at: sha put: (annotator isResolvableLocally: sha) ] ]
]

{ #category : 'accessing' }
GPHRunner >> branchesBySha [

	^ branchesBySha
]

{ #category : 'accessing' }
GPHRunner >> branchesOfSha: aSha [

	^ (branchesBySha at: aSha ifAbsent: [ #(  ) ]) sorted
]

{ #category : 'steps' }
GPHRunner >> buildImporters [
	"Step build: fresh model and importers."

	importers := self mode buildImportersWith: self importerFactory
]

{ #category : 'state' }
GPHRunner >> changeState: aState [

	statusMutex critical: [
			state := aState.
			(self class terminalStates includes: aState) ifTrue: [
				endedAt := clock now ] ].
	self writeStatus
]

{ #category : 'accessing' }
GPHRunner >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHRunner >> clock: anObject [

	clock := anObject
]

{ #category : 'accessing' }
GPHRunner >> cloneHeadDate [

	^ cloneHeadDate
]

{ #category : 'accessing' }
GPHRunner >> cloneHeadMetadata [

	cloneHeadSha ifNil: [ ^ nil ].
	^ OrderedDictionary new
		  at: 'headSha' put: cloneHeadSha;
		  at: 'headCommittedDate' put: (GPHTime iso: cloneHeadDate);
		  at: 'warning' put: (cloneHeadDate < config until ifTrue: [
					   'clone HEAD is older than until: the end of the window may be missing from the clone' ]);
		  yourself
]

{ #category : 'accessing' }
GPHRunner >> cloneHeadSha [

	^ cloneHeadSha
]

{ #category : 'steps' }
GPHRunner >> cloneRepository [
	"Step clone (H): forces GitLocalModelImporter>>#tryClone: into workingDirectory/msr/<name>."

	localRepository := importers local gitRepositoryOf:
		                   project repository
]

{ #category : 'private' }
GPHRunner >> close: aTiming outcome: anOutcome [
	"The rate-limit waits recorded for the step (and its sub-steps) are subtracted from its net duration."

	aTiming
		finishAt: clock now
		milliseconds: clock milliseconds
		outcome: anOutcome
		recordedWaitMs: (recorder rateLimitWaitMsForStep: aTiming name)
]

{ #category : 'steps' }
GPHRunner >> collectWindowAuthors [

	windowAuthors := (windowCommits
		                  select: [ :commit | commit commitCreator notNil ]
		                  thenCollect: [ :commit | commit commitCreator ])
		                 asIdentitySet asArray
]

{ #category : 'accessing' }
GPHRunner >> config [

	^ config
]

{ #category : 'accessing' }
GPHRunner >> config: aRunConfig [

	config := aRunConfig.
	mode := nil
]

{ #category : 'accessing' }
GPHRunner >> currentTiming [

	^ currentTiming
]

{ #category : 'clone directory' }
GPHRunner >> deleteClone [
	"Cold H run: remove the previous clone, only when it is a direct child of the clone root."

	| clonePath |
	clonePath := self safeClonePath.
	clonePath exists ifTrue: [ clonePath ensureDeleteAll ]
]

{ #category : 'private' }
GPHRunner >> describe: anError [
	"The error message, never containing the token."

	^ tokenProvider redact: anError messageText asString
]

{ #category : 'accessing' }
GPHRunner >> endedAt [

	^ endedAt
]

{ #category : 'clone directory' }
GPHRunner >> ensureCloneExists [
	"Warm H run: the clone must already be there."

	self safeClonePath exists ifFalse: [
			GPHWarmMissError signal:
				'warm-miss: no clone at ' , self safeClonePath fullName ]
]

{ #category : 'private' }
GPHRunner >> enterStep: aTiming [

	recorder currentStep: aTiming name.
	statusMutex critical: [
			stepName := aTiming name.
			stepStartedAt := aTiming startedAt ].
	self writeStatus
]

{ #category : 'accessing' }
GPHRunner >> errorClassName [

	^ errorClassName
]

{ #category : 'status' }
GPHRunner >> errorDictionary [

	^ errorMessage ifNotNil: [ :message |
			  OrderedDictionary new
				  at: 'class' put: errorClassName;
				  at: 'message' put: message;
				  yourself ]
]

{ #category : 'accessing' }
GPHRunner >> errorMessage [

	^ errorMessage
]

{ #category : 'finalization' }
GPHRunner >> export [
	"Finalization step export."

	self exporter exportRun: self
]

{ #category : 'accessing' }
GPHRunner >> exporter [

	^ exporter ifNil: [ exporter := GPHRunExporter new ]
]

{ #category : 'accessing' }
GPHRunner >> exporter: anObject [

	exporter := anObject
]

{ #category : 'state' }
GPHRunner >> failWith: anError [
	"Record the error and publish the failed state at once. Last-resort path for an error escaping #run (e.g. while finalizing); #run itself publishes failed only after finalization."

	self recordError: anError.
	self changeState: #failed
]

{ #category : 'accessing' }
GPHRunner >> fallbacks [

	^ importers
		  ifNil: [ releasedFallbacks ifNil: [ #(  ) ] ]
		  ifNotNil: [ :importerSet | importerSet fallbacks ]
]

{ #category : 'accessing' }
GPHRunner >> finalizationErrors [

	^ finalizationErrors
]

{ #category : 'running' }
GPHRunner >> finalize [
	"Run annotate and export. A failure there is recorded, never propagated."

	self steps
		select: [ :step | step isFinalization ]
		thenDo: [ :step | self runFinalizationStep: step ]
]

{ #category : 'running' }
GPHRunner >> finalizeReporting: anExportState thenPublish: aTerminalState [
	"Run annotate and export while the state is finalizing, then publish the terminal state: a client that sees a terminal state always finds the export. anExportState is the state written to meta.json as stateAtExport."

	statusMutex critical: [ stateAtExport := anExportState ].
	self changeState: #finalizing.
	self finalize.
	self changeState: aTerminalState
]

{ #category : 'memory' }
GPHRunner >> forceReleaseModel [
	"Drop the imported data whatever the state. Only for a run that can no longer progress (see GPHRunHandle>>#releaseModelIfNotRunning); otherwise use #releaseModel.
	Dropped: importers (importer set: GLH model, API, local and mixed importers), project (GLHProject), localRepository (the opened clone), windowCommits and windowAuthors (model entities), pullRequests and resolutions (keyed by pull request entities), windowShas, branchesBySha and headResolvable (sha-indexed data only read by the export).
	Kept: config, mode, steps, recorder (API calls), timings, gateCheck, state, dates, errors, cloneHeadSha/cloneHeadDate (scalars), and the fallbacks, copied to releasedFallbacks so that the status keeps reporting them."

	statusMutex critical: [
			modelReleased == true ifFalse: [
				releasedFallbacks := self fallbacks asArray ].
			importers := nil.
			project := nil.
			localRepository := nil.
			windowCommits := #(  ).
			windowShas := Set new.
			windowAuthors := #(  ).
			pullRequests := #(  ).
			resolutions := IdentityDictionary new.
			branchesBySha := Dictionary new.
			headResolvable := Dictionary new.
			modelReleased := true ]
]

{ #category : 'steps' }
GPHRunner >> freezeWindowCommits [
	"End of step commits: the tool filters with strict bounds on the whole model, so the window [since, until) is computed here, on the repository commits, and frozen."

	windowCommits := (project repository commits select: [ :commit |
		                  config isInWindow: commit committed_date ])
		                 asArray.
	windowShas := windowCommits collect: [ :commit | commit id ] as: Set
]

{ #category : 'accessing' }
GPHRunner >> gateCheck [

	^ gateCheck
]

{ #category : 'accessing' }
GPHRunner >> headResolvable [

	^ headResolvable
]

{ #category : 'steps' }
GPHRunner >> importProject [
	"Step project, identical in both modes. GithubModelImporter>>#importProject:ofGroup: is avoided because it triggers #completeImportedProject: (pipelines, branches, commits). #parseProjectResult: creates no repository, hence the explicit GLHRepository."

	| api group |
	api := importers api.
	group := api ensureGroupNamed: config owner.
	project := api parseProjectResult: (api repoApi organizations
			            getRepository: config repositoryName
			            ofOrganization: config owner).
	project name ifNil: [
			GPHRepositoryNotFoundError signal:
				'Repository not found: ' , config repo ].
	project group: group.
	importers model add: project.
	project repository: GLHRepository new.
	importers model add: project repository
]

{ #category : 'steps' }
GPHRunner >> importPullRequests [
	"Step prs: list the pull requests created in the window, then import the merge commits."

	self substep: 'prs.list' do: [
			pullRequests := (self importer
				                 importMergeRequestsOfProject: project
				                 since: config since
				                 until: config until) asArray ].
	self substep: 'prs.mergeCommits' do: [ self resolveMergeCommits ]
]

{ #category : 'accessing' }
GPHRunner >> importer [
	"The importer driven by the run: GithubModelImporter in D, GitModelMixedImporter in H."

	^ importers importer
]

{ #category : 'accessing' }
GPHRunner >> importerFactory [

	^ importerFactory ifNil: [
			  importerFactory := GPHImporterFactory new
				                     recorder: recorder;
				                     clock: clock;
				                     tokenProvider: tokenProvider;
				                     since: config since;
				                     apiBaseUrl: config apiBaseUrl;
				                     yourself ]
]

{ #category : 'accessing' }
GPHRunner >> importerFactory: anObject [

	importerFactory := anObject
]

{ #category : 'accessing' }
GPHRunner >> importers [

	^ importers
]

{ #category : 'accessing' }
GPHRunner >> importers: anObject [
	"Injection point, mainly for tests."

	importers := anObject
]

{ #category : 'initialization' }
GPHRunner >> initialize [

	super initialize.
	clock := GPHClock new.
	recorder := GPHApiCallRecorder new.
	tokenProvider := GPHTokenProvider new.
	listener := GPHNullRunListener new.
	statusMutex := Mutex new.
	timings := OrderedCollection new.
	windowCommits := #(  ).
	windowShas := Set new.
	windowAuthors := #(  ).
	pullRequests := #(  ).
	resolutions := IdentityDictionary new.
	branchesBySha := Dictionary new.
	headResolvable := Dictionary new.
	finalizationErrors := OrderedDictionary new.
	measuredPhaseStarted := false.
	modelReleased := false.
	state := #pending
]

{ #category : 'state' }
GPHRunner >> interruptWith: aState reason: aString [
	"Called from another process after the run process was terminated (timeout or stop): close the open timings, record the reason, write the partial export, and only then publish aState."

	timings
		select: [ :timing | timing isOpen ]
		thenDo: [ :timing | self close: timing outcome: #interrupted ].
	currentTiming := nil.
	statusMutex critical: [
		errorMessage := tokenProvider redact: aString ].
	self finalizeReporting: aState thenPublish: aState
]

{ #category : 'testing' }
GPHRunner >> isFinished [

	^ self class terminalStates includes: self state
]

{ #category : 'accessing' }
GPHRunner >> isHeadResolvableLocally: aPullRequest [
	"Answer true/false once annotated, nil when unknown."

	^ headResolvable at: aPullRequest sha ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GPHRunner >> listener [

	^ listener
]

{ #category : 'accessing' }
GPHRunner >> listener: anObject [

	listener := anObject
]

{ #category : 'accessing' }
GPHRunner >> localRepository [

	^ localRepository
]

{ #category : 'accessing' }
GPHRunner >> localRepository: anObject [
	"Injection point, mainly for tests."

	localRepository := anObject
]

{ #category : 'accessing' }
GPHRunner >> mode [
	"Answer the mode strategy (GPHDirectMode or GPHHybridMode)."

	^ mode ifNil: [ mode := config modeStrategy ]
]

{ #category : 'accessing' }
GPHRunner >> model [

	^ importers ifNotNil: [ :importerSet | importerSet model ]
]

{ #category : 'accessing' }
GPHRunner >> modelReleased [
	"Whether the imported data was dropped (#releaseModel)."

	^ modelReleased ifNil: [ false ]
]

{ #category : 'accessing' }
GPHRunner >> outputDirectory [

	^ config outputDirectory
]

{ #category : 'steps' }
GPHRunner >> passRateLimitGate [
	"Step rateLimitGate: its wait is excluded from the net duration."

	gateCheck := self rateLimitGate pass.
	currentTiming addRateLimitWaitMs: gateCheck waitedMilliseconds.
	self changeState: #running
]

{ #category : 'accessing' }
GPHRunner >> project [

	^ project
]

{ #category : 'accessing' }
GPHRunner >> project: anObject [
	"Injection point, mainly for tests."

	project := anObject
]

{ #category : 'accessing' }
GPHRunner >> pullRequests [

	^ pullRequests
]

{ #category : 'accessing' }
GPHRunner >> pullRequests: anObject [
	"Injection point, mainly for tests."

	pullRequests := anObject
]

{ #category : 'accessing' }
GPHRunner >> rateLimitGate [

	^ rateLimitGate ifNil: [
			  rateLimitGate := GPHRateLimitGate new
				                   tokenProvider: tokenProvider;
				                   baseUrl: config apiBaseUrl;
				                   threshold: config rateLimitThreshold;
				                   clock: clock;
				                   listener: self;
				                   yourself ]
]

{ #category : 'accessing' }
GPHRunner >> rateLimitGate: anObject [

	rateLimitGate := anObject
]

{ #category : 'notifications' }
GPHRunner >> rateLimitGateWillWait: aRateLimitCheck [

	self changeState: #'waiting-rate-limit'
]

{ #category : 'state' }
GPHRunner >> recordError: anError [
	"Record the error class and its message, redacted from the token."

	statusMutex critical: [
			errorClassName := anError class name.
			errorMessage := self describe: anError ]
]

{ #category : 'accessing' }
GPHRunner >> recorder [

	^ recorder
]

{ #category : 'accessing' }
GPHRunner >> recorder: anObject [

	recorder := anObject
]

{ #category : 'memory' }
GPHRunner >> releaseModel [
	"Drop every reference to imported data once the run is finished (its export is written by then), so that the model can be garbage collected. Idempotent. Answer true when the model is released, false (and do nothing) while the run is not in a terminal state."

	self isFinished ifFalse: [ ^ false ].
	self forceReleaseModel.
	^ true
]

{ #category : 'accessing' }
GPHRunner >> resolutionOf: aPullRequest [

	^ resolutions at: aPullRequest ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GPHRunner >> resolutions [

	^ resolutions
]

{ #category : 'steps' }
GPHRunner >> resolveMergeCommitOf: aPullRequest [
	"Answer #'not-merged', #'in-window-model', or the category given by the mode (#api, #local, #'api-fallback', #'not-found')."

	| sha |
	(aPullRequest merged_at notNil and: [
		 aPullRequest merge_commit_sha notNil ]) ifFalse: [ ^ #'not-merged' ].
	sha := aPullRequest merge_commit_sha.
	(windowShas includes: sha) ifFalse: [
		^ self mode resolveOutOfWindowMergeCommit: sha for: self ].
	self importer importCommit: sha ofProject: project.
	^ #'in-window-model'
]

{ #category : 'steps' }
GPHRunner >> resolveMergeCommits [

	pullRequests do: [ :pullRequest |
			resolutions
				at: pullRequest
				put: (self resolveMergeCommitOf: pullRequest) ]
]

{ #category : 'running' }
GPHRunner >> run [
	"Run the measured steps, then the finalization steps (annotate, export) even after a failure. The terminal state (done or failed) is published only once finalization is over. The listener refuses finalization when the run was interrupted concurrently (timeout or stop): the interrupter finalizes instead."

	| succeeded |
	startedAt := clock now.
	self changeState: #running.
	succeeded := [
		             config validate.
		             self mode prepareCloneFor: self.
		             self runMeasuredSteps.
		             true ]
		             on: Error
		             do: [ :anError |
				             self recordError: anError.
				             false ].
	(listener claimFinalizationOf: self) ifFalse: [ ^ self ].
	succeeded
		ifTrue: [ self finalizeReporting: #running thenPublish: #done ]
		ifFalse: [ self finalizeReporting: #failed thenPublish: #failed ]
]

{ #category : 'running' }
GPHRunner >> runFinalizationStep: aStep [

	[
		self
			time: aStep name
			parent: nil
			measured: false
			do: aStep action ]
		on: Error
		do: [ :anError |
			finalizationErrors at: aStep name put: (self describe: anError) ]
]

{ #category : 'accessing' }
GPHRunner >> runId [

	^ config runId
]

{ #category : 'running' }
GPHRunner >> runMeasuredStep: aStep [
	"The watchdog starts once the gate is passed (or before the first step when there is no gate)."

	aStep isGate ifFalse: [ self startMeasuredPhase ].
	self
		time: aStep name
		parent: nil
		measured: true
		do: aStep action.
	aStep isGate ifTrue: [ self startMeasuredPhase ]
]

{ #category : 'running' }
GPHRunner >> runMeasuredSteps [

	self steps
		reject: [ :step | step isFinalization ]
		thenDo: [ :step | self runMeasuredStep: step ]
]

{ #category : 'clone directory' }
GPHRunner >> safeClonePath [
	"Answer cloneRoot / <repository name>, after checking that the name is a plain, non-empty directory name and that the path is a direct child of the clone root."

	| name root path |
	name := config repositoryName.
	(name isEmptyOrNil or: [
		 (name includes: $/) or: [ #( '.' '..' ) includes: name ] ])
		ifTrue: [
				GPHUnsafeClonePathError signal:
					'Refusing clone directory name: ' , name printString ].
	root := config cloneRoot.
	root isRoot ifTrue: [
			GPHUnsafeClonePathError signal:
				'Refusing the file system root as clone root' ].
	path := root / name.
	(path parent = root and: [ root path contains: path path ]) ifFalse: [
			GPHUnsafeClonePathError signal:
				'Clone path outside the clone root: ' , path fullName ].
	^ path
]

{ #category : 'accessing' }
GPHRunner >> since [

	^ config since
]

{ #category : 'running' }
GPHRunner >> startMeasuredPhase [

	measuredPhaseStarted ifTrue: [ ^ self ].
	measuredPhaseStarted := true.
	listener runnerDidStartMeasuredPhase: self
]

{ #category : 'accessing' }
GPHRunner >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
GPHRunner >> state [

	^ statusMutex critical: [ state ]
]

{ #category : 'accessing' }
GPHRunner >> stateAtExport [
	"The state recorded in meta.json: the terminal state being finalized (failed, timeout or stopped), running for a successful run, or the current state for an export made outside finalization."

	^ statusMutex critical: [ stateAtExport ifNil: [ state ] ]
]

{ #category : 'status' }
GPHRunner >> statusDictionary [

	^ statusMutex critical: [
			  OrderedDictionary new
				  at: 'runId' put: config runId;
				  at: 'state' put: state;
				  at: 'step' put: stepName;
				  at: 'stepStartedAt' put: (GPHTime iso: stepStartedAt);
				  at: 'startedAt' put: (GPHTime iso: startedAt);
				  at: 'updatedAt' put: (GPHTime iso: clock now);
				  at: 'apiCallsSoFar' put: recorder callCount;
				  at: 'fallbacksSoFar' put: self fallbacks size;
				  at: 'rateLimited' put: recorder isRateLimited;
				  at: 'anomaly' put: recorder hasUnexpectedErrors;
				  at: 'error' put: self errorDictionary;
				  at: 'finalizationErrors' put: finalizationErrors copy;
				  yourself ]
]

{ #category : 'steps' }
GPHRunner >> steps [
	"Injectable with #steps:; defaults to the steps of the configured mode."

	^ steps ifNil: [ steps := self mode stepsFor: self ]
]

{ #category : 'accessing' }
GPHRunner >> steps: anObject [

	steps := anObject
]

{ #category : 'steps' }
GPHRunner >> stepsFor: aModeName [
	"Answer the ordered list of GPHStep (name -> block) of a mode."

	^ (GPHRunMode forMode: aModeName) stepsFor: self
]

{ #category : 'running' }
GPHRunner >> substep: aName do: aBlock [
	"A timed sub-step of the current step, e.g. commits.walk."

	self
		time: aName
		parent: currentTiming name
		measured: currentTiming measured
		do: aBlock
]

{ #category : 'running' }
GPHRunner >> time: aName parent: aParentName measured: aBoolean do: aBlock [
	"Run aBlock as a step: update the recorder current step and status.json, and record a GPHStepTiming."

	| timing enclosing |
	enclosing := currentTiming.
	timing := GPHStepTiming new
		          name: aName;
		          parent: aParentName;
		          measured: aBoolean;
		          startedAt: clock now;
		          yourself.
	timings add: timing.
	currentTiming := timing.
	self enterStep: timing.
	timing startMs: clock milliseconds.
	[ aBlock value ]
		on: Error
		do: [ :anError |
				self close: timing outcome: #failed.
				anError pass ].
	self close: timing outcome: #ok.
	currentTiming := enclosing.
	enclosing ifNotNil: [ :parentTiming | self enterStep: parentTiming ]
]

{ #category : 'accessing' }
GPHRunner >> timings [

	^ timings
]

{ #category : 'accessing' }
GPHRunner >> tokenProvider [

	^ tokenProvider
]

{ #category : 'accessing' }
GPHRunner >> tokenProvider: anObject [

	tokenProvider := anObject
]

{ #category : 'accessing' }
GPHRunner >> until [

	^ config until
]

{ #category : 'accessing' }
GPHRunner >> windowAuthors [

	^ windowAuthors
]

{ #category : 'accessing' }
GPHRunner >> windowCommits [

	^ windowCommits
]

{ #category : 'accessing' }
GPHRunner >> windowShas [

	^ windowShas
]

{ #category : 'status' }
GPHRunner >> writeStatus [
	"Atomic write of status.json (tmp file then rename), redacted from the token."

	| status |
	status := self statusDictionary.
	statusMutex critical: [
			GPHJsonFile
				write: status
				to: self outputDirectory / 'status.json'
				redactor: tokenProvider ]
]
