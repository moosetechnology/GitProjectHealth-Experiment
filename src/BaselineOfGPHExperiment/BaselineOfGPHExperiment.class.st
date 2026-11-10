"
I am the Metacello baseline of the GitProjectHealth experiment harness (MSR 2027 hybrid import artifact). I load GPHExperiment-Harness and its tests, plus the parts of GitProjectHealth (branch experience) used by the harness: GitHub remote importer (mode D) and local/mixed importers (mode H).
Metacello new
	baseline: 'GPHExperiment';
	repository: 'github://moosetechnology/GitProjectHealth-Experiment:main/src';
	load.
"
Class {
	#name : 'BaselineOfGPHExperiment',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfGPHExperiment',
	#package : 'BaselineOfGPHExperiment'
}

{ #category : 'baselines' }
BaselineOfGPHExperiment >> baseline: spec [

	<baseline>
	spec for: #common do: [
			self defineDependencies: spec.
			self definePackages: spec.
			self defineGroups: spec ]
]

{ #category : 'dependencies' }
BaselineOfGPHExperiment >> defineDependencies: spec [
	"GitProjectHealth-Bridge and GitProjectHealth-Model-LocalImporter-Tests are only used by GPHExperiment-Harness-Tests (GPHBridge testResources and the GitLocalModelImporterWithTestResource resource). They share the single GitLabHealth project spec because one baseline name can be declared only once."

	spec baseline: 'GitLabHealth' with: [
			spec
				loads:
					#( 'GitProjectHealth-Model-Importer'
					   'GitProjectHealth-Model-LocalImporter'
					   'GitProjectHealth-Model-MixedImporter'
					   'GitHubHealth-Model-Importer' 'GitProjectHealth-Bridge'
					   'GitProjectHealth-Model-LocalImporter-Tests' );
				repository:
					'github://moosetechnology/GitProjectHealth:experience/src' ].
	spec baseline: 'NeoJSON' with: [
			spec
				loads: #( 'core' );
				repository: 'github://svenvc/NeoJSON/repository' ]
]

{ #category : 'groups' }
BaselineOfGPHExperiment >> defineGroups: spec [

	spec
		group: 'Core' with: #( 'GPHExperiment-Harness' );
		group: 'Tests' with: #( 'GPHExperiment-Harness-Tests' );
		group: 'default' with: #( 'Core' 'Tests' )
]

{ #category : 'packages' }
BaselineOfGPHExperiment >> definePackages: spec [

	spec
		package: 'GPHExperiment-Harness'
		with: [ spec requires: #( 'GitLabHealth' 'NeoJSON' ) ];
		package: 'GPHExperiment-Harness-Tests'
		with: [ spec requires: #( 'GPHExperiment-Harness' ) ]
]
