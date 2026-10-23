"
I provide the GitHub token: first the GITHUB_TOKEN environment variable, then the Iceberg plaintext credentials of github.com (password field).

I never print the token: only its source ('env' or 'iceberg') is exposed for logging. I also redact the token from any string before it is written (#redact:).

Both lookups are injectable (#environment:, #credentialStore:); tests may use #token:source:.
"
Class {
	#name : 'GPHTokenProvider',
	#superclass : 'Object',
	#instVars : [
		'environment',
		'credentialStore',
		'token',
		'source'
	],
	#category : 'GPHExperiment-Harness-Support',
	#package : 'GPHExperiment-Harness',
	#tag : 'Support'
}

{ #category : 'instance creation' }
GPHTokenProvider class >> token: aString source: aSource [
	"Answer a provider with a fixed token, e.g. for tests."

	^ self new
		  useToken: aString from: aSource;
		  yourself
]

{ #category : 'accessing' }
GPHTokenProvider >> credentialStore [
	"Answer the Iceberg credential store (injectable; any object answering #plaintextCredentialForHostname:)."

	^ credentialStore ifNil: [
		  credentialStore := IceCredentialStore current ]
]

{ #category : 'accessing' }
GPHTokenProvider >> credentialStore: aCredentialStore [

	credentialStore := aCredentialStore
]

{ #category : 'accessing' }
GPHTokenProvider >> environment [
	"Answer a dictionary-like lookup of environment variables (injectable)."

	^ environment ifNil: [ environment := Smalltalk os environment ]
]

{ #category : 'accessing' }
GPHTokenProvider >> environment: aDictionaryLike [

	environment := aDictionaryLike
]

{ #category : 'private' }
GPHTokenProvider >> environmentTokenDo: aBlock [

	| value |
	value := self environment
		         at: self environmentVariableName
		         ifAbsent: [ ^ self ].
	value ifNotEmpty: aBlock
]

{ #category : 'defaults' }
GPHTokenProvider >> environmentVariableName [

	^ 'GITHUB_TOKEN'
]

{ #category : 'defaults' }
GPHTokenProvider >> githubHost [

	^ 'github.com'
]

{ #category : 'private' }
GPHTokenProvider >> icebergTokenDo: aBlock [

	| credentials |
	credentials := self credentialStore plaintextCredentialForHostname:
		               self githubHost.
	credentials password ifNotNil: [ :password |
		password ifNotEmpty: aBlock ]
]

{ #category : 'printing' }
GPHTokenProvider >> printOn: aStream [
	"Never print the token itself."

	super printOn: aStream.
	aStream
		nextPutAll: '(source: ';
		print: source;
		nextPut: $)
]

{ #category : 'redacting' }
GPHTokenProvider >> redact: aString [
	"Answer aString with every occurrence of the token replaced. Must be applied to anything written to a file, a log or an error message."

	| text |
	text := aString asString.
	(token isNil or: [ token isEmpty ]) ifTrue: [ ^ text ].
	^ text copyReplaceAll: token with: self redactionMark
]

{ #category : 'redacting' }
GPHTokenProvider >> redactionMark [

	^ '[REDACTED]'
]

{ #category : 'resolving' }
GPHTokenProvider >> resolve [
	"Environment variable first, then Iceberg plaintext credentials of github.com."

	self environmentTokenDo: [ :found |
		^ self useToken: found from: 'env' ].
	self icebergTokenDo: [ :found |
		^ self useToken: found from: 'iceberg' ].
	GPHMissingTokenError signal:
		'No GitHub token: set GITHUB_TOKEN or store github.com credentials in Iceberg'
]

{ #category : 'accessing' }
GPHTokenProvider >> source [
	"Answer the source of the token if it was already resolved, nil otherwise. Does not resolve."

	^ source
]

{ #category : 'accessing' }
GPHTokenProvider >> token [
	"Answer the GitHub token, resolving it on first use. Never print nor log it."

	token ifNil: [ self resolve ].
	^ token
]

{ #category : 'accessing' }
GPHTokenProvider >> tokenSource [
	"Answer 'env' or 'iceberg', resolving the token on first use."

	source ifNil: [ self resolve ].
	^ source
]

{ #category : 'private' }
GPHTokenProvider >> useToken: aString from: aSource [

	token := aString.
	source := aSource
]
