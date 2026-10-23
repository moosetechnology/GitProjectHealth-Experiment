"
An observed local importer whose clone does not know any commit: GitLocalModelImporter>>#importDiffOfCommit: (the super send of GPHObservedLocalModelImporter) fails with LGit_GIT_ENOTFOUND, as for a commit absent from the clone.
"
Class {
	#name : 'GPHNotFoundLocalImporter',
	#superclass : 'GPHObservedLocalModelImporter',
	#category : 'GPHExperiment-Harness-Tests-Support',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
GPHNotFoundLocalImporter >> gitCommitOf: aCommit [
	"The clone does not contain aCommit: fail as libgit2 does."

	^ LGit_GIT_ENOTFOUND new signal:
		  'object not found - no match for id ' , aCommit id asString
]
