"
I write JSON files atomically (write a .tmp sibling, then rename it over the target) and read them back. Strings can be passed through a redactor (a GPHTokenProvider) before being written.
"
Class {
	#name : 'GPHJsonFile',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Support',
	#package : 'GPHExperiment-Harness',
	#tag : 'Support'
}

{ #category : 'reading' }
GPHJsonFile class >> read: aFileReference [

	^ NeoJSONReader fromString: aFileReference contents
]

{ #category : 'private' }
GPHJsonFile class >> replace: aFileReference with: aTemporaryFile [
	"On disk the store-level rename (rename(2)) atomically replaces an existing target. Other file systems (memory, used by tests) refuse to overwrite, so the target is deleted first."

	aFileReference fileSystem isDiskFileSystem ifTrue: [
			^ aFileReference fileSystem store
				  rename: aTemporaryFile path
				  to: aFileReference path ].
	aFileReference ensureDelete.
	aTemporaryFile renameTo: aFileReference basename
]

{ #category : 'writing' }
GPHJsonFile class >> write: anObject to: aFileReference [

	self
		writeString: (NeoJSONWriter toStringPretty: anObject)
		to: aFileReference
]

{ #category : 'writing' }
GPHJsonFile class >> write: anObject to: aFileReference redactor: aRedactor [
	"Write anObject as pretty JSON, passing the text through aRedactor (#redact:) first."

	self
		writeString:
		(aRedactor redact: (NeoJSONWriter toStringPretty: anObject))
		to: aFileReference
]

{ #category : 'writing' }
GPHJsonFile class >> writeString: aString to: aFileReference [
	"Write a sibling .tmp file, then rename it over aFileReference."

	| temporary |
	aFileReference parent ensureCreateDirectory.
	temporary := aFileReference parent
	             / (aFileReference basename , '.tmp').
	temporary ensureDelete.
	temporary writeStreamDo: [ :stream | stream nextPutAll: aString ].
	self replace: aFileReference with: temporary
]
