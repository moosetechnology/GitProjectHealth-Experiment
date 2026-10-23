"
I write the JSON files of a run in its output directory: meta.json, timings.json, api-calls.json, commits.json, diffs.json, prs.json and counts.json. Dates are ISO UTC with Z. Every file is redacted with the token provider of the run before being written.
"
Class {
	#name : 'GPHRunExporter',
	#superclass : 'Object',
	#instVars : [
		'toolRepositoryName'
	],
	#category : 'GPHExperiment-Harness-Export',
	#package : 'GPHExperiment-Harness',
	#tag : 'Export'
}

{ #category : 'constants' }
GPHRunExporter class >> countedEntityClasses [

	^ {
		  GLHCommit.
		  GLHDiff.
		  GLHUser.
		  GLHMergeRequest.
		  GLHBranch.
		  GLHChange }
]

{ #category : 'constants' }
GPHRunExporter class >> resolutionCategories [

	^ #( #'in-window-model' #local #api #'api-fallback' #'not-found'
	     #'not-merged' )
]

{ #category : 'constants' }
GPHRunExporter class >> toolPatches [
	"Fixes of GithubModelImporter present in the image during the experiment."

	^ #( 'F1' 'F2' 'F3' 'F3b' 'F4' 'F6' 'F8' 'F9' )
]

{ #category : 'commits' }
GPHRunExporter >> commitEntryOf: aCommit in: aRunner [
	"author_name_git: git author name (D: cache #gitAuthorName, H: author_name). author_login: GitHub login (D: author_name, H: null)."

	| mode |
	mode := aRunner mode.
	^ OrderedDictionary new
		  at: 'sha' put: aCommit id;
		  at: 'author_name_git' put: (mode authorNameGitOf: aCommit);
		  at: 'author_login' put: (mode authorLoginOf: aCommit);
		  at: 'author_email' put: aCommit author_email;
		  at: 'committed_date' put: (GPHTime iso: aCommit committed_date);
		  at: 'authored_date' put: (GPHTime iso: aCommit authored_date);
		  at: 'authored_date_semantics' put: mode authoredDateSemantics;
		  at: 'parents_count'
		  put:
			  (aCommit parent_ids
				   ifNil: [ 0 ]
				   ifNotNil: [ :parents | parents size ]);
		  at: 'branches' put: (mode branchesOf: aCommit in: aRunner);
		  at: 'resolved_user' put: (self resolvedUserOf: aCommit);
		  yourself
]

{ #category : 'commits' }
GPHRunExporter >> commitsOf: aRunner [
	"commits.json: the window commits only, sorted by sha."

	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'mode' put: aRunner mode modeName;
		  at: 'since' put: (GPHTime iso: aRunner since);
		  at: 'until' put: (GPHTime iso: aRunner until);
		  at: 'commits'
		  put: ((self sortedWindowCommitsOf: aRunner) collect: [ :commit |
					   self commitEntryOf: commit in: aRunner ]);
		  yourself
]

{ #category : 'counts' }
GPHRunExporter >> countsOf: aRunner [

	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'model' put: (self modelCountsOf: aRunner model);
		  at: 'window' put: (OrderedDictionary new
				   at: 'commits' put: aRunner windowCommits size;
				   at: 'diffs' put: (aRunner windowCommits
						    inject: 0
						    into: [ :sum :commit | sum + commit diffs size ]);
				   at: 'distinctAuthors' put: aRunner windowAuthors size;
				   at: 'pullRequests' put: aRunner pullRequests size;
				   at: 'mergeCommitResolutions'
				   put: (self resolutionHistogramOf: aRunner);
				   at: 'fallbacks' put: aRunner fallbacks size;
				   yourself);
		  yourself
]

{ #category : 'diffs' }
GPHRunExporter >> diffEntryOf: aDiff in: aRunner [

	| stats |
	stats := GPHPatchStats statsOf: aDiff diffString.
	^ OrderedDictionary new
		  at: 'old_path' put: aDiff old_path;
		  at: 'new_path' put: aDiff new_path;
		  at: 'additions' put: stats additions;
		  at: 'deletions' put: stats deletions;
		  at: 'change_type' put: (aRunner mode changeTypeOf: aDiff);
		  at: 'patch_present' put: stats patchPresent;
		  at: 'binary' put: stats binary;
		  yourself
]

{ #category : 'diffs' }
GPHRunExporter >> diffsOf: aRunner [
	"diffs.json: per window commit sha, files_truncated and the file statistics computed by GPHPatchStats."

	| paginated commits |
	paginated := aRunner recorder shasWithTruncatedFiles.
	commits := OrderedDictionary new.
	(self sortedWindowCommitsOf: aRunner) do: [ :commit |
			commits at: commit id put: (OrderedDictionary new
					 at: 'files_truncated'
					 put:
						 (aRunner mode
							  isFilesTruncated: commit
							  amongPaginated: paginated);
					 at: 'files' put: (commit diffs asArray collect: [ :diff |
								  self diffEntryOf: diff in: aRunner ]);
					 yourself) ].
	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'mode' put: aRunner mode modeName;
		  at: 'commits' put: commits;
		  yourself
]

{ #category : 'exporting' }
GPHRunExporter >> exportRun: aRunner [
	"Write every JSON file of the run in its output directory. Works on partial runs (failure, timeout, stop)."

	aRunner outputDirectory ensureCreateDirectory.
	self write: (self metaOf: aRunner) named: 'meta.json' for: aRunner.
	self
		write: (self timingsOf: aRunner)
		named: 'timings.json'
		for: aRunner.
	self writeApiCallsOf: aRunner.
	self
		write: (self commitsOf: aRunner)
		named: 'commits.json'
		for: aRunner.
	self write: (self diffsOf: aRunner) named: 'diffs.json' for: aRunner.
	self
		write: (self pullRequestsOf: aRunner)
		named: 'prs.json'
		for: aRunner.
	self
		write: (self countsOf: aRunner)
		named: 'counts.json'
		for: aRunner
]

{ #category : 'initialization' }
GPHRunExporter >> initialize [

	super initialize.
	toolRepositoryName := 'GitProjectHealth'
]

{ #category : 'commits' }
GPHRunExporter >> kindOfUser: aUser [
	"GitHub accounts carry their numeric GitHub id. Users synthesized by GitLocalModelImporter>>#importUserByCommit: carry the git author name as id; users faked by GithubModelImporter>>#importUserByUsername: after a 404 carry no id."

	^ aUser id isInteger
		  ifTrue: [ 'github-account' ]
		  ifFalse: [ 'synthetic-local' ]
]

{ #category : 'meta' }
GPHRunExporter >> measuredEndOf: aRunner [
	"End of the last measured top-level step."

	^ (aRunner timings select: [ :timing | timing isTopLevelMeasure ])
		  ifEmpty: [ nil ]
		  ifNotEmpty: [ :measured | measured last endedAt ]
]

{ #category : 'meta' }
GPHRunExporter >> metaOf: aRunner [

	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'mode' put: aRunner mode modeName;
		  at: 'config' put: aRunner config asDictionary;
		  at: 'tokenSource' put: aRunner tokenProvider source;
		  at: 'stateAtExport' put: aRunner stateAtExport;
		  at: 'startedAt' put: (GPHTime iso: aRunner startedAt);
		  at: 'measuredEndedAt'
		  put: (GPHTime iso: (self measuredEndOf: aRunner));
		  at: 'exportedAt' put: (GPHTime iso: aRunner clock now);
		  at: 'error' put: aRunner errorDictionary;
		  at: 'rateLimited' put: aRunner recorder isRateLimited;
		  at: 'anomaly' put: aRunner recorder hasUnexpectedErrors;
		  at: 'pharoVersion' put: SystemVersion current printString;
		  at: 'vmVersion' put: Smalltalk vm version;
		  at: 'osSubtype' put: Smalltalk os subtype;
		  at: 'toolRepository' put: self toolRepositoryInfo;
		  at: 'toolPatches' put: self class toolPatches;
		  at: 'diffStrategy' put: aRunner config diffStrategy;
		  at: 'rateLimitGate'
		  put: (aRunner gateCheck ifNotNil: [ :check | check asDictionary ]);
		  at: 'clone' put: (aRunner mode cloneMetadataFor: aRunner);
		  at: 'finalizationErrors' put: aRunner finalizationErrors;
		  yourself
]

{ #category : 'counts' }
GPHRunExporter >> modelCountsOf: aModel [
	"Counts of allWithType: per entity class; empty when the run failed before building the model."

	| counts |
	counts := OrderedDictionary new.
	aModel ifNil: [ ^ counts ].
	self class countedEntityClasses do: [ :entityClass |
			counts
				at: entityClass name
				put: (aModel allWithType: entityClass) size ].
	^ counts
]

{ #category : 'pull requests' }
GPHRunExporter >> pullRequestEntryOf: aPullRequest in: aRunner [

	^ OrderedDictionary new
		  at: 'number' put: aPullRequest iid;
		  at: 'id' put: aPullRequest id;
		  at: 'created_at' put: (GPHTime iso: aPullRequest created_at);
		  at: 'state' put: aPullRequest state;
		  at: 'merged_at' put: (GPHTime iso: aPullRequest merged_at);
		  at: 'merge_commit_sha' put: aPullRequest merge_commit_sha;
		  at: 'head_sha' put: aPullRequest sha;
		  at: 'merge_commit_resolution'
		  put: (aRunner resolutionOf: aPullRequest);
		  at: 'head_resolvable_locally'
		  put: (aRunner mode headResolvableOf: aPullRequest in: aRunner);
		  yourself
]

{ #category : 'pull requests' }
GPHRunExporter >> pullRequestsOf: aRunner [

	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'mode' put: aRunner mode modeName;
		  at: 'pullRequests'
		  put: ((aRunner pullRequests asArray sorted: [ :a :b |
					    (a iid ifNil: [ 0 ]) <= (b iid ifNil: [ 0 ]) ]) collect: [
					   :pullRequest |
					   self pullRequestEntryOf: pullRequest in: aRunner ]);
		  yourself
]

{ #category : 'counts' }
GPHRunExporter >> resolutionHistogramOf: aRunner [

	| histogram |
	histogram := OrderedDictionary new.
	self class resolutionCategories do: [ :category |
		histogram at: category put: 0 ].
	aRunner pullRequests do: [ :pullRequest |
			(aRunner resolutionOf: pullRequest) ifNotNil: [ :category |
					histogram
						at: category
						put: (histogram at: category ifAbsent: [ 0 ]) + 1 ] ].
	^ histogram
]

{ #category : 'commits' }
GPHRunExporter >> resolvedUserOf: aCommit [

	^ aCommit commitCreator
		  ifNil: [ self userEntryKind: 'none' id: nil username: nil ]
		  ifNotNil: [ :user |
				  self
					  userEntryKind: (self kindOfUser: user)
					  id: user id
					  username: user username ]
]

{ #category : 'commits' }
GPHRunExporter >> sortedWindowCommitsOf: aRunner [

	^ aRunner windowCommits asArray sorted: [ :a :b | a id <= b id ]
]

{ #category : 'timings' }
GPHRunExporter >> timingsOf: aRunner [

	| measured |
	measured := aRunner timings select: [ :timing |
		            timing isTopLevelMeasure ].
	^ OrderedDictionary new
		  at: 'runId' put: aRunner runId;
		  at: 'steps'
		  put:
			  (aRunner timings collect: [ :timing | timing asDictionary ])
				  asArray;
		  at: 'totals' put: (OrderedDictionary new
				   at: 'grossMs'
				   put:
					   (measured
						    inject: 0
						    into: [ :sum :timing | sum + timing durationMs ]);
				   at: 'rateLimitWaitMs' put: (measured
						    inject: 0
						    into: [ :sum :timing | sum + timing rateLimitWaitMs ]);
				   at: 'netMs' put: (measured
						    inject: 0
						    into: [ :sum :timing | sum + timing netDurationMs ]);
				   yourself);
		  yourself
]

{ #category : 'meta' }
GPHRunExporter >> toolRepositoryInfo [
	"HEAD, branch and modification state of the Iceberg repository of the tool. Iceberg failures are reported in the file, not propagated."

	| info |
	info := OrderedDictionary new.
	info at: 'name' put: toolRepositoryName.
	[
		IceRepository registry
			detect: [ :repository | repository name = toolRepositoryName ]
			ifFound: [ :repository |
					info
						at: 'headCommit' put: repository headCommit id;
						at: 'branch' put: repository branchName;
						at: 'isModified' put: repository isModified ]
			ifNone: [ info at: 'error' put: 'not registered in Iceberg' ] ]
		on: Error
		do: [ :error | info at: 'error' put: error class name ].
	^ info
]

{ #category : 'accessing' }
GPHRunExporter >> toolRepositoryName: aString [
	"Name of the Iceberg repository of the measured tool (default GitProjectHealth)."

	toolRepositoryName := aString
]

{ #category : 'commits' }
GPHRunExporter >> userEntryKind: aKind id: anId username: aUsername [

	^ OrderedDictionary new
		  at: 'kind' put: aKind;
		  at: 'id' put: anId;
		  at: 'username' put: aUsername;
		  yourself
]

{ #category : 'private' }
GPHRunExporter >> write: anObject named: aFileName for: aRunner [

	GPHJsonFile
		write: anObject
		to: aRunner outputDirectory / aFileName
		redactor: aRunner tokenProvider
]

{ #category : 'api calls' }
GPHRunExporter >> writeApiCallsOf: aRunner [
	"api-calls.json keeps one call per line so that it can be grepped."

	| recorder text |
	recorder := aRunner recorder.
	text := String streamContents: [ :stream |
			        stream
				        nextPut: ${;
				        lf;
				        nextPutAll: '"calls": [';
				        lf.
			        recorder calls
				        do: [ :call |
					        stream nextPutAll:
						        (NeoJSONWriter toString: call asDictionary) ]
				        separatedBy: [
						        stream
							        nextPut: $,;
							        lf ].
			        stream
				        lf;
				        nextPutAll: '],';
				        lf.
			        self
				        writeMember: 'aggregates'
				        value: recorder aggregates
				        on: stream.
			        stream
				        nextPut: $,;
				        lf.
			        self
				        writeMember: 'rateLimitWaits'
				        value:
					        (recorder rateLimitWaits collect: [ :wait |
						         wait asDictionary ]) asArray
				        on: stream.
			        stream
				        nextPut: $,;
				        lf.
			        self
				        writeMember: 'unexpectedErrors'
				        value:
					        (recorder unexpectedErrors collect: [ :error |
						         error asDictionary ]) asArray
				        on: stream.
			        stream
				        nextPut: $,;
				        lf.
			        self
				        writeMember: 'fallbacks'
				        value:
					        (aRunner fallbacks collect: [ :fallback |
						         fallback asDictionary ]) asArray
				        on: stream.
			        stream
				        lf;
				        nextPut: $};
				        lf ].
	GPHJsonFile
		writeString: (aRunner tokenProvider redact: text)
		to: aRunner outputDirectory / 'api-calls.json'
]

{ #category : 'api calls' }
GPHRunExporter >> writeMember: aKey value: anObject on: aStream [

	aStream
		nextPutAll: (NeoJSONWriter toString: aKey);
		nextPutAll: ': ';
		nextPutAll: (NeoJSONWriter toStringPretty: anObject)
]
