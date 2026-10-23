"
I compute line statistics of a unified diff patch: the preamble up to the first @@ is ignored, then + lines (except +++) and - lines (except ---) are counted. binary is true when the patch mentions 'Binary files'.

	GPHPatchStats statsOf: aDiffString
"
Class {
	#name : 'GPHPatchStats',
	#superclass : 'Object',
	#instVars : [
		'additions',
		'deletions',
		'patchPresent',
		'binary'
	],
	#category : 'GPHExperiment-Harness-Support',
	#package : 'GPHExperiment-Harness',
	#tag : 'Support'
}

{ #category : 'instance creation' }
GPHPatchStats class >> statsOf: aDiffString [

	^ self new
		  computeFrom: aDiffString;
		  yourself
]

{ #category : 'accessing' }
GPHPatchStats >> additions [

	^ additions
]

{ #category : 'converting' }
GPHPatchStats >> asDictionary [

	^ OrderedDictionary new
		  at: 'additions' put: additions;
		  at: 'deletions' put: deletions;
		  at: 'patch_present' put: patchPresent;
		  at: 'binary' put: binary;
		  yourself
]

{ #category : 'accessing' }
GPHPatchStats >> binary [

	^ binary
]

{ #category : 'computing' }
GPHPatchStats >> computeFrom: aDiffString [
	"aDiffString may be nil: the GitHub API omits the patch of binary or very large files."

	additions := 0.
	deletions := 0.
	patchPresent := aDiffString notNil and: [ aDiffString notEmpty ].
	binary := patchPresent and: [
		          aDiffString includesSubstring: 'Binary files' ].
	patchPresent ifTrue: [ self countLinesOf: aDiffString ]
]

{ #category : 'private' }
GPHPatchStats >> countLine: aLine [

	((aLine beginsWith: '+') and: [ (aLine beginsWith: '+++') not ])
		ifTrue: [ additions := additions + 1 ].
	((aLine beginsWith: '-') and: [ (aLine beginsWith: '---') not ])
		ifTrue: [ deletions := deletions + 1 ]
]

{ #category : 'private' }
GPHPatchStats >> countLinesOf: aDiffString [
	"Skip the preamble until the first hunk header, then count the changed lines."

	| inHunks |
	inHunks := false.
	aDiffString linesDo: [ :line |
			(line beginsWith: '@@')
				ifTrue: [ inHunks := true ]
				ifFalse: [ inHunks ifTrue: [ self countLine: line ] ] ]
]

{ #category : 'accessing' }
GPHPatchStats >> deletions [

	^ deletions
]

{ #category : 'accessing' }
GPHPatchStats >> patchPresent [

	^ patchPresent
]
