"
I record that the local importer did not find an object (LGit_GIT_ENOTFOUND), which makes GitModelMixedImporter fall back on the API.
"
Class {
	#name : 'GPHFallback',
	#superclass : 'Object',
	#instVars : [
		'operation',
		'sha',
		'errorClass',
		'occurredAt'
	],
	#category : 'GPHExperiment-Harness-Importing',
	#package : 'GPHExperiment-Harness',
	#tag : 'Importing'
}

{ #category : 'converting' }
GPHFallback >> asDictionary [

	^ OrderedDictionary new
		  at: 'operation' put: operation;
		  at: 'sha' put: sha;
		  at: 'errorClass' put: errorClass;
		  at: 'occurredAt' put: (GPHTime isoMillis: occurredAt);
		  yourself
]

{ #category : 'accessing' }
GPHFallback >> errorClass [

	^ errorClass
]

{ #category : 'accessing' }
GPHFallback >> errorClass: anObject [

	errorClass := anObject
]

{ #category : 'accessing' }
GPHFallback >> occurredAt [

	^ occurredAt
]

{ #category : 'accessing' }
GPHFallback >> occurredAt: anObject [

	occurredAt := anObject
]

{ #category : 'accessing' }
GPHFallback >> operation [

	^ operation
]

{ #category : 'accessing' }
GPHFallback >> operation: anObject [

	operation := anObject
]

{ #category : 'accessing' }
GPHFallback >> sha [

	^ sha
]

{ #category : 'accessing' }
GPHFallback >> sha: anObject [

	sha := anObject
]
