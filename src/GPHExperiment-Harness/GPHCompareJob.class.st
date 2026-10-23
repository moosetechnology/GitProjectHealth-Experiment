"
I run a GPHRunComparator in a background process and expose its status.
"
Class {
	#name : 'GPHCompareJob',
	#superclass : 'Object',
	#instVars : [
		'id',
		'directoryD',
		'directoryH',
		'outputDirectory',
		'comparator',
		'state',
		'errorMessage',
		'process'
	],
	#category : 'GPHExperiment-Harness-Compare',
	#package : 'GPHExperiment-Harness',
	#tag : 'Compare'
}

{ #category : 'accessing' }
GPHCompareJob >> comparator [

	^ comparator
]

{ #category : 'accessing' }
GPHCompareJob >> comparator: anObject [

	comparator := anObject
]

{ #category : 'accessing' }
GPHCompareJob >> directoryD [

	^ directoryD
]

{ #category : 'accessing' }
GPHCompareJob >> directoryD: anObject [

	directoryD := anObject
]

{ #category : 'accessing' }
GPHCompareJob >> directoryH [

	^ directoryH
]

{ #category : 'accessing' }
GPHCompareJob >> directoryH: anObject [

	directoryH := anObject
]

{ #category : 'accessing' }
GPHCompareJob >> id [

	^ id
]

{ #category : 'accessing' }
GPHCompareJob >> id: anObject [

	id := anObject
]

{ #category : 'initialization' }
GPHCompareJob >> initialize [

	super initialize.
	state := #pending
]

{ #category : 'testing' }
GPHCompareJob >> isFinished [

	^ #( #done #failed #stopped ) includes: state
]

{ #category : 'accessing' }
GPHCompareJob >> outputDirectory [

	^ outputDirectory
]

{ #category : 'accessing' }
GPHCompareJob >> outputDirectory: anObject [

	outputDirectory := anObject
]

{ #category : 'running' }
GPHCompareJob >> runComparison [

	[
		comparator
			compare: directoryD
			with: directoryH
			into: outputDirectory.
		state := #done ]
		on: Error
		do: [ :error |
				errorMessage := error messageText asString.
				state := #failed ]
]

{ #category : 'running' }
GPHCompareJob >> start [

	state := #running.
	process := [ self runComparison ]
		           forkAt: Processor userBackgroundPriority
		           named: 'GPH-' , id
]

{ #category : 'accessing' }
GPHCompareJob >> state [

	^ state
]

{ #category : 'accessing' }
GPHCompareJob >> status [

	^ OrderedDictionary new
		  at: 'runId' put: id;
		  at: 'state' put: state;
		  at: 'directoryD' put: directoryD fullName;
		  at: 'directoryH' put: directoryH fullName;
		  at: 'output' put: (outputDirectory / 'consistency.json') fullName;
		  at: 'error' put: errorMessage;
		  yourself
]

{ #category : 'running' }
GPHCompareJob >> stop [

	self isFinished ifTrue: [ ^ self ].
	process ifNotNil: [ :comparisonProcess | comparisonProcess terminate ].
	state := #stopped
]
