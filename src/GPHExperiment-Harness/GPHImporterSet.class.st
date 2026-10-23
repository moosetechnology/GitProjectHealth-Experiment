"
I hold the fresh model and importers of one run. importer is the importer driven by the run: the GithubModelImporter in mode D, the GitModelMixedImporter in mode H. local and mixed are nil in mode D.
"
Class {
	#name : 'GPHImporterSet',
	#superclass : 'Object',
	#instVars : [
		'model',
		'api',
		'local',
		'mixed',
		'importer'
	],
	#category : 'GPHExperiment-Harness-Importing',
	#package : 'GPHExperiment-Harness',
	#tag : 'Importing'
}

{ #category : 'accessing' }
GPHImporterSet >> api [

	^ api
]

{ #category : 'accessing' }
GPHImporterSet >> api: anObject [

	api := anObject
]

{ #category : 'accessing' }
GPHImporterSet >> fallbacks [
	"Answer the local fallbacks observed so far (none in mode D)."

	^ local
		  ifNil: [ #(  ) ]
		  ifNotNil: [ :localImporter | localImporter fallbacks ]
]

{ #category : 'accessing' }
GPHImporterSet >> importer [

	^ importer
]

{ #category : 'accessing' }
GPHImporterSet >> importer: anObject [

	importer := anObject
]

{ #category : 'accessing' }
GPHImporterSet >> local [

	^ local
]

{ #category : 'accessing' }
GPHImporterSet >> local: anObject [

	local := anObject
]

{ #category : 'accessing' }
GPHImporterSet >> mixed [

	^ mixed
]

{ #category : 'accessing' }
GPHImporterSet >> mixed: anObject [

	mixed := anObject
]

{ #category : 'accessing' }
GPHImporterSet >> model [

	^ model
]

{ #category : 'accessing' }
GPHImporterSet >> model: anObject [

	model := anObject
]
