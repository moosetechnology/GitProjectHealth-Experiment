"
I am the strategy of an import mode. I define the ordered steps of a run and every behavior that differs between mode D (GithubModelImporter alone) and mode H (GitModelMixedImporter).
"
Class {
	#name : 'GPHRunMode',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHRunMode class >> forMode: aModeName [
	"Answer the strategy of mode #D or #H."

	^ (self allSubclasses
		   detect: [ :each | each modeName = aModeName asSymbol ]
		   ifNone: [
			   GPHConfigurationError signal:
				   'Unknown mode: ' , aModeName printString ]) new
]

{ #category : 'accessing' }
GPHRunMode class >> modeName [

	^ self subclassResponsibility
]

{ #category : 'steps' }
GPHRunMode >> annotateFor: aRunner [
	"Nothing to annotate by default."

	
]

{ #category : 'exporting' }
GPHRunMode >> authorLoginOf: aCommit [

	^ self subclassResponsibility
]

{ #category : 'exporting' }
GPHRunMode >> authorNameGitOf: aCommit [

	^ self subclassResponsibility
]

{ #category : 'exporting' }
GPHRunMode >> authoredDateSemantics [

	^ self subclassResponsibility
]

{ #category : 'exporting' }
GPHRunMode >> branchesOf: aCommit in: aRunner [
	"Branch membership is unknown by default."

	^ nil
]

{ #category : 'building' }
GPHRunMode >> buildImportersWith: anImporterFactory [

	^ self subclassResponsibility
]

{ #category : 'exporting' }
GPHRunMode >> changeTypeOf: aDiff [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
GPHRunMode >> cloneLabelFor: aConfig [
	"The clone kind is ignored by default."

	^ 'api'
]

{ #category : 'exporting' }
GPHRunMode >> cloneMetadataFor: aRunner [
	"No clone by default."

	^ nil
]

{ #category : 'steps' }
GPHRunMode >> cloneStepsFor: aRunner [

	^ #(  )
]

{ #category : 'exporting' }
GPHRunMode >> headResolvableOf: aPullRequest in: aRunner [
	"Local resolvability is unknown by default."

	^ nil
]

{ #category : 'steps' }
GPHRunMode >> importAuthorsFor: aRunner [
	"By default the authors were already resolved during the commit import: only collect them."

	aRunner collectWindowAuthors
]

{ #category : 'steps' }
GPHRunMode >> importCommitsFor: aRunner [

	^ self subclassResponsibility
]

{ #category : 'steps' }
GPHRunMode >> importDiffsFor: aRunner [
	"Diff strategy B: only the window commits get their diffs, in a separate step. In D the importer is the GithubModelImporter, in H the GitModelMixedImporter (local, then API fallback)."

	aRunner windowCommits do: [ :commit |
		aRunner importer importDiffOfCommit: commit ]
]

{ #category : 'exporting' }
GPHRunMode >> isFilesTruncated: aCommit amongPaginated: someShas [
	"Files are never truncated by default."

	^ false
]

{ #category : 'accessing' }
GPHRunMode >> modeName [

	^ self class modeName
]

{ #category : 'preparing' }
GPHRunMode >> prepareCloneFor: aRunner [
	"Nothing to prepare by default."

	
]

{ #category : 'steps' }
GPHRunMode >> resolveOutOfWindowMergeCommit: aSha for: aRunner [
	"Import a merge commit absent from the window and answer its resolution category."

	^ self subclassResponsibility
]

{ #category : 'steps' }
GPHRunMode >> stepsFor: aRunner [
	"Answer the ordered steps of a run: rateLimitGate, build, project, [clone], commits, diffs, authors, prs, then the finalization steps annotate and export."

	^ OrderedCollection new
		  add:
			  (GPHStep gate: 'rateLimitGate' do: [ aRunner passRateLimitGate ]);
		  add: (GPHStep named: 'build' do: [ aRunner buildImporters ]);
		  add: (GPHStep named: 'project' do: [ aRunner importProject ]);
		  addAll: (self cloneStepsFor: aRunner);
		  add:
			  (GPHStep named: 'commits' do: [ self importCommitsFor: aRunner ]);
		  add: (GPHStep named: 'diffs' do: [ self importDiffsFor: aRunner ]);
		  add:
			  (GPHStep named: 'authors' do: [ self importAuthorsFor: aRunner ]);
		  add: (GPHStep named: 'prs' do: [ aRunner importPullRequests ]);
		  add:
			  (GPHStep
				   finalization: 'annotate'
				   do: [ self annotateFor: aRunner ]);
		  add: (GPHStep finalization: 'export' do: [ aRunner export ]);
		  yourself
]
