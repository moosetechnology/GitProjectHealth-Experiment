"
Export of a hand-built mode D run into a memory file system: 2 commits in the window [2026-01-01, 2026-02-01) and 1 just before it, diffs with and without patch, one GitHub account (integer id), one synthetic local user, one merged pull request.
"
Class {
	#name : 'GPHRunExporterTest',
	#superclass : 'TestCase',
	#instVars : [
		'runner',
		'outputDirectory',
		'model'
	],
	#category : 'GPHExperiment-Harness-Tests-Export',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Export'
}

{ #category : 'helpers' }
GPHRunExporterTest >> commit: aSha at: anIsoString creator: aUser diff: aDiff [

	| commit |
	commit := GLHCommit new
		          id: aSha;
		          committed_date: anIsoString asDateAndTime;
		          authored_date: anIsoString asDateAndTime;
		          author_email: aUser username asLowercase , '@example.org';
		          author_name: aUser username;
		          parent_ids:
			          #( '2222222222222222222222222222222222222222' );
		          commitCreator: aUser;
		          yourself.
	commit diffs add: aDiff.
	^ commit
]

{ #category : 'helpers' }
GPHRunExporterTest >> isUtcIso: aString [
	"YYYY-MM-DDTHH:MM:SSZ, no fraction, no offset."

	^ aString notNil and: [
		  aString matchesRegex: '\d\d\d\d-\d\d-\d\dT\d\d\:\d\d\:\d\dZ' ]
]

{ #category : 'helpers' }
GPHRunExporterTest >> read: aFileName [

	^ GPHJsonFile read: outputDirectory / aFileName
]

{ #category : 'running' }
GPHRunExporterTest >> setUp [

	| account synthetic inWindow1 inWindow2 outOfWindow project pullRequest |
	super setUp.
	model := GLHModel new.
	account := GLHUser new
		           id: 583231;
		           username: 'alice';
		           yourself.
	synthetic := GLHUser new
		             id: 'Bob Local';
		             username: 'Bob Local';
		             yourself.
	inWindow1 := self
		             commit: self shaA
		             at: '2026-01-10T12:00:00+02:00'
		             creator: account
		             diff: (GLHDiff new
				              old_path: 'x';
				              new_path: 'x';
				              diffString:
					              (String lf join:
							               #( '@@ -1,2 +1,3 @@' ' a' '-b' '+c' '+d' ));
				              yourself).
	inWindow1 cacheAt: #gitAuthorName put: 'Alice Git'.
	inWindow2 := self
		             commit: self shaB
		             at: '2026-01-20T08:00:00Z'
		             creator: synthetic
		             diff: (GLHDiff new
				              old_path: 'img.png';
				              new_path: 'img.png';
				              diffString: nil;
				              yourself).
	outOfWindow := self
		               commit: self shaC
		               at: '2025-12-31T23:00:00Z'
		               creator: account
		               diff: (GLHDiff new
				                old_path: 'y';
				                new_path: 'y';
				                diffString: '@@ -0,0 +1 @@' , String lf , '+y';
				                yourself).
	project := GLHProject new
		           name: 'r';
		           repository: GLHRepository new;
		           yourself.
	{
		inWindow1.
		inWindow2.
		outOfWindow } do: [ :commit |
			project repository commits add: commit.
			model add: commit.
			commit diffs do: [ :diff | model add: diff ] ].
	model
		add: account;
		add: synthetic;
		add: project;
		add: project repository.
	pullRequest := GLHMergeRequest new
		               iid: 7;
		               id: 1007;
		               state: 'merged';
		               created_at: '2026-01-15T09:00:00+01:00' asDateAndTime;
		               merged_at: '2026-01-20T08:00:00Z' asDateAndTime;
		               merge_commit_sha: self shaB;
		               sha: '1111111111111111111111111111111111111111';
		               yourself.
	model add: pullRequest.
	runner := GPHRunner on: ((GPHRunConfig
			            repo: 'o/r'
			            mode: #D
			            since: '2026-01-01T00:00:00Z'
			            until: '2026-02-01T00:00:00Z')
			           runId: 'export-run';
			           outputRoot: FileSystem memory root / 'out';
			           apiBaseUrl: 'http://localhost:9';
			           yourself).
	runner
		clock: GPHFakeClock new;
		tokenProvider:
			(GPHTokenProvider token: 'SECRET-EXPORT' source: 'iceberg');
		project: project;
		importers: (GPHImporterSet new
				 model: model;
				 yourself);
		pullRequests: { pullRequest };
		freezeWindowCommits;
		collectWindowAuthors.
	outputDirectory := runner outputDirectory.
	GPHRunExporter new exportRun: runner
]

{ #category : 'helpers' }
GPHRunExporterTest >> shaA [

	^ 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
]

{ #category : 'helpers' }
GPHRunExporterTest >> shaB [

	^ 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
]

{ #category : 'helpers' }
GPHRunExporterTest >> shaC [

	^ 'cccccccccccccccccccccccccccccccccccccccc'
]

{ #category : 'tests' }
GPHRunExporterTest >> testAllSevenFilesAreWritten [

	#( 'meta' 'timings' 'api-calls' 'commits' 'diffs' 'prs' 'counts' )
		do: [ :name |
				self
					assert: (outputDirectory / (name , '.json')) exists
					description: name , '.json missing'.
				self shouldnt: [ self read: name , '.json' ] raise: Error ]
]

{ #category : 'tests' }
GPHRunExporterTest >> testCommitsAreThoseOfTheWindowOnly [

	| commits |
	commits := (self read: 'commits.json') at: 'commits'.
	self
		assert: (commits collect: [ :each | each at: 'sha' ]) asArray
		equals: {
				self shaA.
				self shaB }.
	self
		assert: ((self read: 'diffs.json') at: 'commits') keys asSet
		equals: {
				self shaA.
				self shaB } asSet.
	self
		assert: (((self read: 'counts.json') at: 'window') at: 'commits')
		equals: 2.
	self
		assert: (((self read: 'counts.json') at: 'model') at: 'GLHCommit')
		equals: 3
]

{ #category : 'tests' }
GPHRunExporterTest >> testDatesAreUtcZ [

	| commitsFile first pullRequest |
	commitsFile := self read: 'commits.json'.
	self assert: (commitsFile at: 'since') equals: '2026-01-01T00:00:00Z'.
	self assert: (commitsFile at: 'until') equals: '2026-02-01T00:00:00Z'.
	first := (commitsFile at: 'commits') first.
	self
		assert: (first at: 'committed_date')
		equals: '2026-01-10T10:00:00Z'.
	(commitsFile at: 'commits') do: [ :each |
			self assert: (self isUtcIso: (each at: 'committed_date')).
			self assert: (self isUtcIso: (each at: 'authored_date')) ].
	pullRequest := ((self read: 'prs.json') at: 'pullRequests') first.
	self
		assert: (pullRequest at: 'created_at')
		equals: '2026-01-15T08:00:00Z'.
	self assert: (self isUtcIso: (pullRequest at: 'merged_at'))
]

{ #category : 'tests' }
GPHRunExporterTest >> testDiffStatistics [

	| commits patched missing |
	commits := (self read: 'diffs.json') at: 'commits'.
	patched := ((commits at: self shaA) at: 'files') first.
	self assert: (patched at: 'additions') equals: 2.
	self assert: (patched at: 'deletions') equals: 1.
	self assert: (patched at: 'patch_present').
	missing := ((commits at: self shaB) at: 'files') first.
	self deny: (missing at: 'patch_present').
	self deny: ((commits at: self shaA) at: 'files_truncated')
]

{ #category : 'tests' }
GPHRunExporterTest >> testMetaHasTokenSourceButNoToken [

	| meta |
	meta := self read: 'meta.json'.
	self assert: (meta at: 'tokenSource') equals: 'iceberg'.
	self assert: (meta at: 'runId') equals: 'export-run'.
	outputDirectory allFiles do: [ :file |
			self
				deny: (file contents includesSubstring: 'SECRET-EXPORT')
				description: file basename , ' contains the token' ]
]

{ #category : 'tests' }
GPHRunExporterTest >> testPullRequests [

	| pullRequests |
	pullRequests := (self read: 'prs.json') at: 'pullRequests'.
	self assert: pullRequests size equals: 1.
	self assert: (pullRequests first at: 'number') equals: 7.
	self
		assert: (pullRequests first at: 'merge_commit_sha')
		equals: self shaB.
	self
		assert:
		(((self read: 'counts.json') at: 'window') at: 'pullRequests')
		equals: 1
]

{ #category : 'tests' }
GPHRunExporterTest >> testResolvedUserKinds [

	| commits |
	commits := (self read: 'commits.json') at: 'commits'.
	self
		assert: ((commits first at: 'resolved_user') at: 'kind')
		equals: 'github-account'.
	self
		assert: ((commits first at: 'resolved_user') at: 'id')
		equals: 583231.
	self
		assert: ((commits second at: 'resolved_user') at: 'kind')
		equals: 'synthetic-local'.
	self
		assert: (commits first at: 'author_name_git')
		equals: 'Alice Git'.
	self assert: (commits first at: 'author_login') equals: 'alice'
]
