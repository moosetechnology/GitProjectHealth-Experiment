"
Comparison of two synthetic exports (D and H) written by hand in a memory file system. Window [2026-01-01, 2026-02-01). Shared shas s1..s5: s1 identical diffs, s2 merge commit, s3 root commit, s4 different counts and a different author_name_git, s5 a path only in H and a different author_email. d1 only in D (5 h after since), h1 only in H (mid-window), h2 only in H (4 h before until). Pull requests 1, 2, 3 on both sides with different resolutions for #1.
"
Class {
	#name : 'GPHRunComparatorTest',
	#superclass : 'TestCase',
	#instVars : [
		'fileSystem',
		'report'
	],
	#category : 'GPHExperiment-Harness-Tests-Compare',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Compare'
}

{ #category : 'helpers' }
GPHRunComparatorTest >> commit: aSha date: anIsoString parents: aCount name: aName email: anEmail kind: aKind [

	^ OrderedDictionary new
		  at: 'sha' put: aSha;
		  at: 'author_name_git' put: aName;
		  at: 'author_email' put: anEmail;
		  at: 'committed_date' put: anIsoString;
		  at: 'parents_count' put: aCount;
		  at: 'branches' put: #( 'main' );
		  at: 'resolved_user' put: (OrderedDictionary new
				   at: 'kind' put: aKind;
				   at: 'id' put: nil;
				   at: 'username' put: aName;
				   yourself);
		  yourself
]

{ #category : 'helpers' }
GPHRunComparatorTest >> files: somePathAdditionsDeletions [
	"An array of { path. additions. deletions } triples as a diffs.json entry."

	^ OrderedDictionary new
		  at: 'files_truncated' put: false;
		  at: 'files'
		  put: (somePathAdditionsDeletions collect: [ :triple |
						   OrderedDictionary new
							   at: 'old_path' put: triple first;
							   at: 'new_path' put: triple first;
							   at: 'additions' put: triple second;
							   at: 'deletions' put: triple third;
							   at: 'patch_present' put: true;
							   at: 'binary' put: false;
							   yourself ]);
		  yourself
]

{ #category : 'helpers' }
GPHRunComparatorTest >> pullRequest: aNumber resolution: aResolution [

	^ OrderedDictionary new
		  at: 'number' put: aNumber;
		  at: 'merge_commit_sha' put: 'm' , aNumber printString;
		  at: 'merge_commit_resolution' put: aResolution;
		  at: 'head_resolvable_locally' put: true;
		  yourself
]

{ #category : 'running' }
GPHRunComparatorTest >> setUp [

	| directoryD directoryH |
	super setUp.
	fileSystem := FileSystem memory.
	directoryD := self
		              write: 'run-D'
		              commits: {
				              (self
					               commit: 's1'
					               date: '2026-01-10T00:00:00Z'
					               parents: 1
					               name: 'Alice'
					               email: 'alice@x.org'
					               kind: 'github-account').
				              (self
					               commit: 's2'
					               date: '2026-01-11T00:00:00Z'
					               parents: 2
					               name: 'Alice'
					               email: 'alice@x.org'
					               kind: 'github-account').
				              (self
					               commit: 's3'
					               date: '2026-01-12T00:00:00Z'
					               parents: 0
					               name: 'Bob'
					               email: 'bob@x.org'
					               kind: 'github-account').
				              (self
					               commit: 's4'
					               date: '2026-01-13T00:00:00Z'
					               parents: 1
					               name: 'Carol'
					               email: 'carol@x.org'
					               kind: 'github-account').
				              (self
					               commit: 's5'
					               date: '2026-01-14T00:00:00Z'
					               parents: 1
					               name: 'Dan'
					               email: 'dan@x.org'
					               kind: 'github-account').
				              (self
					               commit: 'd1'
					               date: '2026-01-01T05:00:00Z'
					               parents: 1
					               name: 'Eve'
					               email: 'eve@x.org'
					               kind: 'github-account') }
		              diffs: (Dictionary new
				               at: 's1' put: (self files: #( #( 'a.txt' 2 1 ) ));
				               at: 's2' put: (self files: #( #( 'm.txt' 1 0 ) ));
				               at: 's3' put: (self files: #( #( 'r.txt' 5 0 ) ));
				               at: 's4' put: (self files: #( #( 'b.txt' 3 1 ) ));
				               at: 's5' put: (self files: #( #( 'c.txt' 1 1 ) ));
				               at: 'd1' put: (self files: #( #( 'e.txt' 1 0 ) ));
				               yourself)
		              prs: {
				              (self pullRequest: 1 resolution: 'api').
				              (self pullRequest: 2 resolution: 'not-merged').
				              (self pullRequest: 3 resolution: 'in-window-model') }.
	directoryH := self
		              write: 'run-H'
		              commits: {
				              (self
					               commit: 's1'
					               date: '2026-01-10T00:00:00Z'
					               parents: 1
					               name: 'Alice'
					               email: 'alice@x.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 's2'
					               date: '2026-01-11T00:00:00Z'
					               parents: 2
					               name: 'Alice'
					               email: 'alice@x.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 's3'
					               date: '2026-01-12T00:00:00Z'
					               parents: 0
					               name: 'Bob'
					               email: 'bob@x.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 's4'
					               date: '2026-01-13T00:00:00Z'
					               parents: 1
					               name: 'carol'
					               email: 'carol@x.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 's5'
					               date: '2026-01-14T00:00:00Z'
					               parents: 1
					               name: 'Dan'
					               email: 'dan@other.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 'h1'
					               date: '2026-01-15T00:00:00Z'
					               parents: 1
					               name: 'Fay'
					               email: 'fay@x.org'
					               kind: 'synthetic-local').
				              (self
					               commit: 'h2'
					               date: '2026-01-31T20:00:00Z'
					               parents: 1
					               name: 'Gus'
					               email: 'gus@x.org'
					               kind: 'synthetic-local') }
		              diffs: (Dictionary new
				               at: 's1' put: (self files: #( #( 'a.txt' 2 1 ) ));
				               at: 's2' put: (self files: #( #( 'm.txt' 9 9 ) ));
				               at: 's3' put: (self files: #( #( 'r.txt' 7 0 ) ));
				               at: 's4' put: (self files: #( #( 'b.txt' 2 1 ) ));
				               at: 's5'
				               put:
					               (self files:
							                #( #( 'c.txt' 1 1 ) #( 'extra.txt' 1 0 ) ));
				               at: 'h1' put: (self files: #( #( 'f.txt' 1 0 ) ));
				               at: 'h2' put: (self files: #( #( 'g.txt' 1 0 ) ));
				               yourself)
		              prs: {
				              (self pullRequest: 1 resolution: 'api-fallback').
				              (self pullRequest: 2 resolution: 'not-merged').
				              (self pullRequest: 3 resolution: 'in-window-model') }.
	report := GPHRunComparator new
		          compare: directoryD
		          with: directoryH
		          into: fileSystem root / 'compare'
]

{ #category : 'tests' }
GPHRunComparatorTest >> testAuthorNameAndEmailEquality [

	| authors |
	authors := report at: 'authors'.
	self assert: (authors at: 'compared') equals: 5.
	self assert: (authors at: 'authorNameGitEqual') equals: 4.
	self
		assert: ((authors at: 'authorNameGitMismatches') collect: [ :each |
				 each at: 'sha' ]) asArray
		equals: #( 's4' ).
	self assert: (authors at: 'authorEmailEqual') equals: 4.
	self
		assert: ((authors at: 'authorEmailMismatches') collect: [ :each |
				 each at: 'sha' ]) asArray
		equals: #( 's5' ).
	self assert: (authors at: 'committedDateMaxDeltaSeconds') equals: 0.
	self
		assert:
			(((authors at: 'resolvedUserKindMatrixDtoH') at: 'github-account')
				 at: 'synthetic-local')
		equals: 5
]

{ #category : 'tests' }
GPHRunComparatorTest >> testCommitSets [

	| commits |
	commits := report at: 'commits'.
	self assert: (commits at: 'countD') equals: 6.
	self assert: (commits at: 'countH') equals: 7.
	self assert: (commits at: 'intersection') equals: 5.
	self assert: (commits at: 'onlyD') asArray equals: #( 'd1' ).
	self assert: (commits at: 'onlyH') asArray equals: #( 'h1' 'h2' ).
	self assert:
		(fileSystem root / 'compare' / 'consistency.json') exists
]

{ #category : 'tests' }
GPHRunComparatorTest >> testCountsAreComparedOnPathIntersection [
	"x1 has a.txt on both sides with different counts, b.txt only in D and c.txt only in H: the path mismatch must not hide the count mismatch of a.txt."

	| commits directoryD directoryH diffs pathMismatch countMismatch |
	commits := { (self
		            commit: 'x1'
		            date: '2026-01-10T00:00:00Z'
		            parents: 1
		            name: 'Alice'
		            email: 'alice@x.org'
		            kind: 'github-account') }.
	directoryD := self
		              write: 'run-intersection-D'
		              commits: commits
		              diffs: (Dictionary new
				               at: 'x1'
				               put:
					               (self files:
							                #( #( 'a.txt' 2 1 ) #( 'b.txt' 1 0 ) ));
				               yourself)
		              prs: #(  ).
	directoryH := self
		              write: 'run-intersection-H'
		              commits: commits
		              diffs: (Dictionary new
				               at: 'x1'
				               put:
					               (self files:
							                #( #( 'a.txt' 3 1 ) #( 'c.txt' 1 1 ) ));
				               yourself)
		              prs: #(  ).
	diffs := (GPHRunComparator new
		          compare: directoryD
		          with: directoryH
		          into: fileSystem root / 'compare-intersection') at:
		         'diffs'.
	self assert: (diffs at: 'pathMismatches') size equals: 1.
	pathMismatch := (diffs at: 'pathMismatches') first.
	self assert: (pathMismatch at: 'sha') equals: 'x1'.
	self assert: (pathMismatch at: 'onlyD') asArray equals: #( 'b.txt' ).
	self assert: (pathMismatch at: 'onlyH') asArray equals: #( 'c.txt' ).
	self assert: (diffs at: 'countMismatches') size equals: 1.
	countMismatch := (diffs at: 'countMismatches') first.
	self assert: (countMismatch at: 'sha') equals: 'x1'.
	self assert: (countMismatch at: 'path') equals: 'a.txt'.
	self assert: (countMismatch at: 'additionsD') equals: 2.
	self assert: (countMismatch at: 'additionsH') equals: 3.
	self assert: (diffs at: 'identicalCommits') equals: 0.
	self assert: (diffs at: 'commitsWithPathMismatch') equals: 1.
	self assert: (diffs at: 'commitsWithCountMismatch') equals: 1.
	self assert: (diffs at: 'comparedFiles') equals: 1
]

{ #category : 'tests' }
GPHRunComparatorTest >> testEqualAndDifferentDiffsAreDetected [

	| diffs mismatch pathMismatch |
	diffs := report at: 'diffs'.
	self assert: (diffs at: 'identicalCommits') equals: 1.
	self assert: (diffs at: 'countMismatches') size equals: 1.
	mismatch := (diffs at: 'countMismatches') first.
	self assert: (mismatch at: 'sha') equals: 's4'.
	self assert: (mismatch at: 'path') equals: 'b.txt'.
	self assert: (mismatch at: 'additionsD') equals: 3.
	self assert: (mismatch at: 'additionsH') equals: 2.
	self assert: (diffs at: 'pathMismatches') size equals: 1.
	pathMismatch := (diffs at: 'pathMismatches') first.
	self assert: (pathMismatch at: 'sha') equals: 's5'.
	self
		assert: (pathMismatch at: 'onlyH') asArray
		equals: #( 'extra.txt' )
]

{ #category : 'tests' }
GPHRunComparatorTest >> testMergeAndRootCommitsAreCountedApart [
	"s2 (2 parents) and s3 (0 parent) have different diffs on purpose: they must not be compared."

	| diffs |
	diffs := report at: 'diffs'.
	self assert: (diffs at: 'mergeCommits') equals: 1.
	self assert: (diffs at: 'rootCommits') equals: 1.
	self assert: (diffs at: 'comparedCommits') equals: 3.
	self deny: ((diffs at: 'countMismatches') anySatisfy: [ :each |
			 #( 's2' 's3' ) includes: (each at: 'sha') ])
]

{ #category : 'tests' }
GPHRunComparatorTest >> testNearBoundaryMarginIsRecordedInConsistencyJson [

	| commits |
	commits := (GPHJsonFile read:
		            fileSystem root / 'compare' / 'consistency.json') at:
		           'commits'.
	self assert: (commits at: 'nearBoundaryMarginSeconds') equals: 86400
]

{ #category : 'tests' }
GPHRunComparatorTest >> testNearBoundaryMarginIsTenPercentOfTheWindowCappedAtOneDay [

	| comparator since |
	comparator := GPHRunComparator new.
	since := GPHTime parse: '2026-01-01T00:00:00Z'.
	self
		assert:
		(comparator nearBoundaryMarginSince: since until: since + 1 day)
		equals: 8640.
	self
		assert:
		(comparator nearBoundaryMarginSince: since until: since + 1 hour)
		equals: 360.
	self
		assert:
		(comparator nearBoundaryMarginSince: since until: since + 31 days)
		equals: 86400
]

{ #category : 'tests' }
GPHRunComparatorTest >> testNullNewPathFallsBackOnOldPath [
	"DR1b: in D mode the importer leaves new_path nil and keeps the GitHub filename in old_path. The path key is new_path, else old_path, so the file pairs with its H counterpart."

	| fileOf runOf compare diffs mismatch |
	fileOf := [ :oldPath :newPath :additions :deletions |
		          OrderedDictionary new
			          at: 'old_path' put: oldPath;
			          at: 'new_path' put: newPath;
			          at: 'additions' put: additions;
			          at: 'deletions' put: deletions;
			          at: 'patch_present' put: true;
			          at: 'binary' put: false;
			          yourself ].
	runOf := [ :aRunId :aFile |
		         self
			         write: aRunId
			         commits: { (self
					          commit: 'x1'
					          date: '2026-01-10T00:00:00Z'
					          parents: 1
					          name: 'Alice'
					          email: 'alice@x.org'
					          kind: 'github-account') }
			         diffs: (Dictionary new
					          at: 'x1' put: (OrderedDictionary new
							           at: 'files_truncated' put: false;
							           at: 'files' put: { aFile };
							           yourself);
					          yourself)
			         prs: #(  ) ].
	compare := [ :aFileD :aFileH |
		           (GPHRunComparator new
			            compare: (runOf value: 'null-D' value: aFileD)
			            with: (runOf value: 'null-H' value: aFileH)
			            into: fileSystem root / 'null-compare') at: 'diffs' ].
	diffs := compare
		         value: (fileOf
				          value: 'a/X.java'
				          value: nil
				          value: 2
				          value: 1)
		         value: (fileOf
				          value: 'a/X.java'
				          value: 'a/X.java'
				          value: 2
				          value: 1).
	self
		assert: (diffs at: 'pathKeyRule')
		equals: 'new_path, else old_path'.
	self assert: (diffs at: 'pathFallbackCountD') equals: 1.
	self assert: (diffs at: 'pathFallbackCountH') equals: 0.
	self assert: (diffs at: 'comparedCommits') equals: 1.
	self assert: (diffs at: 'identicalCommits') equals: 1.
	self assert: (diffs at: 'pathMismatches') isEmpty.
	self assert: (diffs at: 'countMismatches') isEmpty.
	diffs := compare
		         value: (fileOf
				          value: 'a/X.java'
				          value: nil
				          value: 2
				          value: 1)
		         value: (fileOf
				          value: 'a/X.java'
				          value: 'a/X.java'
				          value: 5
				          value: 1).
	self assert: (diffs at: 'identicalCommits') equals: 0.
	self assert: (diffs at: 'pathMismatches') isEmpty.
	self assert: (diffs at: 'countMismatches') size equals: 1.
	mismatch := (diffs at: 'countMismatches') first.
	self assert: (mismatch at: 'sha') equals: 'x1'.
	self assert: (mismatch at: 'path') equals: 'a/X.java'.
	self assert: (mismatch at: 'additionsD') equals: 2.
	self assert: (mismatch at: 'additionsH') equals: 5
]

{ #category : 'tests' }
GPHRunComparatorTest >> testOneDayWindowListsOnlyShasWithinTheMargin [
	"1-day window: margin 8 640 s. n1 (1 h after since) is near; m1 (12 h from both bounds) is not."

	| commitOf commitsD commitsH commits near |
	commitOf := [ :sha :date |
		            self
			            commit: sha
			            date: date
			            parents: 1
			            name: 'Alice'
			            email: 'alice@x.org'
			            kind: 'github-account' ].
	commitsD := Dictionary new
		            at: 'm1'
		            put:
			            (commitOf value: 'm1' value: '2026-01-01T12:00:00Z');
		            yourself.
	commitsH := Dictionary new
		            at: 'n1'
		            put:
			            (commitOf value: 'n1' value: '2026-01-01T01:00:00Z');
		            yourself.
	commits := GPHRunComparator new
		           commitSetsOf: commitsD
		           and: commitsH
		           since: (GPHTime parse: '2026-01-01T00:00:00Z')
		           until: (GPHTime parse: '2026-01-02T00:00:00Z').
	self assert: (commits at: 'nearBoundaryMarginSeconds') equals: 8640.
	near := commits at: 'nearBoundary'.
	self
		assert: (near collect: [ :entry | entry at: 'sha' ]) asArray
		equals: #( 'n1' ).
	self assert: (near first at: 'secondsFromSince') equals: 3600
]

{ #category : 'tests' }
GPHRunComparatorTest >> testPullRequestNumbersAndResolutions [

	| pullRequests |
	pullRequests := report at: 'pullRequests'.
	self assert: (pullRequests at: 'sameNumbers').
	self assert: (pullRequests at: 'onlyD') isEmpty.
	self assert: (pullRequests at: 'onlyH') isEmpty.
	self assert: ((pullRequests at: 'resolutionsD') at: 'api') equals: 1.
	self deny:
		((pullRequests at: 'resolutionsD') includesKey: 'api-fallback').
	self
		assert: ((pullRequests at: 'resolutionsH') at: 'api-fallback')
		equals: 1.
	self
		assert: ((pullRequests at: 'resolutionsH') at: 'not-merged')
		equals: 1.
	self
		assert: ((pullRequests at: 'resolutionsH') at: 'in-window-model')
		equals: 1.
	self
		assert: (((pullRequests at: 'resolutionPairsDtoH') at: 'api') at:
				 'api-fallback')
		equals: 1.
	self assert: (pullRequests at: 'mergeCommitShaMismatches') isEmpty
]

{ #category : 'tests' }
GPHRunComparatorTest >> testShasNearAWindowBoundaryAreListed [
	"d1 is 5 h after since, h2 is 4 h before until; h1 is mid-window and is not listed."

	| near |
	near := (report at: 'commits') at: 'nearBoundary'.
	self
		assert: (near collect: [ :entry | entry at: 'sha' ]) asArray
		equals: #( 'd1' 'h2' ).
	self
		assert: (near collect: [ :entry | entry at: 'side' ]) asArray
		equals: #( 'D' 'H' ).
	self assert: (near first at: 'secondsFromSince') equals: 5 * 3600.
	self assert: (near second at: 'secondsFromUntil') equals: -4 * 3600
]

{ #category : 'helpers' }
GPHRunComparatorTest >> write: aRunId commits: someCommits diffs: aDiffDictionary prs: somePullRequests [

	| directory |
	directory := fileSystem root / aRunId.
	GPHJsonFile
		write: (OrderedDictionary new
				 at: 'runId' put: aRunId;
				 at: 'config' put: (OrderedDictionary new
						  at: 'since' put: '2026-01-01T00:00:00Z';
						  at: 'until' put: '2026-02-01T00:00:00Z';
						  yourself);
				 yourself)
		to: directory / 'meta.json'.
	GPHJsonFile
		write: (OrderedDictionary new
				 at: 'commits' put: someCommits;
				 yourself)
		to: directory / 'commits.json'.
	GPHJsonFile
		write: (OrderedDictionary new
				 at: 'commits' put: aDiffDictionary;
				 yourself)
		to: directory / 'diffs.json'.
	GPHJsonFile
		write: (OrderedDictionary new
				 at: 'pullRequests' put: somePullRequests;
				 yourself)
		to: directory / 'prs.json'.
	^ directory
]
