"
I aggregate GPHApiCall records: logical requests, attempts, pages > 1, retries by reason, errors, bytes, duration and minimum X-RateLimit-Remaining.
"
Class {
	#name : 'GPHCallAggregate',
	#superclass : 'Object',
	#instVars : [
		'logicalIds',
		'paginationLogicalIds',
		'attempts',
		'retriesByReason',
		'errors',
		'bytes',
		'durationMs',
		'minRemaining'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'adding' }
GPHCallAggregate >> add: anApiCall [

	logicalIds add: anApiCall logicalId.
	anApiCall isPagination ifTrue: [
		paginationLogicalIds add: anApiCall logicalId ].
	attempts := attempts + 1.
	anApiCall retryReason ifNotNil: [ :reason |
			retriesByReason
				at: reason
				put: (retriesByReason at: reason ifAbsent: [ 0 ]) + 1 ].
	anApiCall isError ifTrue: [ errors := errors + 1 ].
	bytes := bytes + anApiCall bytes.
	durationMs := durationMs + anApiCall durationMs.
	anApiCall remaining ifNotNil: [ :remaining |
		self noteRemaining: remaining ]
]

{ #category : 'converting' }
GPHCallAggregate >> asDictionary [

	^ OrderedDictionary new
		  at: 'logicalRequests' put: logicalIds size;
		  at: 'attempts' put: attempts;
		  at: 'paginationRequests' put: paginationLogicalIds size;
		  at: 'retries'
		  put:
			  (retriesByReason values
				   inject: 0
				   into: [ :sum :each | sum + each ]);
		  at: 'retriesByReason' put: retriesByReason;
		  at: 'errors' put: errors;
		  at: 'bytes' put: bytes;
		  at: 'durationMs' put: durationMs;
		  at: 'minRemaining' put: minRemaining;
		  yourself
]

{ #category : 'initialization' }
GPHCallAggregate >> initialize [

	super initialize.
	logicalIds := Set new.
	paginationLogicalIds := Set new.
	attempts := 0.
	retriesByReason := Dictionary new.
	errors := 0.
	bytes := 0.
	durationMs := 0
]

{ #category : 'private' }
GPHCallAggregate >> noteRemaining: anInteger [

	minRemaining := minRemaining
		                ifNil: [ anInteger ]
		                ifNotNil: [ :current | current min: anInteger ]
]
