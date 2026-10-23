"
I am mode H: GitModelMixedImporter with a GithubModelImporter and a GPHObservedLocalModelImporter (clone, local branches and commit walk, local diffs with API fallback).
"
Class {
	#name : 'GPHHybridMode',
	#superclass : 'GPHRunMode',
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'accessing' }
GPHHybridMode class >> modeName [

	^ #H
]

{ #category : 'steps' }
GPHHybridMode >> annotateFor: aRunner [

	aRunner annotateBranches
]

{ #category : 'exporting' }
GPHHybridMode >> authorLoginOf: aCommit [
	"The local importer knows no GitHub login."

	^ nil
]

{ #category : 'exporting' }
GPHHybridMode >> authorNameGitOf: aCommit [

	^ aCommit author_name
]

{ #category : 'exporting' }
GPHHybridMode >> authoredDateSemantics [
	"GitLocalModelImporter>>#importCommit: sets authored_date to the commit time."

	^ 'commit-time'
]

{ #category : 'exporting' }
GPHHybridMode >> branchesOf: aCommit in: aRunner [

	^ aRunner branchesOfSha: aCommit id
]

{ #category : 'building' }
GPHHybridMode >> buildImportersWith: anImporterFactory [

	^ anImporterFactory buildH
]

{ #category : 'exporting' }
GPHHybridMode >> changeTypeOf: aDiff [
	"The flags are true or nil (never set to false by the local importer)."

	aDiff new_file == true ifTrue: [ ^ 'added' ].
	aDiff deleted_file == true ifTrue: [ ^ 'deleted' ].
	aDiff renamed_file == true ifTrue: [ ^ 'renamed' ].
	^ 'modified'
]

{ #category : 'accessing' }
GPHHybridMode >> cloneLabelFor: aConfig [

	^ aConfig clone asString
]

{ #category : 'exporting' }
GPHHybridMode >> cloneMetadataFor: aRunner [

	^ aRunner cloneHeadMetadata
]

{ #category : 'steps' }
GPHHybridMode >> cloneStepsFor: aRunner [

	^ { (GPHStep named: 'clone' do: [ aRunner cloneRepository ]) }
]

{ #category : 'exporting' }
GPHHybridMode >> headResolvableOf: aPullRequest in: aRunner [

	^ aRunner isHeadResolvableLocally: aPullRequest
]

{ #category : 'steps' }
GPHHybridMode >> importCommitsFor: aRunner [
	"Local branches must exist before the walk (it detects each GLHBranch with ifNone: nil)."

	aRunner substep: 'commits.branches' do: [
			aRunner importers local importBranchesOfRepository:
				aRunner project repository ].
	aRunner substep: 'commits.walk' do: [
			aRunner importer
				importCommitsOfProject: aRunner project
				since: aRunner since
				until: aRunner until ].
	aRunner freezeWindowCommits
]

{ #category : 'preparing' }
GPHHybridMode >> prepareCloneFor: aRunner [
	"Cold: delete the clone directory. Warm: it must exist (warm-miss otherwise)."

	aRunner config isColdClone
		ifTrue: [ aRunner deleteClone ]
		ifFalse: [ aRunner ensureCloneExists ]
]

{ #category : 'steps' }
GPHHybridMode >> resolveOutOfWindowMergeCommit: aSha for: aRunner [
	"Local first; a new fallback recorded by the observed local importer means the API answered."

	| fallbacksBefore commit |
	fallbacksBefore := aRunner importers local fallbackCount.
	commit := aRunner importer
		          importCommit: aSha
		          ofProject: aRunner project.
	commit ifNil: [ ^ #'not-found' ].
	^ aRunner importers local fallbackCount > fallbacksBefore
		  ifTrue: [ #'api-fallback' ]
		  ifFalse: [ #local ]
]
