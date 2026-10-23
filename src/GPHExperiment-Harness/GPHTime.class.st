"
I convert DateAndTime instances to and from ISO 8601 UTC strings ending with Z.

	GPHTime iso: DateAndTime now.	 """"'2026-10-22T08:15:00Z'""""
	GPHTime parse: '2025-10-01T00:00:00Z'.
"
Class {
	#name : 'GPHTime',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Support',
	#package : 'GPHExperiment-Harness',
	#tag : 'Support'
}

{ #category : 'converting' }
GPHTime class >> compactStamp: aDateAndTime [
	"Answer a file-name friendly UTC stamp such as 20261022T081500123Z."

	^ (self isoMillis: aDateAndTime) reject: [ :each |
		  '-:.' includes: each ]
]

{ #category : 'converting' }
GPHTime class >> iso: aDateAndTime [
	"Answer an ISO 8601 UTC string such as 2025-10-01T00:00:00Z (no fraction), or nil for nil."

	| utc |
	aDateAndTime ifNil: [ ^ nil ].
	utc := aDateAndTime asUTC.
	^ String streamContents: [ :stream |
			  utc printYMDOn: stream.
			  stream nextPut: $T.
			  utc printHMSOn: stream.
			  stream nextPut: $Z ]
]

{ #category : 'converting' }
GPHTime class >> isoMillis: aDateAndTime [
	"Answer an ISO 8601 UTC string with milliseconds such as 2025-10-01T00:00:00.123Z, or nil for nil."

	| utc |
	aDateAndTime ifNil: [ ^ nil ].
	utc := aDateAndTime asUTC.
	^ String streamContents: [ :stream |
			  utc printYMDOn: stream.
			  stream nextPut: $T.
			  utc printHMSOn: stream.
			  stream
				  nextPut: $.;
				  nextPutAll:
					  (utc nanoSecond // 1000000 printPaddedWith: $0 to: 3);
				  nextPut: $Z ]
]

{ #category : 'converting' }
GPHTime class >> parse: aString [
	"Answer the UTC DateAndTime denoted by an ISO 8601 string, or nil for nil."

	aString ifNil: [ ^ nil ].
	^ (DateAndTime fromString: aString) asUTC
]
