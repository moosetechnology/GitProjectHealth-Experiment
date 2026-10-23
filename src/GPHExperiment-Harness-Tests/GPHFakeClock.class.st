"
A deterministic clock for the harness tests. It answers #now, #milliseconds and #sleepSeconds: like GPHClock, but sleeping never blocks: it records the requested duration and advances both the wall clock and the millisecond counter.
"
Class {
	#name : 'GPHFakeClock',
	#superclass : 'Object',
	#instVars : [
		'currentTime',
		'milliseconds',
		'sleeps'
	],
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'time travel' }
GPHFakeClock >> advanceSeconds: aNumber [

	currentTime := currentTime
	               + (Duration milliSeconds: (aNumber * 1000) rounded).
	milliseconds := milliseconds + (aNumber * 1000) rounded
]

{ #category : 'initialization' }
GPHFakeClock >> initialize [

	super initialize.
	currentTime := DateAndTime
		               year: 2026
		               month: 10
		               day: 1
		               hour: 12
		               minute: 0
		               second: 0
		               offset: Duration zero.
	milliseconds := 1000000.
	sleeps := OrderedCollection new
]

{ #category : 'accessing' }
GPHFakeClock >> milliseconds [

	^ milliseconds
]

{ #category : 'accessing' }
GPHFakeClock >> now [

	^ currentTime
]

{ #category : 'sleeping' }
GPHFakeClock >> sleepSeconds: aNumber [
	"Never block: record the sleep and let the time pass instantly."

	sleeps add: aNumber.
	self advanceSeconds: aNumber
]

{ #category : 'accessing' }
GPHFakeClock >> sleeps [
	"Answer the durations, in seconds, of every requested sleep."

	^ sleeps
]

{ #category : 'accessing' }
GPHFakeClock >> totalSleptSeconds [

	^ sleeps inject: 0 into: [ :sum :each | sum + each ]
]

{ #category : 'accessing' }
GPHFakeClock >> unixNow [
	"Answer the current time in epoch seconds, as in X-RateLimit-Reset."

	^ currentTime asUnixTime
]
