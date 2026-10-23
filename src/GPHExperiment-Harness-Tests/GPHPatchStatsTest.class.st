"
Line statistics computed from unified diff patches (GitHub patch or local diff with its preamble).
"
Class {
	#name : 'GPHPatchStatsTest',
	#superclass : 'TestCase',
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'tests' }
GPHPatchStatsTest >> testBinaryPatch [

	| stats |
	stats := GPHPatchStats statsOf: 'Binary files a/x and b/x differ'.
	self assert: stats binary.
	self assert: stats additions equals: 0.
	self assert: stats deletions equals: 0
]

{ #category : 'tests' }
GPHPatchStatsTest >> testCountsAddedAndDeletedLines [

	| stats |
	stats := GPHPatchStats statsOf:
		         (String lf join: #( '@@ -1,2 +1,3 @@' ' a' '-b' '+c' '+d' )).
	self assert: stats additions equals: 2.
	self assert: stats deletions equals: 1.
	self assert: stats patchPresent.
	self deny: stats binary
]

{ #category : 'tests' }
GPHPatchStatsTest >> testLocalPreambleIsIgnored [
	"The local diff preamble (diff --git, index, --- a/x, +++ b/x) must not be counted as changed lines."

	| stats |
	stats := GPHPatchStats statsOf: (String lf join:
			          #( 'diff --git a/x b/x' 'index 1234567..89abcde 100644'
			             '--- a/x' '+++ b/x' '@@ -1,2 +1,3 @@'
			             ' a' '-b' '+c' '+d' )).
	self assert: stats additions equals: 2.
	self assert: stats deletions equals: 1
]

{ #category : 'tests' }
GPHPatchStatsTest >> testMissingPatch [
	"GitHub omits the patch of binary or very large files."

	| stats |
	stats := GPHPatchStats statsOf: nil.
	self deny: stats patchPresent.
	self deny: stats binary.
	self assert: stats additions equals: 0.
	self assert: stats deletions equals: 0
]
