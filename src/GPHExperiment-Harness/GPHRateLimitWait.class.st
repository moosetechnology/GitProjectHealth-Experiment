"
I record a wait performed after a rate-limited answer (403/429 with X-RateLimit-Remaining: 0 or Retry-After). The wait is excluded from step net durations.
"
Class {
	#name : 'GPHRateLimitWait',
	#superclass : 'Object',
	#instVars : [
		'step',
		'logicalId',
		'endpoint',
		'status',
		'startedAt',
		'waitedMs',
		'plannedSeconds'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'converting' }
GPHRateLimitWait >> asDictionary [

	^ OrderedDictionary new
		  at: 'step' put: step;
		  at: 'logicalId' put: logicalId;
		  at: 'endpoint' put: endpoint;
		  at: 'status' put: status;
		  at: 'startedAt' put: (GPHTime isoMillis: startedAt);
		  at: 'plannedSeconds' put: plannedSeconds;
		  at: 'waitedMs' put: waitedMs;
		  yourself
]

{ #category : 'testing' }
GPHRateLimitWait >> belongsToStep: aStepName [
	"A wait belongs to its step and to the parent of its sub-step (commits.walk belongs to commits)."

	^ step = aStepName or: [ step beginsWith: aStepName , '.' ]
]

{ #category : 'accessing' }
GPHRateLimitWait >> endpoint [

	^ endpoint
]

{ #category : 'accessing' }
GPHRateLimitWait >> endpoint: anObject [

	endpoint := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> logicalId [

	^ logicalId
]

{ #category : 'accessing' }
GPHRateLimitWait >> logicalId: anObject [

	logicalId := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> plannedSeconds [

	^ plannedSeconds
]

{ #category : 'accessing' }
GPHRateLimitWait >> plannedSeconds: anObject [

	plannedSeconds := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
GPHRateLimitWait >> startedAt: anObject [

	startedAt := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> status [

	^ status
]

{ #category : 'accessing' }
GPHRateLimitWait >> status: anObject [

	status := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> step [

	^ step
]

{ #category : 'accessing' }
GPHRateLimitWait >> step: anObject [

	step := anObject
]

{ #category : 'accessing' }
GPHRateLimitWait >> waitedMs [

	^ waitedMs
]

{ #category : 'accessing' }
GPHRateLimitWait >> waitedMs: anObject [

	waitedMs := anObject
]
