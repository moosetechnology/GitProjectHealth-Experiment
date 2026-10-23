"
I record a logical request that ended with an unexpected outcome: a status >= 400 (except tolerated 404 on commits/:sha and users/:login, and handled rate limits) or a network failure after retries. Any of me marks the run as an anomaly.
"
Class {
	#name : 'GPHUnexpectedResponse',
	#superclass : 'Object',
	#instVars : [
		'step',
		'logicalId',
		'endpoint',
		'path',
		'status',
		'errorClass',
		'errorMessage',
		'occurredAt'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'converting' }
GPHUnexpectedResponse >> asDictionary [

	^ OrderedDictionary new
		  at: 'step' put: step;
		  at: 'logicalId' put: logicalId;
		  at: 'endpoint' put: endpoint;
		  at: 'path' put: path;
		  at: 'status' put: status;
		  at: 'errorClass' put: errorClass;
		  at: 'errorMessage' put: errorMessage;
		  at: 'occurredAt' put: (GPHTime isoMillis: occurredAt);
		  yourself
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> endpoint [

	^ endpoint
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> endpoint: anObject [

	endpoint := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> errorClass [

	^ errorClass
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> errorClass: anObject [

	errorClass := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> errorMessage [

	^ errorMessage
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> errorMessage: anObject [

	errorMessage := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> logicalId [

	^ logicalId
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> logicalId: anObject [

	logicalId := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> occurredAt [

	^ occurredAt
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> occurredAt: anObject [

	occurredAt := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> path [

	^ path
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> path: anObject [

	path := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> status [

	^ status
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> status: anObject [

	status := anObject
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> step [

	^ step
]

{ #category : 'accessing' }
GPHUnexpectedResponse >> step: anObject [

	step := anObject
]
