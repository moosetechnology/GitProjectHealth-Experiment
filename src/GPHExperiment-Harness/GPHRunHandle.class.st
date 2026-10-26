"
I own the process of one run and its watchdog. The watchdog starts when the runner leaves the rate-limit gate; after the global timeout it terminates the run process, puts the run in state timeout and writes the partial export. I am the listener of my runner.
"
Class {
	#name : 'GPHRunHandle',
	#superclass : 'Object',
	#instVars : [
		'registry',
		'runner',
		'process',
		'watchdog',
		'mutex',
		'finished'
	],
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'instance creation' }
GPHRunHandle class >> registry: aRegistry runner: aRunner [

	^ self new
		  setRegistry: aRegistry runner: aRunner;
		  yourself
]

{ #category : 'private' }
GPHRunHandle >> cancelWatchdog [

	watchdog ifNotNil: [ :watchdogProcess |
			watchdogProcess == Processor activeProcess ifFalse: [
				watchdogProcess terminate ] ]
]

{ #category : 'notifications' }
GPHRunHandle >> claimFinalizationOf: aRunner [
	"The run process reached its finalization: from now on it cannot be interrupted, the watchdog is cancelled. Answer false when an interruption already won."

	self claimFinish ifFalse: [ ^ false ].
	self cancelWatchdog.
	^ true
]

{ #category : 'private' }
GPHRunHandle >> claimFinish [
	"Answer true for the first claimant only (normal finalization, watchdog or stop)."

	^ mutex critical: [
			  finished
				  ifTrue: [ false ]
				  ifFalse: [
						  finished := true.
						  true ] ]
]

{ #category : 'running' }
GPHRunHandle >> expireAfter: aDuration [
	"Watchdog body. TimedOut is only a Notification in Zinc, so valueWithin:onTimeout: is not enough: the run process is terminated."

	registry clock sleepSeconds: aDuration asMilliSeconds / 1000.
	self
		interruptWith: #timeout
		reason: 'global timeout of ' , aDuration asMilliSeconds printString
			, ' ms exceeded'
]

{ #category : 'testing' }
GPHRunHandle >> hasLiveProcess [
	"Whether the run process or the watchdog (which finalizes a timed-out run) is still alive."

	^ {
		  process.
		  watchdog } anySatisfy: [ :each |
		  each notNil and: [ each isTerminated not ] ]
]

{ #category : 'initialization' }
GPHRunHandle >> initialize [

	super initialize.
	mutex := Mutex new.
	finished := false
]

{ #category : 'running' }
GPHRunHandle >> interruptWith: aState reason: aString [
	"Terminate the run process, then let the runner record the state and write the partial export from the current process."

	self claimFinish ifFalse: [ ^ self ].
	process ifNotNil: [ :runProcess | runProcess terminate ].
	runner interruptWith: aState reason: aString
]

{ #category : 'testing' }
GPHRunHandle >> isFinished [

	^ runner isFinished
]

{ #category : 'accessing' }
GPHRunHandle >> outputDirectory [

	^ runner outputDirectory
]

{ #category : 'accessing' }
GPHRunHandle >> process [

	^ process
]

{ #category : 'memory' }
GPHRunHandle >> releaseModel [
	"Release the in-memory model of a finished run; answer whether it is released (see GPHRunner>>#releaseModel)."

	^ runner releaseModel
]

{ #category : 'memory' }
GPHRunHandle >> releaseModelIfNotRunning [
	"Release the model of a run that no live process can still use: a finished run, or a run whose process is terminated or absent although it never reached a terminal state (e.g. its process was terminated outside the harness). A pending run (nothing imported yet) or one being finalized is left alone, as is any run whose run or watchdog process is alive. Answer true only when this call released the model."

	self hasLiveProcess ifTrue: [ ^ false ].
	runner modelReleased ifTrue: [ ^ false ].
	runner isFinished ifTrue: [ ^ runner releaseModel ].
	(#( #pending #finalizing ) includes: runner state) ifTrue: [ ^ false ].
	runner forceReleaseModel.
	^ true
]

{ #category : 'running' }
GPHRunHandle >> runToCompletion [
	"GPHRunner>>#run handles step errors itself; this only keeps an unexpected failure (e.g. while finalizing) from opening a debugger in the background."

	[ runner run ]
		on: Error
		do: [ :anError | runner failWith: anError ]
]

{ #category : 'accessing' }
GPHRunHandle >> runner [

	^ runner
]

{ #category : 'notifications' }
GPHRunHandle >> runnerDidStartMeasuredPhase: aRunner [
	"The rate-limit gate is passed: start the watchdog of the global timeout. It runs above the run process priority so that it can preempt it."

	watchdog := [ self expireAfter: aRunner config globalTimeout ]
		            forkAt: Processor userSchedulingPriority
		            named: 'GPH-watchdog-' , aRunner runId
]

{ #category : 'initialization' }
GPHRunHandle >> setRegistry: aRegistry runner: aRunner [

	registry := aRegistry.
	runner := aRunner
]

{ #category : 'running' }
GPHRunHandle >> start [
	"Write the pending status, then fork the run at user background priority."

	runner listener: self.
	runner writeStatus.
	process := [ self runToCompletion ]
		           forkAt: Processor userBackgroundPriority
		           named: 'GPH-' , runner runId
]

{ #category : 'accessing' }
GPHRunHandle >> status [

	^ runner statusDictionary
]

{ #category : 'running' }
GPHRunHandle >> stop [

	self cancelWatchdog.
	self interruptWith: #stopped reason: 'stopped on request'
]

{ #category : 'accessing' }
GPHRunHandle >> watchdog [

	^ watchdog
]
