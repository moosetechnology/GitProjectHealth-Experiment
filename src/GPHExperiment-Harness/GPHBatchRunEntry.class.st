"
I am the record of one run of a GPHRunBatch: its position, its configuration, and what the batch observed (state pending|running|done|failed|timeout|stopped|skipped, launch and end times, anomaly and rate-limit flags, error).

I never hold the token: my dictionary only contains the public fields of the configuration.
"
Class {
	#name : 'GPHBatchRunEntry',
	#superclass : 'Object',
	#instVars : [
		'index',
		'config',
		'state',
		'launchedAt',
		'endedAt',
		'anomaly',
		'rateLimited',
		'error'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHBatchRunEntry class >> index: anInteger config: aRunConfig [

	^ self new
		  setIndex: anInteger config: aRunConfig;
		  yourself
]

{ #category : 'converting' }
GPHBatchRunEntry >> asDictionary [
	"The entry as written in batch-status.json; only the public fields of the configuration, never the token."

	| configDictionary |
	configDictionary := config asDictionary.
	^ OrderedDictionary new
		  at: 'index' put: index;
		  at: 'runId' put: self runId;
		  at: 'repo' put: (configDictionary at: 'repo');
		  at: 'mode' put: (configDictionary at: 'mode');
		  at: 'clone' put: (configDictionary at: 'clone');
		  at: 'since' put: (configDictionary at: 'since');
		  at: 'until' put: (configDictionary at: 'until');
		  at: 'state' put: state;
		  at: 'launchedAt' put: (GPHTime iso: launchedAt);
		  at: 'endedAt' put: (GPHTime iso: endedAt);
		  at: 'anomaly' put: anomaly;
		  at: 'rateLimited' put: rateLimited;
		  at: 'error' put: error;
		  yourself
]

{ #category : 'accessing' }
GPHBatchRunEntry >> config [

	^ config
]

{ #category : 'accessing' }
GPHBatchRunEntry >> endedAt [

	^ endedAt
]

{ #category : 'accessing' }
GPHBatchRunEntry >> error [

	^ error
]

{ #category : 'accessing' }
GPHBatchRunEntry >> index [

	^ index
]

{ #category : 'initialization' }
GPHBatchRunEntry >> initialize [

	super initialize.
	state := #pending.
	anomaly := false.
	rateLimited := false
]

{ #category : 'testing' }
GPHBatchRunEntry >> isPending [

	^ state = #pending
]

{ #category : 'testing' }
GPHBatchRunEntry >> isRunning [

	^ state = #running
]

{ #category : 'accessing' }
GPHBatchRunEntry >> launchedAt [

	^ launchedAt
]

{ #category : 'recording' }
GPHBatchRunEntry >> markLaunchedAt: aDateAndTime [

	state := #running.
	launchedAt := aDateAndTime
]

{ #category : 'recording' }
GPHBatchRunEntry >> markSkipped [

	state := #skipped
]

{ #category : 'recording' }
GPHBatchRunEntry >> noteError: aString [
	"Record an error observed by the batch itself (not by the run)."

	error := OrderedDictionary new
		         at: 'class' put: GPHRunBatch name;
		         at: 'message' put: aString;
		         yourself
]

{ #category : 'recording' }
GPHBatchRunEntry >> recordStatus: aRunStatus at: aDateAndTime [
	"Copy the outcome of the run from its status Dictionary (GPHRunner>>#statusDictionary)."

	state := (aRunStatus at: 'state') asSymbol.
	anomaly := aRunStatus at: 'anomaly' ifAbsent: [ false ].
	rateLimited := aRunStatus at: 'rateLimited' ifAbsent: [ false ].
	error := aRunStatus at: 'error' ifAbsent: [ nil ].
	endedAt := aDateAndTime
]

{ #category : 'accessing' }
GPHBatchRunEntry >> runId [

	^ config runId
]

{ #category : 'initialization' }
GPHBatchRunEntry >> setIndex: anInteger config: aRunConfig [

	index := anInteger.
	config := aRunConfig
]

{ #category : 'accessing' }
GPHBatchRunEntry >> state [

	^ state
]
