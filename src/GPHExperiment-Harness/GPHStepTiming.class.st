"
I record the timing of a step or sub-step: gross duration, rate-limit wait time, and net duration (gross minus waits).
"
Class {
	#name : 'GPHStepTiming',
	#superclass : 'Object',
	#instVars : [
		'name',
		'parent',
		'startedAt',
		'endedAt',
		'startMs',
		'durationMs',
		'rateLimitWaitMs',
		'outcome',
		'measured'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'recording' }
GPHStepTiming >> addRateLimitWaitMs: milliseconds [
	"Exclude a wait known by the runner itself (the rate-limit gate)."

	rateLimitWaitMs := rateLimitWaitMs + milliseconds
]

{ #category : 'converting' }
GPHStepTiming >> asDictionary [

	^ OrderedDictionary new
		  at: 'name' put: name;
		  at: 'parent' put: parent;
		  at: 'measured' put: measured;
		  at: 'outcome' put: outcome;
		  at: 'startedAt' put: (GPHTime isoMillis: startedAt);
		  at: 'endedAt' put: (GPHTime isoMillis: endedAt);
		  at: 'durationMs' put: durationMs;
		  at: 'rateLimitWaitMs' put: rateLimitWaitMs;
		  at: 'netDurationMs' put: self netDurationMs;
		  yourself
]

{ #category : 'accessing' }
GPHStepTiming >> durationMs [

	^ durationMs
]

{ #category : 'accessing' }
GPHStepTiming >> durationMs: anObject [

	durationMs := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> endedAt [

	^ endedAt
]

{ #category : 'accessing' }
GPHStepTiming >> endedAt: anObject [

	endedAt := anObject
]

{ #category : 'recording' }
GPHStepTiming >> finishAt: aDateAndTime milliseconds: nowMs outcome: anOutcome recordedWaitMs: waitMs [
	"Close the timing. waitMs are the rate-limit waits recorded by the client for this step and its sub-steps."

	endedAt := aDateAndTime.
	durationMs := nowMs - startMs.
	rateLimitWaitMs := rateLimitWaitMs + waitMs.
	outcome := anOutcome
]

{ #category : 'initialization' }
GPHStepTiming >> initialize [

	super initialize.
	rateLimitWaitMs := 0.
	measured := true.
	outcome := #running
]

{ #category : 'testing' }
GPHStepTiming >> isOpen [

	^ endedAt isNil
]

{ #category : 'testing' }
GPHStepTiming >> isTopLevelMeasure [

	^ measured and: [ parent isNil and: [ durationMs notNil ] ]
]

{ #category : 'accessing' }
GPHStepTiming >> measured [

	^ measured
]

{ #category : 'accessing' }
GPHStepTiming >> measured: anObject [

	measured := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> name [

	^ name
]

{ #category : 'accessing' }
GPHStepTiming >> name: anObject [

	name := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> netDurationMs [
	"Gross duration minus the rate-limit waits."

	^ durationMs ifNotNil: [ :gross | gross - rateLimitWaitMs max: 0 ]
]

{ #category : 'accessing' }
GPHStepTiming >> outcome [

	^ outcome
]

{ #category : 'accessing' }
GPHStepTiming >> outcome: anObject [

	outcome := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> parent [

	^ parent
]

{ #category : 'accessing' }
GPHStepTiming >> parent: anObject [

	parent := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> rateLimitWaitMs [

	^ rateLimitWaitMs
]

{ #category : 'accessing' }
GPHStepTiming >> rateLimitWaitMs: anObject [

	rateLimitWaitMs := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> startMs [

	^ startMs
]

{ #category : 'accessing' }
GPHStepTiming >> startMs: anObject [

	startMs := anObject
]

{ #category : 'accessing' }
GPHStepTiming >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
GPHStepTiming >> startedAt: anObject [

	startedAt := anObject
]
