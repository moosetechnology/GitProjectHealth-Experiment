"
I am a named step of a run (name -> block). kind is #measured, #gate (the rate-limit gate; the watchdog starts after me) or #finalization (annotate and export: always run, even after a failure, and not part of the measures).
"
Class {
	#name : 'GPHStep',
	#superclass : 'Object',
	#instVars : [
		'name',
		'action',
		'kind'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHStep class >> finalization: aName do: aBlock [
	"A step run after the measured steps, even when one of them failed, and excluded from measures."

	^ (self named: aName do: aBlock)
		  kind: #finalization;
		  yourself
]

{ #category : 'instance creation' }
GPHStep class >> gate: aName do: aBlock [
	"The rate-limit gate: measured, and the global timeout watchdog starts after it."

	^ (self named: aName do: aBlock)
		  kind: #gate;
		  yourself
]

{ #category : 'instance creation' }
GPHStep class >> named: aName do: aBlock [
	"A measured step."

	^ self new
		  name: aName;
		  action: aBlock;
		  kind: #measured;
		  yourself
]

{ #category : 'accessing' }
GPHStep >> action [

	^ action
]

{ #category : 'accessing' }
GPHStep >> action: anObject [

	action := anObject
]

{ #category : 'testing' }
GPHStep >> isFinalization [

	^ kind = #finalization
]

{ #category : 'testing' }
GPHStep >> isGate [

	^ kind = #gate
]

{ #category : 'accessing' }
GPHStep >> kind [

	^ kind
]

{ #category : 'accessing' }
GPHStep >> kind: anObject [

	kind := anObject
]

{ #category : 'accessing' }
GPHStep >> name [

	^ name
]

{ #category : 'accessing' }
GPHStep >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GPHStep >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: name;
		space;
		print: kind;
		nextPut: $)
]
