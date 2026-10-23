"
I turn a GitHub API path into a normalized endpoint name used to aggregate calls.

/repos/o/r -> repo ; /repos/o/r/commits/<40 hex> -> commits/:sha ; /repos/o/r/pulls/12 -> pulls/:number ; /users/x -> users/:login ; /user/12 -> user/:id ; /rate_limit -> rate_limit
"
Class {
	#name : 'GPHEndpointNormalizer',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Http',
	#package : 'GPHExperiment-Harness',
	#tag : 'Http'
}

{ #category : 'normalizing' }
GPHEndpointNormalizer class >> normalize: aPath [

	^ self new normalize: aPath
]

{ #category : 'testing' }
GPHEndpointNormalizer >> isNumber: aSegment [

	^ aSegment notEmpty and: [
		  aSegment allSatisfy: [ :each | each isDigit ] ]
]

{ #category : 'testing' }
GPHEndpointNormalizer >> isSha: aSegment [

	^ aSegment size = 40 and: [
			  aSegment allSatisfy: [ :each |
				  each isDigit or: [ 'abcdefABCDEF' includes: each ] ] ]
]

{ #category : 'private' }
GPHEndpointNormalizer >> join: segments [

	^ '/' join: segments
]

{ #category : 'normalizing' }
GPHEndpointNormalizer >> normalize: aPath [
	"Answer the normalized endpoint of a GitHub API path (without host nor query)."

	| segments |
	segments := aPath substrings: '/'.
	segments ifEmpty: [ ^ '' ].
	segments first = 'repos' ifTrue: [
		^ self normalizeRepositorySegments: segments ].
	(segments first = 'users' and: [ segments size >= 2 ]) ifTrue: [
			^ self join: #( 'users' ':login' )
				  , (self normalizeSegments: (segments allButFirst: 2)) ].
	(segments first = 'user' and: [ segments size >= 2 ]) ifTrue: [
			^ self join: #( 'user' ':id' )
				  , (self normalizeSegments: (segments allButFirst: 2)) ].
	^ self join: (self normalizeSegments: segments)
]

{ #category : 'private' }
GPHEndpointNormalizer >> normalizeRepositorySegments: segments [
	"/repos/owner/name is the repository itself; below it the owner/name prefix is dropped."

	segments size <= 3 ifTrue: [ ^ 'repo' ].
	^ self join: (self normalizeSegments: (segments allButFirst: 3))
]

{ #category : 'private' }
GPHEndpointNormalizer >> normalizeSegment: aSegment [

	(self isSha: aSegment) ifTrue: [ ^ ':sha' ].
	(self isNumber: aSegment) ifTrue: [ ^ ':number' ].
	^ aSegment
]

{ #category : 'private' }
GPHEndpointNormalizer >> normalizeSegments: segments [

	^ segments collect: [ :each | self normalizeSegment: each ]
]
