"
A stand-in for IceCredentialStore: answers plaintext credentials holding a fixed password (nil when no credentials are stored) and records the requested host names.
"
Class {
	#name : 'GPHFakeCredentialStore',
	#superclass : 'Object',
	#instVars : [
		'password',
		'requestedHosts'
	],
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
GPHFakeCredentialStore >> password: aString [

	password := aString
]

{ #category : 'credentials' }
GPHFakeCredentialStore >> plaintextCredentialForHostname: aHostname [
	"Same protocol as IceCredentialStore: answer credentials, with a nil password when none are stored."

	self requestedHosts add: aHostname.
	^ IcePlaintextCredentials new
		  username: 'git';
		  password: password;
		  yourself
]

{ #category : 'accessing' }
GPHFakeCredentialStore >> requestedHosts [

	^ requestedHosts ifNil: [ requestedHosts := OrderedCollection new ]
]
