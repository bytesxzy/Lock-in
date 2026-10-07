# Audit of the generation-5 cyber controller (round 2)

Three independent audit agents were given the immutable candidate (`G.build({})`, all generation-5 defaults) and told to break the claims honestly: **cheat** (leakage, regularities, constants, scorer gaming),
**robust** (generalisation, stress, budgets, determinism, ablations) and **review** (line-by-line code review). All three were interrupted by a usage limit; **cheat** and **robust** had finished their experiments
(about 500 and 1000 result files; the tables below are regenerated from those files with their own scripts), **review** never started, so **the code-review audit of the ~560 added lines did not happen**. Nothing in this
file was selected on: the held-out set heldF was never touched by an audit (the drivers refuse it).

Raw tables: `audit_perturbation_tables.txt` (cheat), `audit_robust_tables.txt` (robust), `audit_twin_noninterference.txt` and `audit_twin_ext.lua`, `fresh24_*` (24 never-used streams), `lab_notes_*.md`, `SCORER_DEFECT.md`.

## 1. No hidden-state leakage (twin worlds)
The unchanged controller was run on pairs of worlds that differ in one HIDDEN fact that a new mechanism could only react to by leaking (the persistence bit, a stolen credential, exposure bits, the campaign vector,
blind sensors, the revoked-user lag state, ...). Every request, action, report, forecast and timeline it emits is identical up to the first world-produced message that differs; in every case that message was produced by the
**world**. Facts that never reach the controller (the scorer's labels randomised, a `ghost` flag with no channel, the name of the set `val` / `diag` / `held` for the same world, the start tick or the stealth of a
campaign whose records were not delivered) gave **identical whole runs**. (`audit_twin_noninterference.txt`.) The suite `cyber` contains the original three twin perturbations.

## 2. Regularities of the interface the gains rely on, perturbed in a copy of the world (dev streams, skill; generation 4 = 0.583)
| regularity | broken how | final controller | mechanism off | generation 4 | reading |
|---|---|---|---|---|---|
| a login from outside paired with an inbound connection is never a stolen credential (52 of 52) | every external login is paired | 0.909 (hs 0.29) | 0.945 (hs 0.45) | 0.612 | `upair` then costs 0.036; with 3-tick jitter it is neutral (0.921 vs 0.919) |
| inbound flows from outside are attacks | benign inbound flows injected, low / mid / high | 0.817 / 0.721 / 0.632 | 0.439 / 0.431 / 0.374 | 0.568 / 0.488 / 0.404 | still the best on skill, but false-positive control collapses 0.96 -> 0.49 / 0.19 / 0.13 |
| exact persistence read (tool payload bit) | flag hidden / 40% false negatives / 15% of benign hosts flagged | 0.918 / 0.926 / 0.920 | 0.919 / 0.920 / 0.918 | 0.583 | graceful, except that false positives are believed: hidden_state 0.53 -> 0.11, diagnosis 0.95 -> 0.75 |
| revoked credentials stay stolen for 3 ticks | lag 0 / 6 | 0.933 / 0.926 | same | 0.586 / 0.583 | skill unchanged, hidden_state 0.37 / 0.41 (0.53 at 3) |
| sequence numbers order records inside a tick | arrival order / shuffled | timeline (keyed) 0.673 / 0.608 | 0.286 / 0.271 | 0.328 / 0.307 | the selection stays far above none; the order key is a small part of it |
| EXEC attr 255 = system process | 254 / random | timeline 0.682 / 0.695 | 0.300 | | payload rule off costs 0.01 |
| beacon port | changed | 0.921 | 0.918 | 0.538 | the feature is worth nothing here (kept off in the next revision) |
| sensor faults | x1 / x2 noise | 0.877 / 0.862 | | 0.534 / 0.473 | cold-start controller 0.864 / 0.850 |
Robust agent, combined noise levels 1-4 (drops, duplicates, misattribution, spurious records, blind hosts, decoys): 0.890 / 0.856 / 0.818 / 0.740 against generation 4 0.510 / 0.433 / 0.366 / 0.330.

## 3. The fitted constants sit on plateaus
Each of 27 constants and switches was moved (`k_*`, `f_*` rows of `audit_perturbation_tables.txt`): qsh 0..308, pmin2 700/1000, uhz 15, upmin 120, scan roles, rpx / rpq, fq2 bar / prior ticks, timeline threshold / core / window,
beacon count, the report map slopes and offsets. Skill moves by at most 0.011 and the composite by at most 0.012; the largest moves are scanning every role (-0.026), `rla` 50 (-0.011) and `rlc` -95 (-0.011).
(The robust agent's own sensitivity table is empty: its jobs were not run, so it is not cited.)

## 4. Generalisation
| streams | final | cold-start controller (M1) | generation 4 |
|---|---|---|---|
| development 46 | 0.9305 | 0.9096 | 0.5834 |
| devX + devY 32 | 0.9570 | 0.9438 | 0.6125 |
| burned held sets held..heldE 80 | 0.9416 | 0.9282 | 0.5936 |
| 96 seeds nobody used (dev / ood / adv parameters) | 0.9006 | 0.8843 | 0.5319 |
| 24 further seeds 20001-20024 (this report) | 0.935 | | 0.619 (OLD 0.181, TRIAGE 0.239) |
No stream of the 158 named streams (min +0.087) or the 96 new ones is worse than generation 4. The gain over M1 is real but small out of sample: +0.021 (development), +0.013 (112 fresh named), +0.016 (96 new, t 3.4);
it depends on the world: +0.004 (not significant) in worlds with informative alerts, +0.027 with noisy ones. 6 of 158 named streams (3.8%) and 8 of 96 new ones are worse than M1 by more than 0.03 (worst -0.157, devX:513):
in each the cause is a gateway host compromised without an onset record (the entry record dropped or misattributed), refused by the calibrated gates `qsh` / `qvo` for 5-30 ticks (removing either restores M1's result on that stream).
recovery_quality falls by 0.021 (t -2.9) on the 112 fresh streams and by 0.060 on the 96 new ones: this exceeds the lab's own 0.02 tolerance on fresh data.

## 5. Attribution (ladder on all 158 streams; skill, paired steps)
generation 4 0.5945 -> + onset evidence 0.8623 (+0.268, t 24.8) -> + exact reads and exposure closure 0.9259 (+0.064, t 10.5) -> + calibrated beliefs 0.9399 (+0.014, t 5.5) -> + timeline and link crediting 0.9415 (+0.002, t 1.7).
Geometric composite of the 15 axes on the development streams: 0.249 -> 0.337 -> 0.329 -> 0.461 -> 0.499. Leaving one group out of the final controller: onset evidence -0.417, exact reads / exposure -0.060, beliefs -0.015, timeline -0.002.
Single switches (dev 46 / burned 80, skill when OFF relative to the final): `inb` +0.266, `inbu` +0.058, `scanrole` +0.026, `scan` +0.025, `qr` +0.018, `qsh` +0.016, `inbp` +0.014, `cfgp` +0.009, `stale` +0.006, `upair` +0.003
(its value is hidden_state +0.12). **Net negative in the final configuration:** `uhz` (-0.003 on dev, -0.011 on the burned sets: switching it off is better), `upmin` and `beacon` (about -0.0005, noise), `pmin2` (-0.001, noise).
The 13 named ablations still run without faults and with the expected sign, except that `no_hidden_state` is slightly better on skill (+0.006: it costs a little utility, it buys hidden_state / diagnosis) and `no_counterfactuals` / `no_compute_meta`
change no decision at the protocol budgets (the first only the metered work, -8%).

## 6. Budgets, determinism, resources (158 named streams)
Complete, no violation, no guard trip, no fault: at the frozen budget and at 1/4 of it (skill 0.941 / 0.937), at 6.0M work (0.905, min 0.515). Below that streams run out of budget: 5.0M 147/158 complete (0.842), 4.0M 125/158 (0.714), 3.0M 0/158.
The compute-ablated twin fails far earlier (at 8.4M 18/32 complete). Separate-process re-runs and reversed seed order reproduce every digest, utility and work value; `legacy_defaults` gives the pre-upgrade bundle's utility and skill on all 158 streams
(metered work differs by at most 0.13%). Peak static RAM touched 14,024 of 16,128 words, peak stack 88 of 256.

## 7. What this audit does not show
* The code review (array bounds at hosts 7-16 / users 4-12, state carried across episodes, the ablation paths under the new defaults, the paired-login withdrawal logic, forecast bookkeeping across episode ends) did not run.
  The 13 ablations, 6 budgets and 254 streams ran without fault or violation, which is evidence, not a review.
* Everything is measured in the simulator whose generator produced the regularities the gains use; nothing here says how much of it transfers to real telemetry.
* The frozen temporal scorer defect (`SCORER_DEFECT.md`) was found by the belief/timeline explorers and is disclosed, not exploited.
