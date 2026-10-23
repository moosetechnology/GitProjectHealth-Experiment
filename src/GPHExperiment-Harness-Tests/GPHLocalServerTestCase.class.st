"
Abstract test case running a local ZnServer on a system-assigned port (ZnServer on: 0). The server records every request it receives (URI and headers) and counts the hits per path; the test sets the responder block, which receives the request and the hit count of its path. No request ever leaves localhost. The server is stopped in tearDown.
"
Class {
	#name : 'GPHLocalServerTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'server',
		'port',
		'received',
		'hits',
		'responder',
		'mutex'
	],
	#category : 'GPHExperiment-Harness-Tests-Http',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Http'
}

{ #category : 'testing' }
GPHLocalServerTestCase class >> isAbstract [

	^ self = GPHLocalServerTestCase
]

{ #category : 'server' }
GPHLocalServerTestCase >> baseUrl [

	^ 'http://localhost:' , port printString
]

{ #category : 'server' }
GPHLocalServerTestCase >> handle: aRequest [
	"Record the request and its hit count per path, then let the responder of the test answer."

	| hitCount path |
	path := aRequest uri pathPrintString.
	mutex critical: [
			received add: aRequest.
			hitCount := (hits at: path ifAbsent: [ 0 ]) + 1.
			hits at: path put: hitCount ].
	^ responder value: aRequest value: hitCount
]

{ #category : 'server' }
GPHLocalServerTestCase >> hitsOf: aPath [

	^ mutex critical: [ hits at: aPath ifAbsent: [ 0 ] ]
]

{ #category : 'responses' }
GPHLocalServerTestCase >> jsonResponse: aJsonString [

	^ self jsonResponse: aJsonString status: 200 headers: Dictionary new
]

{ #category : 'responses' }
GPHLocalServerTestCase >> jsonResponse: aJsonString status: aCode headers: aDictionary [

	| response |
	response := ZnResponse statusLine: (ZnStatusLine code: aCode).
	response entity:
		(ZnEntity with: aJsonString type: ZnMimeType applicationJson).
	aDictionary keysAndValuesDo: [ :name :value |
		response headers at: name put: value asString ].
	^ response
]

{ #category : 'fixtures' }
GPHLocalServerTestCase >> newClock [

	^ GPHFakeClock new
]

{ #category : 'server' }
GPHLocalServerTestCase >> received [

	^ mutex critical: [ received copy ]
]

{ #category : 'server' }
GPHLocalServerTestCase >> receivedUris [
	"Answer the raw request targets (path and query) received by the server, in order."

	^ self received collect: [ :request | request uri printString ]
]

{ #category : 'server' }
GPHLocalServerTestCase >> respondWith: aBlock [
	"aBlock receives the request and the number of times its path was hit (1 for the first request)."

	responder := aBlock
]

{ #category : 'running' }
GPHLocalServerTestCase >> setUp [
	"Start a local server on a port chosen by the system, then read the port back."

	super setUp.
	received := OrderedCollection new.
	hits := Dictionary new.
	mutex := Mutex new.
	responder := [ :request :hitCount | self jsonResponse: '{}' ].
	server := ZnServer on: 0.
	server onRequestRespond: [ :request | self handle: request ].
	server start.
	port := server port
]

{ #category : 'running' }
GPHLocalServerTestCase >> tearDown [

	server ifNotNil: [ :localServer | localServer stop ].
	super tearDown
]

{ #category : 'server' }
GPHLocalServerTestCase >> urlFor: aPathAndQuery [

	^ self baseUrl , aPathAndQuery
]
