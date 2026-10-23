"
Token resolution (environment first, then Iceberg credentials), redaction, and printing without the token. The environment and the credential store are fakes: the real ones are never read.
"
Class {
	#name : 'GPHTokenProviderTest',
	#superclass : 'TestCase',
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'tests' }
GPHTokenProviderTest >> testEnvironmentTokenComesFirst [

	| store provider |
	store := GPHFakeCredentialStore new password: 'ICEBERG-TOKEN'.
	provider := GPHTokenProvider new
		            environment: (Dictionary new
				             at: 'GITHUB_TOKEN' put: 'ENV-TOKEN';
				             yourself);
		            credentialStore: store;
		            yourself.
	self assert: provider token equals: 'ENV-TOKEN'.
	self assert: provider tokenSource equals: 'env'.
	self assert: store requestedHosts isEmpty
]

{ #category : 'tests' }
GPHTokenProviderTest >> testIcebergTokenWhenEnvironmentIsEmpty [
	"An empty GITHUB_TOKEN counts as absent."

	| store provider |
	store := GPHFakeCredentialStore new password: 'ICEBERG-TOKEN'.
	provider := GPHTokenProvider new
		            environment: (Dictionary new
				             at: 'GITHUB_TOKEN' put: '';
				             yourself);
		            credentialStore: store;
		            yourself.
	self assert: provider tokenSource equals: 'iceberg'.
	self assert: provider token equals: 'ICEBERG-TOKEN'.
	self assert: store requestedHosts asArray equals: #( 'github.com' )
]

{ #category : 'tests' }
GPHTokenProviderTest >> testMissingTokenSignalsError [

	| provider |
	provider := GPHTokenProvider new
		            environment: Dictionary new;
		            credentialStore: GPHFakeCredentialStore new;
		            yourself.
	self should: [ provider token ] raise: GPHMissingTokenError.
	self should: [ provider tokenSource ] raise: GPHMissingTokenError
]

{ #category : 'tests' }
GPHTokenProviderTest >> testPrintStringHidesToken [

	| provider |
	provider := GPHTokenProvider new
		            environment: (Dictionary new
				             at: 'GITHUB_TOKEN' put: 'SECRET-PRINT';
				             yourself);
		            credentialStore: GPHFakeCredentialStore new;
		            yourself.
	provider token.
	self deny: (provider printString includesSubstring: 'SECRET-PRINT').
	self assert: (provider printString includesSubstring: 'env').
	self deny:
		((GPHTokenProvider token: 'SECRET-PRINT' source: 'iceberg')
			 printString includesSubstring: 'SECRET-PRINT')
]

{ #category : 'tests' }
GPHTokenProviderTest >> testRedactReplacesEveryOccurrence [

	| provider |
	provider := GPHTokenProvider token: 'SECRET-123' source: 'env'.
	self
		assert: (provider redact: 'Bearer SECRET-123 and again SECRET-123')
		equals: 'Bearer [REDACTED] and again [REDACTED]'.
	self assert: (provider redact: 'nothing here') equals: 'nothing here'
]
