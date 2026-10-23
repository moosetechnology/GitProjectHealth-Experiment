"
Cold and warm clone preparation of mode H (GPHHybridMode>>#prepareCloneFor:) on a memory file system: cold deletes only cloneRoot/name, unsafe names are refused without deleting anything, warm requires an existing clone. No clone is ever made.
"
Class {
	#name : 'GPHClonePreparationTest',
	#superclass : 'TestCase',
	#instVars : [
		'fileSystem',
		'cloneRoot'
	],
	#category : 'GPHExperiment-Harness-Tests-Run',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Run'
}

{ #category : 'helpers' }
GPHClonePreparationTest >> assertNothingDeleted [

	self assert: (cloneRoot / 'keep' / 'file.txt') exists.
	self assert: (fileSystem root / 'work' / 'outside.txt') exists.
	self assert: cloneRoot exists
]

{ #category : 'helpers' }
GPHClonePreparationTest >> configure: aConfig clone: aCloneKind [

	^ aConfig
		  mode: #H;
		  since: '2026-01-01T00:00:00Z';
		  until: '2026-02-01T00:00:00Z';
		  clone: aCloneKind;
		  runId: 'clone-test';
		  cloneRoot: cloneRoot;
		  outputRoot: fileSystem root / 'out';
		  apiBaseUrl: 'http://localhost:9';
		  yourself
]

{ #category : 'helpers' }
GPHClonePreparationTest >> runnerForRawName: aName [

	^ GPHRunner on: (self
			   configure: (GPHRawNameRunConfig new
					    repo: 'o/r';
					    rawRepositoryName: aName;
					    yourself)
			   clone: #cold)
]

{ #category : 'helpers' }
GPHClonePreparationTest >> runnerForRepo: anOwnerSlashName clone: aCloneKind [

	^ GPHRunner on: (self
			   configure: (GPHRunConfig new
					    repo: anOwnerSlashName;
					    yourself)
			   clone: aCloneKind)
]

{ #category : 'running' }
GPHClonePreparationTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory.
	cloneRoot := fileSystem root / 'work' / 'msr'.
	(cloneRoot / 'keep') ensureCreateDirectory.
	cloneRoot / 'keep' / 'file.txt' writeStreamDo: [ :stream |
		stream nextPutAll: 'keep' ].
	fileSystem root / 'work' / 'outside.txt' writeStreamDo: [ :stream |
		stream nextPutAll: 'outside' ]
]

{ #category : 'tests' }
GPHClonePreparationTest >> testColdDeletesOnlyTheExistingClone [

	| runner |
	(cloneRoot / 'r' / '.git') ensureCreateDirectory.
	cloneRoot / 'r' / 'README.md' writeStreamDo: [ :stream |
		stream nextPutAll: 'old clone' ].
	runner := self runnerForRepo: 'o/r' clone: #cold.

	runner mode prepareCloneFor: runner.

	self deny: (cloneRoot / 'r') exists.
	self assertNothingDeleted
]

{ #category : 'tests' }
GPHClonePreparationTest >> testColdWithoutPreviousCloneDoesNothing [

	| runner |
	runner := self runnerForRepo: 'o/r' clone: #cold.

	self shouldnt: [ runner mode prepareCloneFor: runner ] raise: Error.
	self assertNothingDeleted
]

{ #category : 'tests' }
GPHClonePreparationTest >> testDotDotRepositoryFailsTheRunWithoutDeleting [
	"Through the public configuration path: repo 'o/..' passes #validate, then the run fails on the unsafe clone path."

	| runner |
	runner := self runnerForRepo: 'o/..' clone: #cold.
	runner
		tokenProvider:
			(GPHTokenProvider token: 'SECRET-CLONE' source: 'env');
		steps: #(  ).

	runner run.

	self assert: runner state equals: #failed.
	self assert: runner errorClassName equals: #GPHUnsafeClonePathError.
	self assertNothingDeleted
]

{ #category : 'tests' }
GPHClonePreparationTest >> testUnsafeNamesAreRefused [
	"'' would target the clone root itself, '..' its parent, 'a/b' a nested directory: all are refused and nothing is deleted."

	(cloneRoot / 'a' / 'b') ensureCreateDirectory.
	#( '' '..' 'a/b' ) do: [ :name |
			| runner |
			runner := self runnerForRawName: name.
			self
				should: [ runner mode prepareCloneFor: runner ]
				raise: GPHUnsafeClonePathError
				description: 'name ' , name printString , ' was accepted'.
			self assertNothingDeleted.
			self assert: (cloneRoot / 'a' / 'b') exists ]
]

{ #category : 'tests' }
GPHClonePreparationTest >> testWarmRequiresAnExistingClone [

	| runner |
	runner := self runnerForRepo: 'o/r' clone: #warm.
	self
		should: [ runner mode prepareCloneFor: runner ]
		raise: GPHWarmMissError.

	(cloneRoot / 'r' / '.git') ensureCreateDirectory.
	self shouldnt: [ runner mode prepareCloneFor: runner ] raise: Error.
	self assert: (cloneRoot / 'r' / '.git') exists
]
