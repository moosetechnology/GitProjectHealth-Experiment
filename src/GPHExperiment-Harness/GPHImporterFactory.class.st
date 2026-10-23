"
I build a fresh GLHModel and fresh importers for a run (#buildD, #buildH). The instrumented client is injected into the GithubApi before the token, commit diffs are disabled on the api and local importers, and the mixed importer is wired with #apiImporter: / #localImporter: then #glhModel:.
"
Class {
	#name : 'GPHImporterFactory',
	#superclass : 'Object',
	#instVars : [
		'recorder',
		'clock',
		'tokenProvider',
		'since',
		'apiBaseUrl'
	],
	#category : 'GPHExperiment-Harness-Importing',
	#package : 'GPHExperiment-Harness',
	#tag : 'Importing'
}

{ #category : 'accessing' }
GPHImporterFactory >> apiBaseUrl [

	^ apiBaseUrl
]

{ #category : 'accessing' }
GPHImporterFactory >> apiBaseUrl: anObject [

	apiBaseUrl := anObject
]

{ #category : 'building' }
GPHImporterFactory >> buildD [
	"Mode D: a fresh model and a GithubModelImporter alone."

	| model api |
	model := GLHModel new.
	api := self newApiImporter.
	api glhModel: model.
	^ GPHImporterSet new
		  model: model;
		  api: api;
		  importer: api;
		  yourself
]

{ #category : 'building' }
GPHImporterFactory >> buildH [
	"Mode H: a fresh model and a GitModelMixedImporter wired to a GithubModelImporter and an observed local importer. #glhModel: on the mixed importer propagates to both. #withCommitDiffs: is deliberately not sent to the mixed importer."

	| model api local mixed |
	model := GLHModel new.
	api := self newApiImporter.
	local := self newLocalImporter.
	mixed := GitModelMixedImporter new.
	mixed
		apiImporter: api;
		localImporter: local;
		withCommitsSince: since;
		glhModel: model.
	^ GPHImporterSet new
		  model: model;
		  api: api;
		  local: local;
		  mixed: mixed;
		  importer: mixed;
		  yourself
]

{ #category : 'accessing' }
GPHImporterFactory >> clock [

	^ clock
]

{ #category : 'accessing' }
GPHImporterFactory >> clock: anObject [

	clock := anObject
]

{ #category : 'initialization' }
GPHImporterFactory >> initialize [

	super initialize.
	recorder := GPHApiCallRecorder new.
	clock := GPHClock new.
	tokenProvider := GPHTokenProvider new.
	apiBaseUrl := 'https://api.github.com'
]

{ #category : 'private' }
GPHImporterFactory >> newApiImporter [
	"The instrumented client must be in place before #privateToken:, which adds the Authorization header to the current client."

	| api |
	api := GithubModelImporter new.
	api repoApi
		hostUrl: apiBaseUrl;
		client: self newInstrumentedClient.
	api privateToken: tokenProvider token.
	api
		withCommitDiffs: false;
		withCommitsSince: since.
	^ api
]

{ #category : 'building' }
GPHImporterFactory >> newInstrumentedClient [

	^ GPHInstrumentedZnClient new
		  recorder: recorder;
		  clock: clock;
		  accept: ZnMimeType applicationJson;
		  yourself
]

{ #category : 'private' }
GPHImporterFactory >> newLocalImporter [

	^ GPHObservedLocalModelImporter new
		  withCommitDiffs: false;
		  withCommitsSince: since;
		  yourself
]

{ #category : 'accessing' }
GPHImporterFactory >> recorder [

	^ recorder
]

{ #category : 'accessing' }
GPHImporterFactory >> recorder: anObject [

	recorder := anObject
]

{ #category : 'accessing' }
GPHImporterFactory >> since [

	^ since
]

{ #category : 'accessing' }
GPHImporterFactory >> since: anObject [

	since := anObject
]

{ #category : 'accessing' }
GPHImporterFactory >> tokenProvider [

	^ tokenProvider
]

{ #category : 'accessing' }
GPHImporterFactory >> tokenProvider: anObject [

	tokenProvider := anObject
]
