"
GPHBranchAnnotator on the local git repository of the existing TestResource GitLocalModelImporterWithTestResource (GPHBridge testResources). No clone and no network. The resource repository only has local branches, so only the default branch (main) is walked.
"
Class {
	#name : 'GPHBranchAnnotatorTest',
	#superclass : 'TestCase',
	#instVars : [
		'repository',
		'annotator'
	],
	#category : 'GPHExperiment-Harness-Tests-Export',
	#package : 'GPHExperiment-Harness-Tests',
	#tag : 'Export'
}

{ #category : 'accessing' }
GPHBranchAnnotatorTest class >> resources [

	^ Array with: GitLocalModelImporterWithTestResource
]

{ #category : 'running' }
GPHBranchAnnotatorTest >> setUp [

	super setUp.
	repository := LGitRepository on:
		              GPHBridge testResources / 'testResource'.
	repository open.
	annotator := GPHBranchAnnotator
		             on: repository
		             since: (DateAndTime year: 2000 day: 1).
	annotator annotate
]

{ #category : 'tests' }
GPHBranchAnnotatorTest >> testBranchTableIsFilled [

	self deny: annotator branchesBySha isEmpty.
	self assert: annotator defaultBranchName equals: 'main'.
	self assert: annotator headSha size equals: 40.
	self assert:
		((annotator branchesBySha at: annotator headSha) includes: 'main').
	self assert: (annotator headDate isKindOf: DateAndTime)
]

{ #category : 'tests' }
GPHBranchAnnotatorTest >> testLocalResolvability [

	self assert: (annotator isResolvableLocally: annotator headSha).
	self deny:
		(annotator isResolvableLocally: (String new: 40 withAll: $0))
]

{ #category : 'tests' }
GPHBranchAnnotatorTest >> testSinceStopsTheWalk [
	"With since after every commit of the resource, nothing is annotated."

	| late |
	late := GPHBranchAnnotator
		        on: repository
		        since: (DateAndTime year: 2100 day: 1).
	late annotate.
	self assert: late branchesBySha isEmpty
]

{ #category : 'tests' }
GPHBranchAnnotatorTest >> testSkippingOldBranchTipsKeepsTheBranchTable [
	"Differential check against GPHOldBranchAnnotator (one revwalk per remote branch, no tip skip) for several since bounds."

	{
		(DateAndTime year: 2000 day: 1).
		annotator headDate.
		(DateAndTime year: 2100 day: 1) } do: [ :since |
			| old new |
			old := GPHOldBranchAnnotator on: repository since: since.
			old annotate.
			new := GPHBranchAnnotator on: repository since: since.
			new annotate.
			self assert: new branchesBySha equals: old branchesBySha.
			self assert: new headSha equals: old headSha ]
]
