"
After an H run (not timed), I walk the clone with LGitRevwalk, sorted by commit time, and stop at the first commit older than since: the default branch first, then each remote branch with the default branch hidden. I answer a table sha -> branch names, the HEAD sha and date of the clone, and whether a sha can be resolved locally.
"
Class {
	#name : 'GPHBranchAnnotator',
	#superclass : 'Object',
	#instVars : [
		'repository',
		'since',
		'branchesBySha',
		'defaultBranchName',
		'headSha',
		'headDate'
	],
	#category : 'GPHExperiment-Harness-Export',
	#package : 'GPHExperiment-Harness',
	#tag : 'Export'
}

{ #category : 'instance creation' }
GPHBranchAnnotator class >> on: anLGitRepository since: aDateAndTime [

	^ self new
		  setRepository: anLGitRepository since: aDateAndTime;
		  yourself
]

{ #category : 'annotating' }
GPHBranchAnnotator >> annotate [
	"Walk the default branch, then every remote branch other than the default one with the default branch hidden. A remote branch whose tip is older than since is skipped without any revwalk: the time-sorted walk would stop at once, while hiding the default branch costs a full history marking. Caveat: under clock skew, an ancestor dated at or after since below an older tip is not annotated."

	| head |
	head := repository head.
	defaultBranchName := head gitName.
	headSha := head object name.
	headDate := head object time asDateAndTime asUTC.
	self walk: head named: defaultBranchName hiding: nil.
	self remoteBranchesToAnnotate
		reject: [ :reference | self isTipOlderThanSince: reference ]
		thenDo: [ :reference |
			self walk: reference named: reference gitName hiding: head ]
]

{ #category : 'accessing' }
GPHBranchAnnotator >> branchesBySha [

	^ branchesBySha
]

{ #category : 'accessing' }
GPHBranchAnnotator >> defaultBranchName [

	^ defaultBranchName
]

{ #category : 'accessing' }
GPHBranchAnnotator >> headDate [

	^ headDate
]

{ #category : 'accessing' }
GPHBranchAnnotator >> headSha [

	^ headSha
]

{ #category : 'querying' }
GPHBranchAnnotator >> isResolvableLocally: aSha [

	^ [
		  LGitCommit of: repository fromHexString: aSha.
		  true ]
		  on: LGit_GIT_ENOTFOUND
		  do: [ false ]
]

{ #category : 'private' }
GPHBranchAnnotator >> isTipOlderThanSince: aReference [
	"Same test as the walk stop condition, applied to the tip commit only."

	^ aReference object time asDateAndTime < since
]

{ #category : 'private' }
GPHBranchAnnotator >> remoteBranchesToAnnotate [
	"Remote branches except origin/HEAD and the remote copy of the default branch."

	^ repository allBranches select: [ :reference |
			  reference isLocal not and: [
					  reference gitName ~= 'HEAD' and: [
						  reference gitName ~= defaultBranchName ] ] ]
]

{ #category : 'initialization' }
GPHBranchAnnotator >> setRepository: anLGitRepository since: aDateAndTime [

	repository := anLGitRepository.
	since := aDateAndTime.
	branchesBySha := Dictionary new
]

{ #category : 'private' }
GPHBranchAnnotator >> walk: aReference named: aBranchName hiding: aHiddenReference [
	"Sorting is set before pushing (changing the sort resets a libgit2 walker). Stops at the first commit older than since."

	| revwalk |
	revwalk := LGitRevwalk of: repository.
	revwalk beSortedByCommitTime.
	revwalk pushReference: aReference.
	aHiddenReference ifNotNil: [ :hidden | revwalk hideReference: hidden ].
	[ revwalk hasNext ] whileTrue: [
			| commit |
			commit := revwalk next.
			commit time asDateAndTime < since ifTrue: [ ^ self ].
			(branchesBySha at: commit name ifAbsentPut: [ Set new ]) add:
				aBranchName ]
]
