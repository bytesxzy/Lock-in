# Cyber reasoning upgrade of `exec_eval_1.lua` — final report

Everything below was measured with the bundle in this repository (Lua 5.4 only, no external model, no network, no other language).
Raw per-stream rows and paired reports are in `reports/cyber/`; the pre-upgrade bundle is `baseline/exec_eval_1.lua`.

## 0. Update: generation 5 and the `sketch.lua` workspace (read this first)

Two things were added after the generation-4 report that follows (sections 1–8, kept as measured; their verdict applies to generation 4 and is superseded for the default controller by 0.1).
Every number in this section was produced by the bundle in this repository (Lua 5.4 only, no external model, no network).

### 0.1 Generation 5 of the cyber controller (default `G.build({})`)

**What changed.** Four groups of mechanisms, each a `cfg` flag of the compiled guest controller, ON through `G.DEFAULTS` (`cfg.x = false` switches one off; `cfg.legacy_defaults = true` restores the
generation-4 decisions, with metered work within 0.13%; the `cyber-eval` variant `gen4` runs that controller):
* **onset evidence** (`inb inbu inbp onset_adapt stale pmin2 wmask`): an inbound flow from outside the inventory is evidence about its destination host, a login from outside about its user, a new persistence
  record about its host; the weight is the learned surprise of such an event under the rate seen so far; the evidence is sticky, decays, and records older than the last remediation of their entity are ignored;
* **exact reads and early exposure closure** (`cfgp cfghost expo scan scanrole beacon norec uhz upmin`): the configuration / host tool returns the autostart flag, so exposure is closed before it is used;
* **calibrated beliefs and posterior-gated decisions** (`qr qsh qvo`), activity forecasts (`fq2 fcpool`), login pairing (`upair`);
* **incident-timeline selection** (`tlsel`) and nearest-cause link crediting (`lnear`).
Guest image `1a10b215…` (514,272 bits, 7,992 words, static RAM top 14,072 of 16,128); generation 4 `ebb23466…` (440,288 bits). Found in parallel lab explorations on the **development streams only**, kept
only when paired gates passed, then audited (twin-world noninterference, regularity perturbation, constant plateaus, generalisation, budgets: `round2/AUDIT_SUMMARY.md`).

**Pre-registered confirmation on `heldF` (16 streams, 9501–9516).** The controller image and the baselines (`baselines_heldF.*`) were recorded before the run (`FINAL_CONTROLLER.txt`); the set was never touched by a lab
or an audit; the controller was run on it once. Files: `gen5/`.

| budget 4/4 (at 1/4 and 2/4 generation 5 has the same skill 0.895 and ratios 3.74x / 3.73x vs OLD) | defensive skill | composite vs OLD (pre-registered rule) | vs TRIAGE |
|---|---|---|---|
| generation 5 | **0.895** | **3.73x** (95% CI 2.76–4.60) | **2.27x** (1.56–2.93) |
| generation 4 | 0.528 | 2.13x (1.72–2.55) | 1.39x (1.03–1.78) |
| OLD (pre-upgrade reasoner) | 0.171 | 1 | |
| TRIAGE (fixed heuristic) | 0.190 | | 1 |

On a second set of 24 never-used seeds (`round2/fresh24_report.txt`, run by the audit, not selected on): skill 0.935 against generation 4 0.619, OLD 0.181, TRIAGE 0.239 (4.51x vs OLD, CI 3.28–5.27).

**Reading.** The 2x composite target is **met on heldF**, under the rule fixed before the run. Three qualifications belong to the number:
1. The strict composite (geometric mean of all jointly supported axes) of OLD is exactly 0 because OLD scores 0.000 on `knowledge_retention`, so the ratio of composites is undefined; the number is the
   pre-registered fallback, the geometric mean of the per-axis ratios over the jointly supported axes whose reference is positive (8 of 15; six axes cannot be scored for OLD at all and are excluded, never zero-filled).
   The largest single ratio is `cross_environment_transfer` (22.5x); without it the figure is about 2.9x. `safety_compliance` enters at 1.00 (both comply).
2. Against the strong triage heuristic the figure is 2.27x, and `capability_per_compute` is 0.004 for generation 5 (about 230x the minimum work): triage is 14x more frugal. This is the weakest axis and it was not improved.
3. All of it is measured in the simulator whose generator produced the regularities the new mechanisms use (listed in `AUDIT_SUMMARY.md` section 2); nothing here says how much transfers to real telemetry.

**Where the gain comes from (all 158 development / diagnostic / validation / burned-held streams, skill, paired).** generation 4 0.5945 → + onset evidence 0.8623 → + exact reads and exposure closure 0.9259 →
+ calibrated beliefs 0.9399 → + timeline and link crediting 0.9415. Leaving one group out of the final controller costs −0.417 / −0.060 / −0.015 / −0.002. Out of sample the last two groups are small:
+0.013 over the controller without them on 112 fresh streams and +0.016 on 96 new seeds, so most of the gain is the first two groups.

**Known weaknesses of generation 5 (measured, not fixed).**
* Regularity brittleness: inbound noise collapses false-positive control (0.96 → 0.49 at low noise) although skill stays the best; false-positive persistence reads are believed (hidden_state 0.53 → 0.11); the login-pairing rule costs 0.036 when its regularity is broken.
* 6 of 158 named streams (and 8 of 96 new ones) are worse than the controller without the belief / timeline groups by more than 0.03 (worst −0.157): a gateway compromised without an onset record is refused by the calibrated gates for 5–30 ticks. None is worse than generation 4.
* `recovery_quality` falls by 0.02–0.06 on fresh streams.
* `uhz` and `upmin` are net negative in the final configuration (+0.003 … +0.010 skill when off) but stay in v5 exactly as it was run on heldF; removing them is the first change of the next revision, to be confirmed on the reserved set `heldG`.
* **The code-review audit of the ~560 added guest lines did not complete** (its agent hit a usage limit). The perturbation and robustness audits did; 13 ablations, 6 budgets and 254 streams ran without a fault or violation, which is evidence, not a review.
* The frozen temporal scorer resolves records by `seq` alone although sequence numbers restart in every stage (`round2/SCORER_DEFECT.md`). It was not exploited and not changed (the frozen axis stays 0.14 on heldF); the keyed diagnostic printed beside it is 0.58.
* Round-3 explorations (cross-environment transfer / retention, compute efficiency) were not done.

### 0.2 `sketch.lua`: a sandboxed code workspace and a program-synthesis coding agent

The system now has **one file to write code in, `sketch.lua`, and a set of tools to work on it** (modules `asi.sketch*`, commands `sketch-new / -call / -solve / -show / -replay / -import / -bench`, suite `sketch`).
The tools are the only way in: the coding agent uses the same `ws:call(tool, args)` interface as an operator, so every observation and change is costed (deterministic integer units), checked against a policy
(capabilities, file names, sizes, total budget, call limit, sandbox limits), appended to a hash-chained audit log and replayable (`sketch-replay` re-executes the log and checks every status, cost and digest).
Code runs only in an in-process sandbox (fresh environment without `os io debug load require coroutine` and string patterns; per-instruction step / memory / CPU limits; limits that `pcall` cannot swallow;
36 attack programs in the suite). The coding agent is program synthesis, not a language model: bottom-up enumeration over a typed DSL with observational equivalence, counter-example guided refinement against
validation cases, plus `fill` (complete a sketch with holes) and `repair` (mutate a failing function). Details, tool table and limits: `reports/sketch/README.md`.

Measured (`reports/sketch/BENCH.txt`; 54 tasks, a few examples each, 14 validation cases, 40 **hidden** cases the agent never sees): a program for 52 tasks, 51 correct on all hidden cases, hidden accuracy 0.958;
a lookup table of the training examples is right on 11.7% of the hidden cases; `fill` completes 4 of 6 sketches; `repair` fixes 5 of 6 seeded bugs against the visible tests (one of them, `count_big`, is right on 35 of 40 hidden cases).
`reports/sketch/example/` holds a `sketch.lua` of 27 functions written by the agent itself (220 logged tool calls, replay verified).
Limits: no loops or recursion in the DSL, examples are a weak specification (`all_pos` fits the validation cases and fails 10 of 40 hidden ones), the sandbox is in-process rather than an operating-system boundary.

### 0.3 Gates for this revision

`lua exec_eval_1.lua selftest`: **100,381 passed, 0 failed** (the 98,443 checks that existed before the cyber layer, unchanged; 1,719 in suite `cyber`; 219 in suite `sketch`; log `reports/gates/selftest_gen5.txt`).
The generation-3 held / diagnostic / generated evaluations (`reason-compare --held|--diagnostic|--generated --summary`) were re-run on this bundle and print **byte-identical** output to the pre-upgrade bundle
(`reports/gates/g3_{held,diag,gen}_final.txt` against `reports/pre_upgrade/g3_{held,diag,gen}.txt`). The CYB1 protocol hash is unchanged (`8005afaf…`); `legacy_defaults` reproduces the generation-4 utility and
skill on all 158 development / burned streams (metered work within 0.13%). Not done: the reserved set `heldG` was not run, the code-review audit did not complete, the round-3 explorations were not carried out.

## 1. Verdict in five lines (generation 4, the controller of the previous revision; section 0 supersedes it for the default controller)

* A real defensive-cyber reasoning system now exists inside the bundle: a procedural enterprise simulator, a metered four-operation
  interface (15 tools, 10 actions, belief reports and forecasts), one compiled guest controller that does all reasoning as charged VM instructions,
  a frozen benchmark with a 15-axis scorecard, baselines, 13 ablations, twin-world noninterference tests, a fully replayable CLI.
* On the one set that was never used for any decision (`heldE`, 16 streams, controller run once): defensive skill **0.500** against OLD **0.175**
  (2.9x) and a fixed triage heuristic **0.200** (2.5x). Composite ratio against OLD on the jointly supported axes **1.99x (95% CI 1.56–2.58)**.
* **The 2x composite target is not established.** Pooled over five held-out sets (80 streams, optimistic because they guided three revisions) the
  pre-registered rule gives 2.53x (CI 2.22–3.26), but that number leans on one axis (retention) where OLD scores 0.005; without it 1.81x (1.65–2.10).
  Against the strong triage heuristic the composite is 1.32x (1.16–1.66) because triage is ~170x cheaper in compute.
* All 98,443 pre-existing checks still pass, plus 1,719 new ones (100,162 total). The existing generation-3 held / diagnostic / generated evaluations print
  byte-identical output to the pre-upgrade bundle.
* The requested small improvement to the generation-3 reasoner was **not** achieved: five candidate modifications were measured and none cleared the gate, so none was kept.

## 2. What was built

| module (in the bundle) | role |
|---|---|
| `asi.cyber.world` | evaluator-only simulator: 7–16 hosts, 4–12 users, services/dependencies, routines, decoys, noisy/delayed/duplicated/misattributed sensors, blind hosts, attack campaigns (initial access, credential theft, lateral movement, persistence/respawn, exfiltration), 15 tools, 10 actions with costs/quotas/authorization, a perfect-information reactive reference defender (scoring only) |
| `asi.cyber.env` | the only boundary: `CSENSE / CTOOL / CACT / CREP`, charged work quoted before execution, validation and violation counting, 4-episode stream (base world, structural novelty, a different world, return with regime shock), legacy 4-field adapter that runs the unchanged generation-3 reasoner as OLD |
| `asi.cyber.guest` | the controller (GL program, ~6.4k words, 412k bits of the 1.05M cap) |
| `asi.cyber.eval` | 15-axis scorecard, paired suite, aggregation (ratios on jointly supported axes, paired seed bootstrap, ablation deltas), frozen benchmark pins |
| `asi.tests.t_cyber` | 1,719 checks (suite `cyber`) |

Controller mechanisms (all inside the guest): typed events with role-abstracted signatures; learned normality; temporal links mined and credited only after
prospective success; Poisson likelihood-ratio model of three hidden states (host compromised / credential stolen / persistence) with absence-of-evidence counted only
where a host is observable; bounded influence of correlated weak evidence; value-of-information probing; SIMULATE dry-runs and a two-step lookahead before KILL;
root-cause closure (misconfiguration, vulnerability via the local KB, credential); deterministic shield; world library (retention / transfer); self-resolved forecast
calibration; six epistemic statuses per host; 64-entry decision-provenance ring; predictive compute pacing (deep / normal / economy).

Commands: `cyber-run`, `cyber-eval`, `cyber-report` (`--min-ref`, `--exclude`), `cyber-trace`, `cyber-replay`, `cyber-stress`; test suite `cyber`.

## 3. No-cheating design and its tests

The guest sees nothing but what `asi.cyber.env` writes into its RAM; there is no seed, task id, ground truth, reference action or evaluator state on the interface
(pointers outside guest RAM fault the VM; checked). `t_cyber` runs **twin worlds** that differ only in a hidden fact (all credentials stolen / a hidden persistence /
a hidden foothold) and asserts that every tool request, action and report the controller emits is identical up to the first world-produced message that differs.
The three perturbations all become observable eventually, so the test is not vacuous. Replay: identical digests and identical VM interface traces on re-runs;
`cyber-replay rows.lua --all` re-runs saved rows and checks their digests.

## 4. The benchmark and the protocol that was followed

CYB1: protocol hash `8005afaf…dcfea1`, scoring hash `3ddd15d6…012388`, golden scorecard digest of three non-learning baselines, per-set world digests and the OLD image hash are
**pinned in the tests**. Baselines (passive, triage, sweeper, OLD) were recorded on every set at budgets 1/4, 2/4, 4/4 before the controller touched the held-out sets
(`reports/cyber/FREEZE.txt`). Development sets: `dev`, `diag`, `val`; `ood` (larger, noisier, structurally different) and `adv` (decoy-heavy, low-detection) were consulted while
developing. Held-out: `held`, `heldB` (first pass), and fresh sets `heldC`, `heldD`, `heldE` created outside the frozen protocol, each run once.

What actually happened (kept unedited under `reports/cyber/v1_first_pass`, `v2_second_pass`, `v3_third_pass`, `final`):

| pass | controller | fresh set | result and what it exposed |
|---|---|---|---|
| 1 | v1 | held, heldB | skill ≈0.5 vs OLD ≈0.2; but disabling the controller's own temporal explain-away *improved* held skill by 0.134 (se 0.037) → defect |
| 2 | v2 (explain-away narrowed) | heldC | 2.79x utility; exposed a tool-allowance violation (seed 9208), a budget cut-off at 1/4 (seed 9216), over-confident persistence beliefs (hidden-state axis exactly 0) |
| 3 | v3 (tool guard, predictive pacing, persistence shrink) | heldD | composite 1.55x (CI 1.29–2.10); ablating tools / information gain *improved* utility → probing bonus too large |
| 4 | v4 (bonus 40→20, selected on development sets) | **heldE** | the confirmation reported above |

Every fix was chosen on development sets (and the choice evidence is in `FINAL_CONTROLLER.txt`); each fresh set stopped being clean for later versions as soon as it informed a change.

## 5. Results

### 5.1 Clean confirmation set `heldE` (budget 4/4; budgets 1/4 and 2/4 give 2.00x and 1.99x)

| | skill | notes |
|---|---|---|
| passive / sweeper | 0.000 / 0.000 | |
| triage (fixed alert-score heuristic) | 0.200 | ~50k instructions per stream |
| OLD (generation-3 reasoner behind the 4-field adapter) | 0.175 | ~2.2M instructions |
| **NEW** | **0.500** | ~8.2M instructions |

Ratios against OLD per axis (NEW/OLD): utility 2.86, false-positive control 1.03, transfer 8.82, structural OOD 2.67, planning 2.15, recovery 2.04, capability per compute 0.81,
safety 1.00; retention not a ratio (OLD scored exactly 0). Geometric mean of the eight ratios: **1.99 (1.56–2.58)**. Against triage: composite 1.47 (1.02–2.01).

### 5.2 Pooled held-out (held, heldB, heldC, heldD, heldE; 80 streams, optimistic)

utility 0.577 vs OLD 0.205 (2.81x) vs triage 0.231 (2.49x); transfer 3.19x; structural OOD 2.46x; planning 2.56x; recovery 2.10x; **false-positive control 1.11x** (0.479 vs triage 0.937);
**capability per compute 0.85x** (and 0.02x against triage); retention 37x (OLD 0.005). Composite 2.53x (2.22–3.26); excluding retention 1.81x (1.65–2.10); against triage 1.32x (1.16–1.66).

### 5.3 Axes OLD cannot be scored on (NA there, never zero-filled)

diagnosis 0.69, causal-model identification 0.60, information-gathering efficiency 0.41, calibration vs climatology 0.26, temporal reconstruction 0.14, **hidden-state inference 0.02**.
The last two are weak; silent credential theft is essentially undetectable by this controller, and the incident timeline is right about one record in five.

### 5.4 Other sets (budget 4/4, defensive skill NEW vs OLD): structural-OOD 0.551 vs 0.115, adversarial 0.527 vs 0.077, dev 0.578 vs 0.212, diag 0.497 vs 0.277, val 0.639 vs 0.164.

### 5.5 Ablations (paired per seed, skill change when the mechanism is removed; positive = the mechanism helps; heldE / val)

memory +0.11 / +0.09, planning +0.08 / +0.07, uncertainty-aware decisions +0.05 / +0.07, root-cause closure +0.06 / +0.04, model learning +0.04 / +0.05.
Value-of-information probing, tools, counterfactual forecasts, graph reasoning, temporal links, hidden-state telemetry and the competing-hypotheses cap are within noise on utility
(se 0.01–0.04, sign varies by set). They carry the diagnosis, causal-model, information, calibration and timeline axes — not utility. This is a real negative finding about those
mechanisms, not a rounding error. (13 ablations were run: `no_model_learning, no_competing_hypotheses, no_counterfactuals, no_temporal, no_hidden_state, no_information_gain, no_planning,
no_graph, no_cyber_tools, no_memory, no_compute_meta, no_uncertainty, no_root_cause`.)

### 5.6 Compute control (`cyber-stress --set val`)

| work budget | NEW completes | skill | ablated (no compute meta) completes | skill |
|---|---|---|---|---|
| 8.39M (1/4 of frozen) | 16/16 | 0.653 | 11/16 | 0.428 |
| 6.29M | 16/16 | 0.619 | 0/16 | 0 |
| 4.19M (1/8) | 16/16 | 0.623 | 0/16 | 0 |

At the protocol budgets compute meta-control changes nothing; below them it decides completion. Economy mode (no probes, no link mining, no forecasts) keeps ~97% of the skill at ~half the work (val: 0.623 at 3.8M instructions vs 0.639 at 7.7M) —
which is also why capability per compute stays poor for the full pipeline.

## 6. Non-degradation gates

`reports/gates/selftest_after.txt`: 100,162 passed, 0 failed (98,443 pre-existing, unchanged, plus 1,719 `cyber`). `reports/gates/g3_{held,diag,gen}_after.txt` are byte-identical to
`reports/pre_upgrade/g3_{held,diag,gen}.txt`. The OLD controller image is pinned to the pre-upgrade image hash.

## 7. What did not work / honest limits (generation 4; the limits of generation 5 are in 0.1)

* **2x composite not robustly met** (sections 1 and 5). FP control is barely better than OLD and far worse than triage; capability per compute is worse than OLD and ~50x worse than triage.
* **Generation-3 reasoner improvement: none kept.** Measured on its development seeds (composite 0.2564): mixture forecasts over competing rules (−0.0004), per-bin forecast calibration (−0.0003),
  rule-score prior 1 / 4 (−0.0015 / +0.0027 with retention −0.1), memory window 8 / 20 (−0.008 / −0.0015), population 6 (+0.0009), permanent economy (−0.007). All reverted; the pre-upgrade behaviour is unchanged. A further sweep of 20 tunables (eb, novb, mintry, stagw, delibq, cbw, simstrong, reinds, deepfit, cbspread, each at two alternative values) on 48 frozen-family streams (development + diagnostic seeds) stayed within ±0.005 composite of the default 0.2485 (best +0.0047, simstrong=8): the reasoner sits on a flat optimum for its tunables.
* **Rejected cyber experiments:** meter fusion, one-hop graph prior propagation, forecast-hypothesis mixtures, learned report-layer recalibration (the intercept cannot be learned from probed labels), prior-strength sweeps.
* The controller is a hand-structured Bayesian reasoner with hand-set priors (feature prior multipliers, decision floor 0.2, persistence report shrink 0.024 + 0.35 p) and online-learned class rates; planning is receding-horizon with a two-step lookahead, not unrestricted search.
* The adversary is a stochastic procedural attacker with decoys, low detection and heavy noise, not an adaptive opponent. Worlds are procedural, not real enterprises.
* `knowledge_retention` is low on heldE (0.10) and the retention ratio is not meaningful when OLD scores ≈0; the report prints it as excluded.

## 8. Reproduce

```
lua exec_eval_1.lua selftest                         # 100,162 checks
lua exec_eval_1.lua selftest cyber                   # the cyber suite only
lua exec_eval_1.lua cyber-eval --set heldE --variants new,old,triage --budgets 4 --save rows.lua --summary
lua exec_eval_1.lua cyber-report reports/cyber/baselines_heldE.lua reports/cyber/final/new_heldE.lua
lua exec_eval_1.lua cyber-report --exclude knowledge_retention <rows files>
lua exec_eval_1.lua cyber-replay reports/cyber/final/new_heldE.lua --row 3
lua exec_eval_1.lua cyber-trace --seed 9401 --set heldE
lua exec_eval_1.lua cyber-stress --set val --works 6000000,4194304

# generation 5 (default controller), the pre-registered confirmation set, and the generation-4 controller for the paired comparison
lua exec_eval_1.lua cyber-eval --set heldF --variants new,gen4 --budgets 1,2,4 --save new_heldF.lua --summary
lua exec_eval_1.lua cyber-report reports/cyber/baselines_heldF.lua reports/cyber/gen5/new_heldF.lua

# the sketch.lua workspace
lua exec_eval_1.lua selftest sketch                  # 219 checks, including 36 sandbox attack programs
lua exec_eval_1.lua sketch-new && lua exec_eval_1.lua sketch-solve reports/sketch/example/task_square.lua && lua exec_eval_1.lua sketch-replay
lua exec_eval_1.lua sketch-bench --baseline --sketches        # reports/sketch/BENCH.txt
```
