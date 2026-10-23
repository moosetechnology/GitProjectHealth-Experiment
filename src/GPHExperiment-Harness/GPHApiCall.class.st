"
I record one real HTTP exchange (one wire attempt) made by a GPHInstrumentedZnClient. Request headers are never recorded; only a white list of X-RateLimit-* response headers is kept.
"
Class {
	#name : 'GPHApiCall',
	#superclass : 'Object',
	#instVars : [
		'seq',
		'logicalId',
		'attempt',
		'retryReason',
		'page',
		'method',
		'endpoint',
		'path',
		'query',
		'status',
		'durationMs',
		'bytes',
		'rateLimitHeaders',
		'linkNext',
		'step',
		'startedAt',
		'errorClass'
	],
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'converting' }
GPHApiCall >> asDictionary [

	^ OrderedDictionary new
		  at: 'seq' put: seq;
		  at: 'logicalId' put: logicalId;
		  at: 'attempt' put: attempt;
		  at: 'isRetry' put: self isRetry;
		  at: 'retryReason' put: retryReason;
		  at: 'isPagination' put: self isPagination;
		  at: 'page' put: page;
		  at: 'method' put: method;
		  at: 'endpoint' put: endpoint;
		  at: 'path' put: path;
		  at: 'query' put: query;
		  at: 'status' put: status;
		  at: 'durationMs' put: durationMs;
		  at: 'bytes' put: bytes;
		  at: 'rateLimit' put: rateLimitHeaders;
		  at: 'linkNext' put: linkNext;
		  at: 'step' put: step;
		  at: 'startedAt' put: (GPHTime isoMillis: startedAt);
		  at: 'error' put: errorClass;
		  yourself
]

{ #category : 'accessing' }
GPHApiCall >> attempt [

	^ attempt
]

{ #category : 'accessing' }
GPHApiCall >> attempt: anObject [

	attempt := anObject
]

{ #category : 'accessing' }
GPHApiCall >> bytes [

	^ bytes
]

{ #category : 'accessing' }
GPHApiCall >> bytes: anObject [

	bytes := anObject
]

{ #category : 'accessing' }
GPHApiCall >> durationMs [

	^ durationMs
]

{ #category : 'accessing' }
GPHApiCall >> durationMs: anObject [

	durationMs := anObject
]

{ #category : 'accessing' }
GPHApiCall >> endpoint [

	^ endpoint
]

{ #category : 'accessing' }
GPHApiCall >> endpoint: anObject [

	endpoint := anObject
]

{ #category : 'accessing' }
GPHApiCall >> errorClass [

	^ errorClass
]

{ #category : 'accessing' }
GPHApiCall >> errorClass: anObject [

	errorClass := anObject
]

{ #category : 'testing' }
GPHApiCall >> hasNextLinkForCommit: aSha [
	"True when this call fetched the files of commit aSha and GitHub announced a next page (files truncated)."

	^ linkNext and: [
		  endpoint = 'commits/:sha' and: [ path endsWith: aSha ] ]
]

{ #category : 'initialization' }
GPHApiCall >> initialize [

	super initialize.
	bytes := 0.
	durationMs := 0.
	linkNext := false.
	rateLimitHeaders := OrderedDictionary new.
	query := OrderedDictionary new
]

{ #category : 'testing' }
GPHApiCall >> isError [
	"A failed exchange (no status) or an HTTP error status."

	^ status isNil or: [ status >= 400 ]
]

{ #category : 'testing' }
GPHApiCall >> isPagination [

	^ page notNil and: [ page > 1 ]
]

{ #category : 'testing' }
GPHApiCall >> isRetry [

	^ retryReason notNil
]

{ #category : 'accessing' }
GPHApiCall >> linkNext [

	^ linkNext
]

{ #category : 'accessing' }
GPHApiCall >> linkNext: anObject [

	linkNext := anObject
]

{ #category : 'accessing' }
GPHApiCall >> logicalId [

	^ logicalId
]

{ #category : 'accessing' }
GPHApiCall >> logicalId: anObject [

	logicalId := anObject
]

{ #category : 'accessing' }
GPHApiCall >> method [

	^ method
]

{ #category : 'accessing' }
GPHApiCall >> method: anObject [

	method := anObject
]

{ #category : 'accessing' }
GPHApiCall >> page [

	^ page
]

{ #category : 'accessing' }
GPHApiCall >> page: anObject [

	page := anObject
]

{ #category : 'accessing' }
GPHApiCall >> path [

	^ path
]

{ #category : 'accessing' }
GPHApiCall >> path: anObject [

	path := anObject
]

{ #category : 'accessing' }
GPHApiCall >> query [

	^ query
]

{ #category : 'accessing' }
GPHApiCall >> query: anObject [

	query := anObject
]

{ #category : 'accessing' }
GPHApiCall >> rateLimitHeaders [

	^ rateLimitHeaders
]

{ #category : 'accessing' }
GPHApiCall >> rateLimitHeaders: anObject [

	rateLimitHeaders := anObject
]

{ #category : 'accessing' }
GPHApiCall >> remaining [
	"Answer X-RateLimit-Remaining as an Integer, or nil when absent."

	^ rateLimitHeaders
		  at: 'X-RateLimit-Remaining'
		  ifPresent: [ :value | value asInteger ]
		  ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GPHApiCall >> retryReason [

	^ retryReason
]

{ #category : 'accessing' }
GPHApiCall >> retryReason: anObject [

	retryReason := anObject
]

{ #category : 'accessing' }
GPHApiCall >> seq [

	^ seq
]

{ #category : 'accessing' }
GPHApiCall >> seq: anObject [

	seq := anObject
]

{ #category : 'accessing' }
GPHApiCall >> startedAt [

	^ startedAt
]

{ #category : 'accessing' }
GPHApiCall >> startedAt: anObject [

	startedAt := anObject
]

{ #category : 'accessing' }
GPHApiCall >> status [

	^ status
]

{ #category : 'accessing' }
GPHApiCall >> status: anObject [

	status := anObject
]

{ #category : 'accessing' }
GPHApiCall >> step [

	^ step
]

{ #category : 'accessing' }
GPHApiCall >> step: anObject [

	step := anObject
]
