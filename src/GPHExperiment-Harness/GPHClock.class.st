"
I am the time source of the harness: current UTC time, a millisecond clock for durations, and sleeping. Tests inject a fake clock answering the same protocol (#now, #milliseconds, #sleepSeconds:).
"
Class {
	#name : 'GPHClock',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Support',
	#package : 'GPHExperiment-Harness',
	#tag : 'Support'
}

{ #category : 'accessing' }
GPHClock >> milliseconds [
	"Answer a monotonic millisecond counter used to measure durations."

	^ Time millisecondClockValue
]

{ #category : 'accessing' }
GPHClock >> now [
	"Answer the current time in UTC."

	^ DateAndTime now asUTC
]

{ #category : 'waiting' }
GPHClock >> sleepSeconds: aNumber [
	"Block the active process for aNumber seconds (fractions allowed)."

	aNumber > 0 ifTrue: [
		(Delay forMilliseconds: (aNumber * 1000) rounded) wait ]
]
