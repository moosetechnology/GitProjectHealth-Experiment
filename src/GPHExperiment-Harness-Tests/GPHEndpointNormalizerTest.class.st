"
Normalization of GitHub API paths into endpoint names used to group the recorded calls.
"
Class {
	#name : 'GPHEndpointNormalizerTest',
	#superclass : 'TestCase',
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'tests' }
GPHEndpointNormalizerTest >> testRepositoryEndpoints [
	"Below /repos/owner/name the owner/name prefix is dropped; a 40-hex segment becomes :sha."

	self
		assert: (GPHEndpointNormalizer normalize: '/repos/o/r')
		equals: 'repo'.
	self
		assert: (GPHEndpointNormalizer normalize: '/repos/o/r/commits')
		equals: 'commits'.
	self
		assert: (GPHEndpointNormalizer normalize:
				 '/repos/o/r/commits/0123456789abcdef0123456789ABCDEF01234567')
		equals: 'commits/:sha'.
	self
		assert: (GPHEndpointNormalizer normalize: '/repos/o/r/pulls')
		equals: 'pulls'.
	self
		assert: (GPHEndpointNormalizer normalize: '/repos/o/r/pulls/42')
		equals: 'pulls/:number'
]

{ #category : 'tests' }
GPHEndpointNormalizerTest >> testShortHexIsNotASha [
	"Only full 40-character hexadecimal segments are shas."

	self
		assert: (GPHEndpointNormalizer normalize: '/repos/o/r/commits/abc')
		equals: 'commits/abc'
]

{ #category : 'tests' }
GPHEndpointNormalizerTest >> testUserAndRateLimitEndpoints [

	self
		assert: (GPHEndpointNormalizer normalize: '/users/octocat')
		equals: 'users/:login'.
	self
		assert: (GPHEndpointNormalizer normalize: '/user/123')
		equals: 'user/:id'.
	self
		assert: (GPHEndpointNormalizer normalize: '/rate_limit')
		equals: 'rate_limit'
]
