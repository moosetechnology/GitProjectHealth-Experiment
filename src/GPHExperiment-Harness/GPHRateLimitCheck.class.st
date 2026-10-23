"
I am the result of the pre-run rate-limit check: core limit, remaining, reset (epoch seconds) and how long the gate waited.
"
Class {
	#name : 'GPHRateLimitCheck',
	#superclass : 'Object',
	#instVars : [
		'checkedAt',
		'remaining',
		'limit',
		'reset',
		'waitedSeconds'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'converting' }
GPHRateLimitCheck >> asDictionary [

	^ OrderedDictionary new
		  at: 'checkedAt' put: (GPHTime iso: checkedAt);
		  at: 'remaining' put: remaining;
		  at: 'limit' put: limit;
		  at: 'reset' put: reset;
		  at: 'waitedSeconds' put: waitedSeconds;
		  yourself
]

{ #category : 'accessing' }
GPHRateLimitCheck >> checkedAt [

	^ checkedAt
]

{ #category : 'accessing' }
GPHRateLimitCheck >> checkedAt: anObject [

	checkedAt := anObject
]

{ #category : 'initialization' }
GPHRateLimitCheck >> initialize [

	super initialize.
	waitedSeconds := 0
]

{ #category : 'testing' }
GPHRateLimitCheck >> isBelow: aThreshold [

	^ remaining < aThreshold
]

{ #category : 'accessing' }
GPHRateLimitCheck >> limit [

	^ limit
]

{ #category : 'accessing' }
GPHRateLimitCheck >> limit: anObject [

	limit := anObject
]

{ #category : 'accessing' }
GPHRateLimitCheck >> remaining [

	^ remaining
]

{ #category : 'accessing' }
GPHRateLimitCheck >> remaining: anObject [

	remaining := anObject
]

{ #category : 'accessing' }
GPHRateLimitCheck >> reset [

	^ reset
]

{ #category : 'accessing' }
GPHRateLimitCheck >> reset: anObject [

	reset := anObject
]

{ #category : 'accessing' }
GPHRateLimitCheck >> waitedMilliseconds [

	^ (waitedSeconds * 1000) rounded
]

{ #category : 'accessing' }
GPHRateLimitCheck >> waitedSeconds [

	^ waitedSeconds
]

{ #category : 'accessing' }
GPHRateLimitCheck >> waitedSeconds: anObject [

	waitedSeconds := anObject
]
