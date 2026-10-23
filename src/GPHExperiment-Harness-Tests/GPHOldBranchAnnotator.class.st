"
Test-only reference implementation: verbatim copy of GPHBranchAnnotator>>#annotate and #walk:named:hiding: as they were before the ""skip branches whose tip is older than since"" optimisation. Every remote branch gets its own time-sorted revwalk with the default branch hidden. Used for differential checks (old == new branchesBySha).
"
Class {
	#name : 'GPHOldBranchAnnotator',
	#superclass : 'GPHBranchAnnotator',
	#category : 'GPHExperiment-Harness-Tests-Export',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Export'
}

{ #category : 'annotating' }
GPHOldBranchAnnotator >> annotate [
	"Walk the default branch, then every remote branch other than the default one with the default branch hidden."

	| head |
	head := repository head.
	defaultBranchName := head gitName.
	headSha := head object name.
	headDate := head object time asDateAndTime asUTC.
	self walk: head named: defaultBranchName hiding: nil.
	self remoteBranchesToAnnotate do: [ :reference |
		self walk: reference named: reference gitName hiding: head ]
]

{ #category : 'private' }
GPHOldBranchAnnotator >> walk: aReference named: aBranchName hiding: aHiddenReference [
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
