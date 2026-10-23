"
A test double for the API importer of a GitModelMixedImporter. It records the commits whose diffs are requested instead of calling GitHub.
"
Class {
	#name : 'GPHFakeApiImporter',
	#superclass : 'Object',
	#instVars : [
		'factoryImporter',
		'glhModel',
		'diffRequests',
		'withCommitDiffs',
		'withCommitsSince'
	],
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
GPHFakeApiImporter >> diffRequests [
	"Answer the commits whose diffs were asked to the API."

	^ diffRequests ifNil: [ diffRequests := OrderedCollection new ]
]

{ #category : 'accessing' }
GPHFakeApiImporter >> factoryImporter [

	^ factoryImporter
]

{ #category : 'accessing' }
GPHFakeApiImporter >> factoryImporter: anImporter [

	factoryImporter := anImporter
]

{ #category : 'accessing' }
GPHFakeApiImporter >> glhModel: aModel [

	glhModel := aModel
]

{ #category : 'importing' }
GPHFakeApiImporter >> importDiffOfCommit: aCommit [
	"Record the fallback request instead of calling GitHub."

	self diffRequests add: aCommit.
	^ #(  )
]

{ #category : 'accessing' }
GPHFakeApiImporter >> withCommitDiffs: aBoolean [

	withCommitDiffs := aBoolean
]

{ #category : 'accessing' }
GPHFakeApiImporter >> withCommitsSince: aDateAndTime [

	withCommitsSince := aDateAndTime
]
