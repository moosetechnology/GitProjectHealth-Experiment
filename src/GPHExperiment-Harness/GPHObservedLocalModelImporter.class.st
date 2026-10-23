"
I am a GitLocalModelImporter that records every LGit_GIT_ENOTFOUND raised by #importDiffOfCommit: and #importCommit:ofProject: before passing it on, so the API fallbacks of GitModelMixedImporter become observable.
"
Class {
	#name : 'GPHObservedLocalModelImporter',
	#superclass : 'GitLocalModelImporter',
	#instVars : [
		'fallbacks'
	],
	#category : 'GPHExperiment-Harness-Importing',
	#package : 'GPHExperiment-Harness',
	#tag : 'Importing'
}

{ #category : 'accessing' }
GPHObservedLocalModelImporter >> fallbackCount [

	^ fallbacks size
]

{ #category : 'accessing' }
GPHObservedLocalModelImporter >> fallbacks [

	^ fallbacks
]

{ #category : 'commit' }
GPHObservedLocalModelImporter >> importCommit: aCommitID ofProject: aGLHProject [
	"Record the local miss, then let GitModelMixedImporter fall back on the API."

	^ [ super importCommit: aCommitID ofProject: aGLHProject ]
		  on: LGit_GIT_ENOTFOUND
		  do: [ :error |
				  self
					  recordFallback: #importCommit:ofProject:
					  sha: aCommitID
					  error: error.
				  error pass ]
]

{ #category : 'commit' }
GPHObservedLocalModelImporter >> importDiffOfCommit: aCommit [
	"Record the local miss, then let GitModelMixedImporter fall back on the API."

	^ [ super importDiffOfCommit: aCommit ]
		  on: LGit_GIT_ENOTFOUND
		  do: [ :error |
				  self
					  recordFallback: #importDiffOfCommit:
					  sha: aCommit id
					  error: error.
				  error pass ]
]

{ #category : 'initialization' }
GPHObservedLocalModelImporter >> initialize [

	super initialize.
	fallbacks := OrderedCollection new
]

{ #category : 'private' }
GPHObservedLocalModelImporter >> recordFallback: anOperation sha: aSha error: anError [

	fallbacks add: (GPHFallback new
			 operation: anOperation;
			 sha: aSha;
			 errorClass: anError class name;
			 occurredAt: DateAndTime now asUTC;
			 yourself)
]
