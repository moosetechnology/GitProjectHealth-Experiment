"
I read the JSON exports of a D run and an H run and write consistency.json: commit sets, diffs, authors and pull requests.

	GPHRunComparator new compare: dirD with: dirH into: dirOut
"
Class {
	#name : 'GPHRunComparator',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Compare',
	#package : 'GPHExperiment-Harness',
	#tag : 'Compare'
}

{ #category : 'private' }
GPHRunComparator >> add: aNumber to: aKey in: aReport [

	aReport at: aKey put: (aReport at: aKey ifAbsent: [ 0 ]) + aNumber
]

{ #category : 'diffs' }
GPHRunComparator >> addPathMismatchOf: aSha byPathD: byPathD byPathH: byPathH into: aReport [

	self increment: 'commitsWithPathMismatch' in: aReport.
	(aReport at: 'pathMismatches') add: (OrderedDictionary new
			 at: 'sha' put: aSha;
			 at: 'onlyD' put: (self keysOf: byPathD missingFrom: byPathH);
			 at: 'onlyH' put: (self keysOf: byPathH missingFrom: byPathD);
			 yourself)
]

{ #category : 'authors' }
GPHRunComparator >> authorConsistencyOf: someShas commitsD: commitsD commitsH: commitsH [
	"On the intersection: author_name_git and author_email equality, committed_date gaps, matrix of resolved_user kinds; distinct users over each whole run."

	| nameMismatches emailMismatches dateMismatches kindMatrix maxDelta |
	nameMismatches := OrderedCollection new.
	emailMismatches := OrderedCollection new.
	dateMismatches := OrderedCollection new.
	kindMatrix := OrderedDictionary new.
	maxDelta := 0.
	someShas do: [ :sha |
			| commitD commitH delta |
			commitD := commitsD at: sha.
			commitH := commitsH at: sha.
			(self field: 'author_name_git' differsIn: commitD and: commitH)
				ifTrue: [
						nameMismatches add: (self
								 mismatchOf: sha
								 field: 'author_name_git'
								 d: commitD
								 h: commitH) ].
			(self field: 'author_email' differsIn: commitD and: commitH)
				ifTrue: [
						emailMismatches add: (self
								 mismatchOf: sha
								 field: 'author_email'
								 d: commitD
								 h: commitH) ].
			delta := self committedDateDeltaOf: commitD and: commitH.
			delta > 0 ifTrue: [
					dateMismatches add: ((self
							  mismatchOf: sha
							  field: 'committed_date'
							  d: commitD
							  h: commitH)
							 at: 'deltaSeconds' put: delta;
							 yourself) ].
			maxDelta := maxDelta max: delta.
			self
				count: ((commitH at: 'resolved_user') at: 'kind')
				under: ((commitD at: 'resolved_user') at: 'kind')
				in: kindMatrix ].
	^ OrderedDictionary new
		  at: 'compared' put: someShas size;
		  at: 'authorNameGitEqual' put: someShas size - nameMismatches size;
		  at: 'authorNameGitMismatches' put: nameMismatches;
		  at: 'authorEmailEqual' put: someShas size - emailMismatches size;
		  at: 'authorEmailMismatches' put: emailMismatches;
		  at: 'committedDateMaxDeltaSeconds' put: maxDelta;
		  at: 'committedDateMismatches' put: dateMismatches;
		  at: 'resolvedUserKindMatrixDtoH' put: kindMatrix;
		  at: 'distinctUsersD' put: (self distinctUsersOf: commitsD);
		  at: 'distinctUsersH' put: (self distinctUsersOf: commitsH);
		  yourself
]

{ #category : 'commits' }
GPHRunComparator >> commitSetsOf: commitsD and: commitsH since: since until: until [
	"Sha sets; branches of the H-only shas; discrepant shas dated less than the near-boundary margin (10 % of the window, at most 24 h) from a bound."

	| onlyD onlyH |
	onlyD := self keysOf: commitsD missingFrom: commitsH.
	onlyH := self keysOf: commitsH missingFrom: commitsD.
	^ OrderedDictionary new
		  at: 'countD' put: commitsD size;
		  at: 'countH' put: commitsH size;
		  at: 'intersection'
		  put: (self sharedKeysOf: commitsD and: commitsH) size;
		  at: 'onlyD' put: onlyD;
		  at: 'onlyH' put: onlyH;
		  at: 'onlyHBranches' put: (onlyH collect: [ :sha |
						   OrderedDictionary new
							   at: 'sha' put: sha;
							   at: 'branches' put: ((commitsH at: sha) at: 'branches');
							   yourself ]);
		  at: 'nearBoundaryMarginSeconds'
		  put: (self nearBoundaryMarginSince: since until: until);
		  at: 'nearBoundary' put: (Array streamContents: [ :stream |
				   self
					   nearBoundary: onlyD
					   side: 'D'
					   of: commitsD
					   since: since
					   until: until
					   on: stream.
				   self
					   nearBoundary: onlyH
					   side: 'H'
					   of: commitsH
					   since: since
					   until: until
					   on: stream ]);
		  yourself
]

{ #category : 'authors' }
GPHRunComparator >> committedDateDeltaOf: anEntryD and: anEntryH [
	"Absolute gap in seconds; 0 when a date is missing."

	| dateD dateH |
	dateD := GPHTime parse: (anEntryD at: 'committed_date').
	dateH := GPHTime parse: (anEntryH at: 'committed_date').
	(dateD isNil or: [ dateH isNil ]) ifTrue: [ ^ 0 ].
	^ (dateD - dateH) asSeconds abs
]

{ #category : 'comparing' }
GPHRunComparator >> compare: aDirectoryD with: aDirectoryH into: anOutputDirectory [
	"Read the exports of a D run and an H run, write consistency.json in anOutputDirectory and answer the report."

	| report |
	report := self
		          consistencyOf: (self loadRun: aDirectoryD)
		          with: (self loadRun: aDirectoryH).
	GPHJsonFile write: report to: anOutputDirectory / 'consistency.json'.
	^ report
]

{ #category : 'diffs' }
GPHRunComparator >> compareCountsOf: aSha byPathD: byPathD byPathH: byPathH into: aReport [
	"Compare additions and deletions on the paths shared by both sides; answer the paths whose counts differ."

	| sharedPaths mismatches |
	sharedPaths := self sharedKeysOf: byPathD and: byPathH.
	self add: sharedPaths size to: 'comparedFiles' in: aReport.
	mismatches := sharedPaths reject: [ :path |
		              self
			              sameCountsOf: (byPathD at: path)
			              and: (byPathH at: path) ].
	mismatches ifNotEmpty: [
		self increment: 'commitsWithCountMismatch' in: aReport ].
	mismatches do: [ :path |
			(aReport at: 'countMismatches') add: (OrderedDictionary new
					 at: 'sha' put: aSha;
					 at: 'path' put: path;
					 at: 'additionsD' put: ((byPathD at: path) at: 'additions');
					 at: 'deletionsD' put: ((byPathD at: path) at: 'deletions');
					 at: 'additionsH' put: ((byPathH at: path) at: 'additions');
					 at: 'deletionsH' put: ((byPathH at: path) at: 'deletions');
					 yourself) ].
	^ mismatches
]

{ #category : 'diffs' }
GPHRunComparator >> compareDiffsOf: aSha parents: aParentsCount entryD: anEntryD entryH: anEntryH into: aReport [

	aParentsCount = 0 ifTrue: [
		^ self increment: 'rootCommits' in: aReport ].
	aParentsCount > 1 ifTrue: [
		^ self increment: 'mergeCommits' in: aReport ].
	(anEntryD isNil or: [ anEntryH isNil ]) ifTrue: [
		^ self increment: 'missingDiffEntries' in: aReport ].
	((anEntryD at: 'files_truncated') or: [
		 anEntryH at: 'files_truncated' ]) ifTrue: [
		^ self increment: 'truncatedCommits' in: aReport ].
	self
		compareFilesOf: aSha
		filesD: (anEntryD at: 'files')
		filesH: (anEntryH at: 'files')
		into: aReport
]

{ #category : 'diffs' }
GPHRunComparator >> compareFilesOf: aSha filesD: filesD filesH: filesH into: aReport [
	"Files are keyed by pathKeyOf: (new_path, else old_path). A path is excluded when either side has no patch or a binary patch. A path set difference is recorded, then counts are compared on the path intersection. A commit is identical only when both path sets are equal and no count differs."

	| absentPaths binaryPaths excluded byPathD byPathH samePaths mismatches |
	self
		countPathFallbacksOf: filesD
		to: 'pathFallbackCountD'
		in: aReport.
	self
		countPathFallbacksOf: filesH
		to: 'pathFallbackCountH'
		in: aReport.
	absentPaths := filesD , filesH
		               select: [ :file | (file at: 'patch_present') not ]
		               thenCollect: [ :file | self pathKeyOf: file ].
	binaryPaths := filesD , filesH
		               select: [ :file | file at: 'binary' ]
		               thenCollect: [ :file | self pathKeyOf: file ].
	excluded := absentPaths asSet , binaryPaths asSet.
	self
		add: absentPaths asSet size
		to: 'excludedFilesPatchAbsent'
		in: aReport.
	self
		add: binaryPaths asSet size
		to: 'excludedFilesBinary'
		in: aReport.
	byPathD := self filesByPath: filesD excluding: excluded.
	byPathH := self filesByPath: filesH excluding: excluded.
	self increment: 'comparedCommits' in: aReport.
	samePaths := byPathD keys asSet = byPathH keys asSet.
	samePaths ifFalse: [
			self
				addPathMismatchOf: aSha
				byPathD: byPathD
				byPathH: byPathH
				into: aReport ].
	mismatches := self
		              compareCountsOf: aSha
		              byPathD: byPathD
		              byPathH: byPathH
		              into: aReport.
	(samePaths and: [ mismatches isEmpty ]) ifTrue: [
		self increment: 'identicalCommits' in: aReport ]
]

{ #category : 'comparing' }
GPHRunComparator >> consistencyOf: aRunD with: aRunH [

	| commitsD commitsH shared config since until |
	commitsD := aRunD at: 'commits'.
	commitsH := aRunH at: 'commits'.
	shared := self sharedKeysOf: commitsD and: commitsH.
	config := (aRunD at: 'meta') at: 'config'.
	since := GPHTime parse: (config at: 'since').
	until := GPHTime parse: (config at: 'until').
	^ OrderedDictionary new
		  at: 'runD' put: ((aRunD at: 'meta') at: 'runId');
		  at: 'runH' put: ((aRunH at: 'meta') at: 'runId');
		  at: 'window' put: (OrderedDictionary new
				   at: 'since' put: (config at: 'since');
				   at: 'until' put: (config at: 'until');
				   yourself);
		  at: 'commits' put: (self
			   commitSetsOf: commitsD
			   and: commitsH
			   since: since
			   until: until);
		  at: 'diffs' put: (self
			   diffConsistencyOf: shared
			   commits: commitsD
			   diffsD: (aRunD at: 'diffs')
			   diffsH: (aRunH at: 'diffs'));
		  at: 'authors' put: (self
			   authorConsistencyOf: shared
			   commitsD: commitsD
			   commitsH: commitsH);
		  at: 'pullRequests' put: (self
			   pullRequestConsistencyOf: (aRunD at: 'prs')
			   and: (aRunH at: 'prs'));
		  yourself
]

{ #category : 'private' }
GPHRunComparator >> count: aColumnKey under: aRowKey in: aMatrix [

	| row |
	row := aMatrix
		       at: (self labelOf: aRowKey)
		       ifAbsentPut: [ OrderedDictionary new ].
	self add: 1 to: (self labelOf: aColumnKey) in: row
]

{ #category : 'diffs' }
GPHRunComparator >> countPathFallbacksOf: someFiles to: aKey in: aReport [
	"Count the files whose path key falls back on old_path."

	self
		add: (someFiles count: [ :file | (file at: 'new_path') isNil ])
		to: aKey
		in: aReport
]

{ #category : 'private' }
GPHRunComparator >> dayInSeconds [

	^ 24 * 3600
]

{ #category : 'diffs' }
GPHRunComparator >> diffConsistencyOf: someShas commits: commitsD diffsD: diffsD diffsH: diffsH [
	"On the intersection: commits with one parent are compared file by file; merge (> 1 parent) and root (0 parent) commits are counted apart, as well as truncated commits and excluded files."

	| report |
	report := self newDiffReport.
	someShas do: [ :sha |
			self
				compareDiffsOf: sha
				parents: ((commitsD at: sha) at: 'parents_count')
				entryD: (diffsD at: sha ifAbsent: [ nil ])
				entryH: (diffsH at: sha ifAbsent: [ nil ])
				into: report ].
	^ report
]

{ #category : 'authors' }
GPHRunComparator >> distinctUsersOf: someCommits [
	"Distinct resolved usernames over all the commits of a run (kind none excluded)."

	^ (someCommits values
		   select: [ :commit |
		   ((commit at: 'resolved_user') at: 'kind') ~= 'none' ]
		   thenCollect: [ :commit |
		   (commit at: 'resolved_user') at: 'username' ]) asSet size
]

{ #category : 'authors' }
GPHRunComparator >> field: aKey differsIn: anEntry and: anotherEntry [

	^ (anEntry at: aKey) ~= (anotherEntry at: aKey)
]

{ #category : 'diffs' }
GPHRunComparator >> filesByPath: someFiles excluding: excludedPaths [

	| byPath |
	byPath := Dictionary new.
	someFiles
		reject: [ :file | excludedPaths includes: (self pathKeyOf: file) ]
		thenDo: [ :file | byPath at: (self pathKeyOf: file) put: file ].
	^ byPath
]

{ #category : 'private' }
GPHRunComparator >> histogramOf: someEntries key: aKey [

	| histogram |
	histogram := OrderedDictionary new.
	someEntries do: [ :entry |
		self add: 1 to: (self labelOf: (entry at: aKey)) in: histogram ].
	^ histogram
]

{ #category : 'private' }
GPHRunComparator >> increment: aKey in: aReport [

	self add: 1 to: aKey in: aReport
]

{ #category : 'loading' }
GPHRunComparator >> index: someEntries by: aKey [

	| index |
	index := Dictionary new.
	someEntries do: [ :entry | index at: (entry at: aKey) put: entry ].
	^ index
]

{ #category : 'private' }
GPHRunComparator >> keysOf: anIndex missingFrom: anotherIndex [

	^ (anIndex keys reject: [ :key | anotherIndex includesKey: key ])
		  sorted
]

{ #category : 'private' }
GPHRunComparator >> labelOf: aJsonValue [
	"JSON object keys must be strings."

	^ aJsonValue ifNil: [ 'null' ] ifNotNil: [ :value | value asString ]
]

{ #category : 'loading' }
GPHRunComparator >> loadRun: aDirectory [
	"Answer the parsed exports of a run: meta, commits by sha, diffs by sha, pull requests by number."

	^ Dictionary new
		  at: 'meta' put: (GPHJsonFile read: aDirectory / 'meta.json');
		  at: 'commits' put: (self
				   index:
					   ((GPHJsonFile read: aDirectory / 'commits.json') at: 'commits')
				   by: 'sha');
		  at: 'diffs'
		  put: ((GPHJsonFile read: aDirectory / 'diffs.json') at: 'commits');
		  at: 'prs' put: (self
				   index:
					   ((GPHJsonFile read: aDirectory / 'prs.json') at:
							    'pullRequests')
				   by: 'number');
		  yourself
]

{ #category : 'authors' }
GPHRunComparator >> mismatchOf: aSha field: aKey d: anEntryD h: anEntryH [

	^ OrderedDictionary new
		  at: 'sha' put: aSha;
		  at: 'D' put: (anEntryD at: aKey);
		  at: 'H' put: (anEntryH at: aKey);
		  yourself
]

{ #category : 'commits' }
GPHRunComparator >> nearBoundary: someShas side: aSide of: someCommits since: since until: until on: aStream [

	| margin |
	margin := self nearBoundaryMarginSince: since until: until.
	someShas do: [ :sha |
			| dateString date fromSince fromUntil |
			dateString := (someCommits at: sha) at: 'committed_date'.
			date := GPHTime parse: dateString.
			date ifNotNil: [
					fromSince := (date - since) asSeconds.
					fromUntil := (date - until) asSeconds.
					(fromSince abs < margin or: [ fromUntil abs < margin ]) ifTrue: [
							aStream nextPut: (OrderedDictionary new
									 at: 'sha' put: sha;
									 at: 'side' put: aSide;
									 at: 'committed_date' put: dateString;
									 at: 'secondsFromSince' put: fromSince;
									 at: 'secondsFromUntil' put: fromUntil;
									 yourself) ] ] ]
]

{ #category : 'commits' }
GPHRunComparator >> nearBoundaryMarginSince: since until: until [
	"Seconds within which a discrepant sha is reported as near a window bound: 10 % of the window, capped at one day."

	^ (until - since) asSeconds // 10 min: self dayInSeconds
]

{ #category : 'diffs' }
GPHRunComparator >> newDiffReport [

	^ OrderedDictionary new
		  at: 'pathKeyRule' put: self pathKeyRule;
		  at: 'pathFallbackCountD' put: 0;
		  at: 'pathFallbackCountH' put: 0;
		  at: 'comparedCommits' put: 0;
		  at: 'comparedFiles' put: 0;
		  at: 'identicalCommits' put: 0;
		  at: 'commitsWithPathMismatch' put: 0;
		  at: 'commitsWithCountMismatch' put: 0;
		  at: 'mergeCommits' put: 0;
		  at: 'rootCommits' put: 0;
		  at: 'truncatedCommits' put: 0;
		  at: 'missingDiffEntries' put: 0;
		  at: 'excludedFilesPatchAbsent' put: 0;
		  at: 'excludedFilesBinary' put: 0;
		  at: 'pathMismatches' put: OrderedCollection new;
		  at: 'countMismatches' put: OrderedCollection new;
		  yourself
]

{ #category : 'diffs' }
GPHRunComparator >> pathKeyOf: aFile [
	"The comparison key of a diffs.json file: new_path, else old_path. In D mode the importer leaves new_path nil and keeps the current GitHub filename in old_path."

	^ (aFile at: 'new_path') ifNil: [ aFile at: 'old_path' ]
]

{ #category : 'diffs' }
GPHRunComparator >> pathKeyRule [
	"Recorded in consistency.json; see pathKeyOf:."

	^ 'new_path, else old_path'
]

{ #category : 'pull requests' }
GPHRunComparator >> pullRequestConsistencyOf: prsD and: prsH [

	| shared resolutionPairs shaMismatches |
	shared := self sharedKeysOf: prsD and: prsH.
	resolutionPairs := OrderedDictionary new.
	shaMismatches := OrderedCollection new.
	shared do: [ :number |
			| prD prH |
			prD := prsD at: number.
			prH := prsH at: number.
			self
				count: (prH at: 'merge_commit_resolution')
				under: (prD at: 'merge_commit_resolution')
				in: resolutionPairs.
			(self field: 'merge_commit_sha' differsIn: prD and: prH) ifTrue: [
					shaMismatches add: (self
							 mismatchOf: number
							 field: 'merge_commit_sha'
							 d: prD
							 h: prH) ] ].
	^ OrderedDictionary new
		  at: 'countD' put: prsD size;
		  at: 'countH' put: prsH size;
		  at: 'sameNumbers' put: prsD keys asSet = prsH keys asSet;
		  at: 'onlyD' put: (self keysOf: prsD missingFrom: prsH);
		  at: 'onlyH' put: (self keysOf: prsH missingFrom: prsD);
		  at: 'resolutionsD'
		  put:
			  (self histogramOf: prsD values key: 'merge_commit_resolution');
		  at: 'resolutionsH'
		  put:
			  (self histogramOf: prsH values key: 'merge_commit_resolution');
		  at: 'resolutionPairsDtoH' put: resolutionPairs;
		  at: 'mergeCommitShaMismatches' put: shaMismatches;
		  at: 'headResolvableLocallyH'
		  put:
			  (self histogramOf: prsH values key: 'head_resolvable_locally');
		  yourself
]

{ #category : 'diffs' }
GPHRunComparator >> sameCountsOf: aFileD and: aFileH [

	^ (aFileD at: 'additions') = (aFileH at: 'additions') and: [
		  (aFileD at: 'deletions') = (aFileH at: 'deletions') ]
]

{ #category : 'private' }
GPHRunComparator >> sharedKeysOf: anIndex and: anotherIndex [

	^ (anIndex keys select: [ :key | anotherIndex includesKey: key ])
		  sorted
]
