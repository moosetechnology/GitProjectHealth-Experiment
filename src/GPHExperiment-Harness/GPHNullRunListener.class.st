"
I am the listener of a runner that runs synchronously, outside a registry: I start no watchdog and always allow finalization.
"
Class {
	#name : 'GPHNullRunListener',
	#superclass : 'Object',
	#category : 'GPHExperiment-Harness-Run',
	#package : 'GPHExperiment-Harness',
	#tag : 'Run'
}

{ #category : 'notifications' }
GPHNullRunListener >> claimFinalizationOf: aRunner [
	"Nobody else can interrupt the run: the runner may always finalize."

	^ true
]

{ #category : 'notifications' }
GPHNullRunListener >> rateLimitGateWillWait: aRateLimitCheck [
	"Nothing to do."

	
]

{ #category : 'notifications' }
GPHNullRunListener >> runnerDidStartMeasuredPhase: aRunner [
	"No watchdog outside a registry."

	
]
