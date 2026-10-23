"
I am mode D: GithubModelImporter alone (commits, diffs, creators and merge commits through the GitHub API).
"
Class {
	#name : 'GPHDirectMode',
	#superclass : 'GPHRunMode',
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'accessing' }
GPHDirectMode class >> modeName [

	^ #D
]

{ #category : 'exporting' }
GPHDirectMode >> authorLoginOf: aCommit [

	^ aCommit author_name
]

{ #category : 'exporting' }
GPHDirectMode >> authorNameGitOf: aCommit [
	"The git author name is cached by GithubModelImporter>>#configureReaderForCommit: (author_name holds the login)."

	^ aCommit cacheAt: #gitAuthorName ifAbsent: [ nil ]
]

{ #category : 'exporting' }
GPHDirectMode >> authoredDateSemantics [

	^ 'author-time'
]

{ #category : 'building' }
GPHDirectMode >> buildImportersWith: anImporterFactory [

	^ anImporterFactory buildD
]

{ #category : 'exporting' }
GPHDirectMode >> changeTypeOf: aDiff [
	"The GitHub files mapping of the tool keeps no status."

	^ 'unknown'
]

{ #category : 'steps' }
GPHDirectMode >> importAuthorsFor: aRunner [
	"Resolve the GitHub account of each window commit (up to 2 calls per new login), then collect them."

	aRunner windowCommits do: [ :commit |
		aRunner importer importCreatorOfCommit: commit ].
	super importAuthorsFor: aRunner
]

{ #category : 'steps' }
GPHDirectMode >> importCommitsFor: aRunner [
	"Paginated GET commits?since&until, then freeze the window commits."

	aRunner importer
		importCommitsOfProject: aRunner project
		since: aRunner since
		until: aRunner until.
	aRunner freezeWindowCommits
]

{ #category : 'exporting' }
GPHDirectMode >> isFilesTruncated: aCommit amongPaginated: someShas [
	"GitHub answers at most 300 files per page of commits/:sha; a Link rel=next means more files were not fetched."

	^ aCommit diffs size >= 300 or: [ someShas includes: aCommit id ]
]

{ #category : 'steps' }
GPHDirectMode >> resolveOutOfWindowMergeCommit: aSha for: aRunner [

	^ (aRunner importer importCommit: aSha ofProject: aRunner project)
		  ifNil: [ #'not-found' ]
		  ifNotNil: [ #api ]
]
