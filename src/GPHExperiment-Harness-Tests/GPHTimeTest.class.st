"
ISO 8601 UTC formatting and parsing used by every exported date.
"
Class {
	#name : 'GPHTimeTest',
	#superclass : 'TestCase',
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'tests' }
GPHTimeTest >> testIsoIsUtcWithoutFraction [
	"12:34:56.789 at +02:00 is 10:34:56 UTC; the fraction is dropped."

	| local |
	local := DateAndTime
		         year: 2025
		         month: 10
		         day: 1
		         hour: 12
		         minute: 34
		         second: 56
		         nanoSecond: 789000000
		         offset: 2 hours.
	self assert: (GPHTime iso: local) equals: '2025-10-01T10:34:56Z'.
	self assert: (GPHTime iso: nil) isNil
]

{ #category : 'tests' }
GPHTimeTest >> testIsoMillisKeepsMilliseconds [

	| local |
	local := DateAndTime
		         year: 2025
		         month: 10
		         day: 1
		         hour: 0
		         minute: 0
		         second: 5
		         nanoSecond: 7000000
		         offset: Duration zero.
	self
		assert: (GPHTime isoMillis: local)
		equals: '2025-10-01T00:00:05.007Z'
]

{ #category : 'tests' }
GPHTimeTest >> testIsoParseRoundTrip [

	| local parsed |
	local := DateAndTime
		         year: 2025
		         month: 12
		         day: 31
		         hour: 23
		         minute: 30
		         second: 0
		         offset: 2 hours.
	parsed := GPHTime parse: (GPHTime iso: local).
	self assert: parsed equals: local.
	self assert: parsed offset equals: Duration zero.
	self assert: (GPHTime iso: parsed) equals: '2025-12-31T21:30:00Z'.
	self assert: (GPHTime parse: nil) isNil
]
