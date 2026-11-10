# Running the experiments

This guide explains how to load the measurement harness in a Pharo image and how to re-run the runs of the protocol (`protocol/protocol-v1.fr.md`). The harness compares two ways of importing a GitHub repository with GitProjectHealth:

- mode **D** (direct): `GithubModelImporter` only, everything through the GitHub REST API;
- mode **H** (hybrid): `GitModelMixedImporter`, with commits and diffs read from a local clone (`#cold`: fresh clone, `#warm`: existing clone).

## 1. Requirements

- Pharo 13.1, 64 bit. The experiment used `Pharo-13.1.0+SNAPSHOT.build.748.sha.acdc1aaef95938eb7b024566561d73dc1db090da (64 Bit)`.
- Network access to `github.com` and `api.github.com`.
- A GitHub token. The harness reads the `GITHUB_TOKEN` environment variable, or else the `github.com` credentials stored in Iceberg. The token is redacted from every file written by the harness.
- Enough disk space for the local clones used by mode H (`microsoft/vscode` is large).

## 2. Load the harness

```smalltalk
Metacello new
	baseline: 'GPHExperiment';
	repository: 'github://moosetechnology/GitProjectHealth-Experiment:main/src';
	load.
```

`BaselineOfGPHExperiment` loads:

| Project | Repository | What is loaded |
|---|---|---|
| GitLabHealth (GitProjectHealth) | `github://moosetechnology/GitProjectHealth:experience/src` | `GitProjectHealth-Model-Importer`, `-LocalImporter`, `-MixedImporter`, `GitHubHealth-Model-Importer`, and the test support packages `GitProjectHealth-Bridge` and `GitProjectHealth-Model-LocalImporter-Tests` |
| NeoJSON | `github://svenvc/NeoJSON/repository` | group `core` |
| this repository | | `GPHExperiment-Harness`, `GPHExperiment-Harness-Tests` |

Groups: `Core` (harness only), `Tests` (harness tests), `default` (`Core` + `Tests`). The test support packages of GitProjectHealth are loaded in every case.

**Exact version.** The baseline follows the `experience` branch of GitProjectHealth. The runs reported in the paper used commit `6eb6304bdf65d4cfb1061f60b657d9cc64bb192b`. To reproduce them exactly, check out this commit of the `GitProjectHealth` repository in Iceberg before running.

## 3. Check the installation

Run the tests of package `GPHExperiment-Harness-Tests` (Test Runner, or the package's test command). They use only a local `ZnServer` and need no Internet access. In the experiment image: 98 tests, 98 passed (2026-11-10).

## 4. Outputs and working directory

Paths are relative to the image working directory (`FileSystem workingDirectory`):

- `gph-exp-out/<runId>/`: one directory per run, with `meta.json`, `status.json`, `timings.json`, `api-calls.json`, `commits.json`, `diffs.json`, `prs.json`, `counts.json`;
- `gph-exp-out/<batchId>/batch-status.json`: state of a batch, rewritten after every change;
- `consistency.json`: written by the comparison of a D run and an H run;
- `msr/<repository name>/`: local clones used by mode H.

The output and clone roots are the `outputRoot` and `cloneRoot` attributes of `GPHRunConfig`.

## 5. Run one configuration

```smalltalk
"Predefined subjects of the protocol"
config := GPHRunConfig verveineJMode: #D clone: #cold.   "or: GPHRunConfig vscodeMode: #H clone: #warm"

"Any repository and time window [since, until) in UTC"
config := GPHRunConfig repo: 'owner/name' mode: #H since: aDateAndTime until: anotherDateAndTime.

runId := GPHRunRegistry default launch: config.   "answers immediately; the run executes in a background process named 'GPH-<runId>'"
GPHRunRegistry default statusOf: runId.
```

Two runs can be compared with `GPHRunRegistry default compare: runIdD with: runIdH`.

## 6. Re-run the protocol batches

A batch runs its configurations one after the other in a single background process (`GPH-batch-<batchId>`), then the D/H comparisons. A failed or timed-out run is recorded and the batch goes on; a run is never relaunched.

Parameters of the protocol:

| Subject | Window (UTC) | Global timeout | Rate-limit threshold |
|---|---|---|---|
| `moosetechnology/VerveineJ` | [2025-10-01, 2026-10-01) | 30 min | 500 |
| `microsoft/vscode` | [2026-09-01, 2026-10-01) | 2 h | 4000 |

Order of runs for each subject: D-1, H-cold-1, D-2, H-warm-2, D-3, H-warm-3, H-cold-4 (`diffStrategy: #B`, 1 minute pause between runs).

Example (subject vscode):

```smalltalk
makeConfig := [ :runId :mode :clone |
	(GPHRunConfig vscodeMode: mode clone: clone)
		runId: runId;
		globalTimeout: 2 hours;
		diffStrategy: #B;
		rateLimitThreshold: 4000;
		yourself ].
batch := GPHRunBatch new batchId: 'batch-vscode-1'; yourself.
batch addConfig: (makeConfig value: 'VS-D-1' value: #D value: #cold).
batch addConfig: (makeConfig value: 'VS-H-cold-1' value: #H value: #cold).
"... remaining runs in the order above ..."
batch addComparison: 'VS-D-1' -> 'VS-H-cold-1'.
batch pauseBetweenRuns: 1 minute.
batch waitAllowance: 4 hours.
batch start.
batch statusFile fullName.
```

- check that no `GPH-*` process is still running;
- release the models of finished runs and collect garbage: `GPHRunRegistry default releaseFinishedModels. Smalltalk garbageCollect.`;
- check that the GitProjectHealth repository is at the expected commit and not modified.

Follow a batch with `GPHRunBatch statusOf: '<batchId>'` (reads `batch-status.json`) and stop it with `batch stop`.
