"
I am the record of one comparison (D run vs H run) executed by a GPHRunBatch after all its runs: state pending|running|done|failed|stopped|skipped, the comparison id given by the registry, its output directory and its error message if any.
"
Class {
	#name : 'GPHBatchComparisonEntry',
	#superclass : 'Object',
	#instVars : [
		'runIdD',
		'runIdH',
		'compareId',
		'state',
		'outputDirectory',
		'error'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHBatchComparisonEntry class >> runIdD: aRunIdD runIdH: aRunIdH [

	^ self new
		  setRunIdD: aRunIdD runIdH: aRunIdH;
		  yourself
]

{ #category : 'converting' }
GPHBatchComparisonEntry >> asDictionary [
	"The entry as written in batch-status.json."

	^ OrderedDictionary new
		  at: 'runIdD' put: runIdD;
		  at: 'runIdH' put: runIdH;
		  at: 'compareId' put: compareId;
		  at: 'state' put: state;
		  at: 'outputDirectory'
		  put: (outputDirectory ifNotNil: [ :directory | directory fullName ]);
		  at: 'error' put: error;
		  yourself
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> compareId [

	^ compareId
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> error [

	^ error
]

{ #category : 'initialization' }
GPHBatchComparisonEntry >> initialize [

	super initialize.
	state := #pending
]

{ #category : 'testing' }
GPHBatchComparisonEntry >> isPending [

	^ state = #pending
]

{ #category : 'testing' }
GPHBatchComparisonEntry >> isRunning [

	^ state = #running
]

{ #category : 'recording' }
GPHBatchComparisonEntry >> markSkipped [

	state := #skipped
]

{ #category : 'recording' }
GPHBatchComparisonEntry >> markStartedAs: aCompareId outputDirectory: aDirectory [

	compareId := aCompareId.
	outputDirectory := aDirectory.
	state := #running
]

{ #category : 'recording' }
GPHBatchComparisonEntry >> noteError: aString [

	error := aString
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> outputDirectory [

	^ outputDirectory
]

{ #category : 'recording' }
GPHBatchComparisonEntry >> recordStatus: aComparisonStatus [
	"Copy the outcome from the status Dictionary of the GPHCompareJob."

	state := (aComparisonStatus at: 'state') asSymbol.
	error := aComparisonStatus at: 'error' ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> runIdD [

	^ runIdD
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> runIdH [

	^ runIdH
]

{ #category : 'initialization' }
GPHBatchComparisonEntry >> setRunIdD: aRunIdD runIdH: aRunIdH [

	runIdD := aRunIdD.
	runIdH := aRunIdH
]

{ #category : 'accessing' }
GPHBatchComparisonEntry >> state [

	^ state
]
