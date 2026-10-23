"
I describe one run: repo ('owner/name'), mode (#D or #H), clone (#cold or #warm, ignored in D), window [since, until) in UTC, runId, globalTimeout (a Duration), outputRoot, cloneRoot, rateLimitThreshold, diffStrategy (#B) and apiBaseUrl.

	GPHRunConfig verveineJMode: #H clone: #cold.
	GPHRunConfig vscodeMode: #D clone: #cold.
"
Class {
	#name : 'GPHRunConfig',
	#superclass : 'Object',
	#instVars : [
		'repo',
		'mode',
		'clone',
		'since',
		'until',
		'runId',
		'globalTimeout',
		'outputRoot',
		'cloneRoot',
		'rateLimitThreshold',
		'diffStrategy',
		'apiBaseUrl'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHRunConfig class >> repo: anOwnerSlashName mode: aMode since: aSince until: anUntil [
	"aSince and anUntil are DateAndTime or ISO strings; they are converted to UTC."

	^ self new
		  repo: anOwnerSlashName;
		  mode: aMode;
		  since: aSince;
		  until: anUntil;
		  yourself
]

{ #category : 'instance creation' }
GPHRunConfig class >> verveineJMode: aMode clone: aClone [
	"moosetechnology/VerveineJ on [2025-10-01, 2026-10-01), global timeout 30 min."

	^ (self
		   repo: 'moosetechnology/VerveineJ'
		   mode: aMode
		   since: '2025-10-01T00:00:00Z'
		   until: '2026-10-01T00:00:00Z')
		  clone: aClone;
		  globalTimeout: 30 minutes;
		  rateLimitThreshold: 500;
		  yourself
]

{ #category : 'instance creation' }
GPHRunConfig class >> vscodeMode: aMode clone: aClone [
	"microsoft/vscode on [2026-09-01, 2026-10-01), global timeout 2 h."

	^ (self
		   repo: 'microsoft/vscode'
		   mode: aMode
		   since: '2026-09-01T00:00:00Z'
		   until: '2026-10-01T00:00:00Z')
		  clone: aClone;
		  globalTimeout: 2 hours;
		  rateLimitThreshold: 4000;
		  yourself
]

{ #category : 'accessing' }
GPHRunConfig >> apiBaseUrl [

	^ apiBaseUrl
]

{ #category : 'accessing' }
GPHRunConfig >> apiBaseUrl: anObject [

	apiBaseUrl := anObject
]

{ #category : 'converting' }
GPHRunConfig >> asDictionary [
	"The configuration as written in meta.json (it never holds the token)."

	^ OrderedDictionary new
		  at: 'repo' put: repo;
		  at: 'mode' put: mode;
		  at: 'clone' put: (self modeStrategy cloneLabelFor: self);
		  at: 'since' put: (GPHTime iso: since);
		  at: 'until' put: (GPHTime iso: until);
		  at: 'runId' put: self runId;
		  at: 'globalTimeoutSeconds' put: globalTimeout asSeconds;
		  at: 'outputRoot' put: outputRoot fullName;
		  at: 'cloneRoot' put: cloneRoot fullName;
		  at: 'rateLimitThreshold' put: rateLimitThreshold;
		  at: 'diffStrategy' put: diffStrategy;
		  at: 'apiBaseUrl' put: apiBaseUrl;
		  yourself
]

{ #category : 'accessing' }
GPHRunConfig >> clone [

	^ clone
]

{ #category : 'accessing' }
GPHRunConfig >> clone: aCloneName [

	clone := aCloneName asSymbol
]

{ #category : 'accessing' }
GPHRunConfig >> clonePath [
	"Same location as GitLocalModelImporter>>#tryClone: when cloneRoot is the default workingDirectory/msr."

	^ cloneRoot / self repositoryName
]

{ #category : 'accessing' }
GPHRunConfig >> cloneRoot [

	^ cloneRoot
]

{ #category : 'accessing' }
GPHRunConfig >> cloneRoot: anObject [

	cloneRoot := anObject
]

{ #category : 'private' }
GPHRunConfig >> defaultRunId [

	^ '-' join: {
			  self repositoryName.
			  mode asString.
			  (self modeStrategy cloneLabelFor: self).
			  (GPHTime compactStamp: DateAndTime now) }
]

{ #category : 'accessing' }
GPHRunConfig >> diffStrategy [

	^ diffStrategy
]

{ #category : 'accessing' }
GPHRunConfig >> diffStrategy: aStrategyName [

	diffStrategy := aStrategyName asSymbol
]

{ #category : 'accessing' }
GPHRunConfig >> globalTimeout [

	^ globalTimeout
]

{ #category : 'accessing' }
GPHRunConfig >> globalTimeout: anObject [

	globalTimeout := anObject
]

{ #category : 'initialization' }
GPHRunConfig >> initialize [

	super initialize.
	clone := #cold.
	diffStrategy := #B.
	rateLimitThreshold := 1000.
	globalTimeout := 30 minutes.
	outputRoot := FileSystem workingDirectory / 'gph-exp-out'.
	cloneRoot := FileSystem workingDirectory / 'msr'.
	apiBaseUrl := 'https://api.github.com'
]

{ #category : 'testing' }
GPHRunConfig >> isColdClone [

	^ clone = #cold
]

{ #category : 'testing' }
GPHRunConfig >> isInWindow: aDateAndTime [
	"The window is [since, until)."

	^ aDateAndTime notNil and: [
		  aDateAndTime >= since and: [ aDateAndTime < until ] ]
]

{ #category : 'accessing' }
GPHRunConfig >> mode [

	^ mode
]

{ #category : 'accessing' }
GPHRunConfig >> mode: aModeName [

	mode := aModeName asSymbol
]

{ #category : 'accessing' }
GPHRunConfig >> modeStrategy [

	^ GPHRunMode forMode: mode
]

{ #category : 'accessing' }
GPHRunConfig >> outputDirectory [

	^ outputRoot / self runId
]

{ #category : 'accessing' }
GPHRunConfig >> outputRoot [

	^ outputRoot
]

{ #category : 'accessing' }
GPHRunConfig >> outputRoot: anObject [

	outputRoot := anObject
]

{ #category : 'accessing' }
GPHRunConfig >> owner [

	^ (repo substrings: '/') first
]

{ #category : 'accessing' }
GPHRunConfig >> rateLimitThreshold [

	^ rateLimitThreshold
]

{ #category : 'accessing' }
GPHRunConfig >> rateLimitThreshold: anObject [

	rateLimitThreshold := anObject
]

{ #category : 'accessing' }
GPHRunConfig >> repo [

	^ repo
]

{ #category : 'accessing' }
GPHRunConfig >> repo: anObject [

	repo := anObject
]

{ #category : 'accessing' }
GPHRunConfig >> repositoryName [

	^ (repo substrings: '/') last
]

{ #category : 'accessing' }
GPHRunConfig >> runId [
	"Answer the run id, generated on first access: <name>-<mode>-<clone|api>-<UTC stamp>."

	^ runId ifNil: [ runId := self defaultRunId ]
]

{ #category : 'accessing' }
GPHRunConfig >> runId: aString [

	runId := aString
]

{ #category : 'accessing' }
GPHRunConfig >> since [

	^ since
]

{ #category : 'accessing' }
GPHRunConfig >> since: aDateAndTimeOrString [

	since := aDateAndTimeOrString asDateAndTime asUTC
]

{ #category : 'accessing' }
GPHRunConfig >> until [

	^ until
]

{ #category : 'accessing' }
GPHRunConfig >> until: aDateAndTimeOrString [

	until := aDateAndTimeOrString asDateAndTime asUTC
]

{ #category : 'validating' }
GPHRunConfig >> validate [

	(repo notNil and: [ (repo substrings: '/') size = 2 ]) ifFalse: [
		GPHConfigurationError signal: 'repo must be owner/name' ].
	self modeStrategy.
	(#( #cold #warm ) includes: clone) ifFalse: [
		GPHConfigurationError signal: 'clone must be #cold or #warm' ].
	diffStrategy = #B ifFalse: [
		GPHConfigurationError signal: 'only diffStrategy #B is implemented' ].
	(since notNil and: [ until notNil and: [ since < until ] ]) ifFalse: [
		GPHConfigurationError signal: 'since must be before until' ].
	globalTimeout ifNil: [
		GPHConfigurationError signal: 'globalTimeout is required' ]
]
