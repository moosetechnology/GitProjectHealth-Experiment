"
A run configuration whose repository name is given verbatim, so that tests can feed GPHRunner>>#safeClonePath names that cannot be derived from an owner/name string ('' or 'a/b').
"
Class {
	#name : 'GPHRawNameRunConfig',
	#superclass : 'GPHRunConfig',
	#instVars : [
		'rawRepositoryName'
	],
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
GPHRawNameRunConfig >> rawRepositoryName: aString [

	rawRepositoryName := aString
]

{ #category : 'accessing' }
GPHRawNameRunConfig >> repositoryName [
	"Answer the name verbatim, bypassing the owner/name split."

	^ rawRepositoryName
]
