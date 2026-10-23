"
Wiring of the importers built for modes D and H. Building does not send any request; the API base URL points to localhost anyway.
"
Class {
	#name : 'GPHImporterFactoryTest',
	#superclass : 'TestCase',
	#instVars : [
		'factory',
		'recorder',
		'since'
	],
	#category : 'GPHExperiment-Harness-Tests-Importing',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Importing'
}

{ #category : 'running' }
GPHImporterFactoryTest >> setUp [

	super setUp.
	since := '2026-01-01T00:00:00Z' asDateAndTime.
	recorder := GPHApiCallRecorder new.
	factory := GPHImporterFactory new
		           recorder: recorder;
		           clock: GPHFakeClock new;
		           tokenProvider:
			           (GPHTokenProvider token: 'SECRET-FACTORY' source: 'env');
		           since: since;
		           apiBaseUrl: 'http://localhost:9';
		           yourself
]

{ #category : 'tests' }
GPHImporterFactoryTest >> testBuildDWiresAnInstrumentedApiImporter [

	| set api client |
	set := factory buildD.
	api := set api.
	self assert: set importer identicalTo: api.
	self assert: (api isKindOf: GithubModelImporter).
	client := api repoApi client.
	self assert: (client isKindOf: GPHInstrumentedZnClient).
	self assert: client recorder identicalTo: recorder.
	self assert: api repoApi hostUrl equals: 'http://localhost:9'.
	self
		assert: (client request headers at: 'Authorization')
		equals: 'token SECRET-FACTORY'.
	self deny: api withCommitDiffs.
	self assert: api withCommitsSince equals: since.
	self assert: api glhModel identicalTo: set model.
	self assert: set fallbacks isEmpty
]

{ #category : 'tests' }
GPHImporterFactoryTest >> testBuildHWiresTheMixedImporter [
	"The mixed importer drives an instrumented API importer and an observed local importer; the three share one model, know the mixed importer as factory, and use the same since; the local importer does not import diffs during the walk."

	| set mixed api local |
	set := factory buildH.
	mixed := set mixed.
	api := set api.
	local := set local.
	self assert: set importer identicalTo: mixed.
	self assert: (mixed isKindOf: GitModelMixedImporter).
	self assert: mixed apiImporter identicalTo: api.
	self assert: mixed localImporter identicalTo: local.
	self assert: (local isKindOf: GPHObservedLocalModelImporter).
	self assert: (api repoApi client isKindOf: GPHInstrumentedZnClient).
	self assert: mixed glhModel identicalTo: set model.
	self assert: api glhModel identicalTo: set model.
	self assert: local glhModel identicalTo: set model.
	self assert: api factoryImporter identicalTo: mixed.
	self assert: local factoryImporter identicalTo: mixed.
	self assert: mixed withCommitsSince equals: since.
	self assert: api withCommitsSince equals: since.
	self assert: local withCommitsSince equals: since.
	self deny: local withCommitDiffs.
	self deny: api withCommitDiffs
]
