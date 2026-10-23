"
A local miss (LGit_GIT_ENOTFOUND) is recorded as a fallback and still reaches the API fallback of GitModelMixedImporter. The local importer is GPHNotFoundLocalImporter, the API importer a GPHFakeApiImporter: no clone, no network.
"
Class {
	#name : 'GPHObservedLocalModelImporterTest',
	#superclass : 'TestCase',
	#category : 'GPHExperiment-Harness-Tests-Importing',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Importing'
}

{ #category : 'tests' }
GPHObservedLocalModelImporterTest >> testLocalMissFallsBackOnApiAndIsRecorded [

	| local api mixed commit |
	local := GPHNotFoundLocalImporter new.
	api := GPHFakeApiImporter new.
	mixed := GitModelMixedImporter new.
	mixed
		apiImporter: api;
		localImporter: local;
		glhModel: GLHModel new.
	commit := GLHCommit new
		          id: 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
		          yourself.

	mixed importDiffOfCommit: commit.

	self assert: api diffRequests asArray equals: { commit }.
	self assert: local fallbacks size equals: 1.
	self assert: local fallbackCount equals: 1.
	self
		assert: local fallbacks first sha
		equals: 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'.
	self
		assert: local fallbacks first operation
		equals: #importDiffOfCommit:.
	self
		assert: local fallbacks first errorClass
		equals: #LGit_GIT_ENOTFOUND
]
