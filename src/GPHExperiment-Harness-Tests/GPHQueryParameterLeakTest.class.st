"
T-F5: a real GithubApi pointed at the local server with the instrumented client. The query parameters of a list request (since, page) must not leak into the next request made with the same client (commits/:sha).
"
Class {
	#name : 'GPHQueryParameterLeakTest',
	#superclass : 'GPHLocalServerTestCase',
	#instVars : [
		'recorder',
		'client',
		'api'
	],
	#category : 'GPHExperiment-Harness-Tests-Http',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Http'
}

{ #category : 'running' }
GPHQueryParameterLeakTest >> setUp [

	super setUp.
	recorder := GPHApiCallRecorder new.
	client := GPHInstrumentedZnClient new
		          recorder: recorder;
		          clock: self newClock;
		          yourself.
	api := GithubApi new.
	api
		hostUrl: self baseUrl;
		client: client;
		privateToken: 'SECRET-TF5'.
	self respondWith: [ :request :hitCount |
			(request uri pathPrintString endsWith: '/commits')
				ifTrue: [ self jsonResponse: '[]' ]
				ifFalse: [ self jsonResponse: '{"sha":"abc","files":[]}' ] ]
]

{ #category : 'running' }
GPHQueryParameterLeakTest >> tearDown [

	client ifNotNil: [ :instrumented | instrumented close ].
	super tearDown
]

{ #category : 'tests' }
GPHQueryParameterLeakTest >> testCommitRequestDoesNotInheritListParameters [
	"T-F5: GET commits?since=X and page=1, then GET commits/abc on the same client. The second URL received by the server must carry neither since nor page. The failure message shows both raw URLs."

	| uris report |
	api commits getForRepo: 'r' ofOwner: 'o' withParms: {
			(#since -> 'X').
			(#page -> 1) } asDictionary.
	api commits getCommit: 'abc' ForRepo: 'r' ofOwner: 'o'.

	uris := self receivedUris.
	report := 'received URLs: ' , (' | ' join: uris).
	self assert: uris size equals: 2.
	self
		assert: (uris first includesSubstring: 'since=X')
		description: report.
	self
		assert: (uris first includesSubstring: 'page=1')
		description: report.
	self
		assert: (uris second beginsWith: '/repos/o/r/commits/abc')
		description: report.
	self
		deny: (uris second includesSubstring: 'since')
		description: report.
	self
		deny: (uris second includesSubstring: 'page')
		description: report
]
