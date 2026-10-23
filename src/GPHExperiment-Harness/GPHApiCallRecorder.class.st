"
I collect the API calls, rate-limit waits and unexpected errors of one run, attribute them to the current step, and compute aggregates. All my state is protected by a Mutex because the status of a run is read from another process.
"
Class {
	#name : 'GPHApiCallRecorder',
	#superclass : 'Object',
	#instVars : [
		'mutex',
		'calls',
		'logicalSeq',
		'callSeq',
		'currentStep',
		'rateLimitWaits',
		'unexpectedErrors'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'aggregating' }
GPHApiCallRecorder >> aggregate: someCalls groupedBy: aKeyBlock [
	"Answer an OrderedDictionary key -> aggregate dictionary, sorted by key."

	| groups result |
	groups := Dictionary new.
	someCalls do: [ :call |
			(groups
				 at: (aKeyBlock value: call) asString
				 ifAbsentPut: [ GPHCallAggregate new ]) add: call ].
	result := OrderedDictionary new.
	groups keys sorted do: [ :key |
		result at: key put: (groups at: key) asDictionary ].
	^ result
]

{ #category : 'aggregating' }
GPHApiCallRecorder >> aggregates [
	"Answer totals and breakdowns by endpoint and by step, plus rate-limit and unexpected error counts."

	| snapshot totals waits |
	snapshot := self calls.
	waits := self rateLimitWaits.
	totals := GPHCallAggregate new.
	snapshot do: [ :call | totals add: call ].
	^ OrderedDictionary new
		  at: 'totals' put: totals asDictionary;
		  at: 'byEndpoint'
		  put:
			  (self aggregate: snapshot groupedBy: [ :call | call endpoint ]);
		  at: 'byStep'
		  put: (self aggregate: snapshot groupedBy: [ :call | call step ]);
		  at: 'rateLimitWaits' put: waits size;
		  at: 'rateLimitWaitMs'
		  put: (waits inject: 0 into: [ :sum :wait | sum + wait waitedMs ]);
		  at: 'unexpectedErrors' put: self unexpectedErrors size;
		  yourself
]

{ #category : 'accessing' }
GPHApiCallRecorder >> callCount [

	^ mutex critical: [ calls size ]
]

{ #category : 'accessing' }
GPHApiCallRecorder >> calls [
	"Answer a snapshot of the recorded calls."

	^ mutex critical: [ calls copy ]
]

{ #category : 'accessing' }
GPHApiCallRecorder >> currentStep [

	^ mutex critical: [ currentStep ]
]

{ #category : 'accessing' }
GPHApiCallRecorder >> currentStep: aStepName [

	mutex critical: [ currentStep := aStepName ]
]

{ #category : 'testing' }
GPHApiCallRecorder >> hasUnexpectedErrors [

	^ mutex critical: [ unexpectedErrors notEmpty ]
]

{ #category : 'initialization' }
GPHApiCallRecorder >> initialize [

	super initialize.
	mutex := Mutex new.
	calls := OrderedCollection new.
	rateLimitWaits := OrderedCollection new.
	unexpectedErrors := OrderedCollection new.
	logicalSeq := 0.
	callSeq := 0.
	currentStep := 'none'
]

{ #category : 'testing' }
GPHApiCallRecorder >> isRateLimited [

	^ mutex critical: [ rateLimitWaits notEmpty ]
]

{ #category : 'accessing' }
GPHApiCallRecorder >> logicalSeq [

	^ mutex critical: [ logicalSeq ]
]

{ #category : 'sequencing' }
GPHApiCallRecorder >> nextLogicalId [

	^ mutex critical: [ logicalSeq := logicalSeq + 1 ]
]

{ #category : 'sequencing' }
GPHApiCallRecorder >> nextSeq [

	^ mutex critical: [ callSeq := callSeq + 1 ]
]

{ #category : 'querying' }
GPHApiCallRecorder >> rateLimitWaitMsForStep: aStepName [
	"Answer the milliseconds spent waiting for rate limits in aStepName and its sub-steps."

	^ self rateLimitWaits inject: 0 into: [ :sum :wait |
			  (wait belongsToStep: aStepName)
				  ifTrue: [ sum + wait waitedMs ]
				  ifFalse: [ sum ] ]
]

{ #category : 'accessing' }
GPHApiCallRecorder >> rateLimitWaits [
	"Answer a snapshot of the recorded rate-limit waits."

	^ mutex critical: [ rateLimitWaits copy ]
]

{ #category : 'recording' }
GPHApiCallRecorder >> recordCall: anApiCall [

	mutex critical: [ calls add: anApiCall ]
]

{ #category : 'recording' }
GPHApiCallRecorder >> recordRateLimitWait: aRateLimitWait [

	mutex critical: [ rateLimitWaits add: aRateLimitWait ]
]

{ #category : 'recording' }
GPHApiCallRecorder >> recordUnexpectedError: anUnexpectedResponse [

	mutex critical: [ unexpectedErrors add: anUnexpectedResponse ]
]

{ #category : 'querying' }
GPHApiCallRecorder >> shasWithTruncatedFiles [
	"Answer the shas whose commits/:sha answer announced a next page of files."

	^ (self calls select: [ :call |
		   call linkNext and: [ call endpoint = 'commits/:sha' ] ])
		  collect: [ :call | (call path substrings: '/') last ]
		  as: Set
]

{ #category : 'accessing' }
GPHApiCallRecorder >> unexpectedErrors [
	"Answer a snapshot of the recorded unexpected errors."

	^ mutex critical: [ unexpectedErrors copy ]
]
