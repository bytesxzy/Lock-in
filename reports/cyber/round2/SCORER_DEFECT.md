# Evaluator defect: the temporal-reconstruction scorer resolves records of stages 1-3 to records of a later stage

Status: found while diagnosing `temporal_reconstruction` (agent "timeline"). Not exploited: the controller was never changed to take advantage of it, the scorer was not touched,
and every temporal number in the notes is reported twice (frozen scorer as shipped, and the same formula with records keyed correctly).

## What is wrong

1. `W.new` starts `nseq = 1` for every stage, so the telemetry sequence number `rec.seq` restarts at 1 in each of the four stages of a stream.
2. `Env:packet` stores each delivered record in ONE table per stream: `s.rec_by_seq[rec.seq] = rec` (the key does not contain the stage). Stage k+1 overwrites the entries of stage k.
3. `E.score` (block "5 temporal reconstruction") resolves, after the whole stream has run, (a) the delivered chain records that decide `live`, (b) every submitted timeline entry
   (`REP[8..15]`, precision) and (c) the pair order (`true_id`) through `s.rec_by_seq[seq]`. For stage 1, 2 and 3 the lookup returns the record that a later stage (normally stage 4,
   which usually delivers the most records) wrote under the same number.

Consequence: for stages 1-3 `live`, precision and order are computed on the wrong records; only stage 4 (and the tail of stage 3 where stage 4 delivered fewer records) is scored against
the records the controller actually saw. A controller that lists exactly the attack records of stage 1 is scored against stage-4 records, so the frozen score of stages 1-3 is almost
independent of timeline quality (it even moves in the wrong direction: see stage 2 below).

Other consequences on the 46 development streams: the frozen scorer reports no scored tick (axis `nil`) for 19 streams; with (stage, seq) keys 42 of the 46 streams have scored ticks.
(fresh sets devX/devY: 15 of 32 vs 3 of 32 without scored ticks.)

## Reproduce

```
cd lab/work_timeline
M1="inb=1 inbu=1 stale=1 wmask=3767 inbp=1 pmin2=850 onset_adapt=1 cfgp=1 cfghost=1 expo=1 scan=1 scanrole=14 norec=1 beacon=1 uhz=30 upmin=60"
BUNDLE=$PWD/exec_eval_1.lua ./sd_run.sh m1  $M1                 # controller M1                     (about 40 s)
BUNDLE=$PWD/exec_eval_1.lua ./sd_run.sh fin $M1 tlsel fcpool    # M1 + the retained timeline change  (about 40 s)
./sd_merge.sh m1; ./sd_merge.sh fin                             # per-stage table over the five development sets
```
`scorer_defect.lua` (the script both call) runs a stream, captures every delivered record under its true key (stage, seq), then prints per stage how many delivered records the shipped
lookup resolves to a different record, how many of those change the chain label, and the temporal score computed (a) exactly as `E.score` does and (b) with (stage, seq) keys.
It reads evaluator state only; nothing in the controller or the scorer is modified.

## Measured effect (46 development streams, tick-weighted per stage)

| | stage 1 | stage 2 | stage 3 | stage 4 |
|---|---|---|---|---|
| delivered records | 9346 | 9431 | 10129 | 10516 |
| resolved by the shipped lookup to ANOTHER record | 99% | 98% | 89% | 0% |
| chain label flipped by that | 323 | 288 | 249 | 0 |
| scored ticks, frozen / (stage, seq)-keyed | 359 / 641 | 358 / 548 | 426 / 419 | 374 / 374 |
| M1, frozen scorer | 0.049 | 0.067 | 0.073 | 0.246 |
| M1, (stage, seq)-keyed | 0.329 | 0.232 | 0.372 | 0.246 |
| M1 + tlsel + fcpool, frozen scorer | 0.056 | 0.033 | 0.108 | 0.577 |
| M1 + tlsel + fcpool, (stage, seq)-keyed | 0.725 | 0.766 | 0.730 | 0.577 |

Axis means (mean over streams that have scored ticks): M1 frozen 0.100 (27 streams) vs keyed 0.290 (42 streams); candidate frozen 0.207 (27 streams, paired +0.107, t = 5.0)
vs keyed 0.726. On the fresh sets devX/devY the candidate scores 0.767 keyed and +0.112 (t = 3.4) paired frozen against M1.

Reading the table: stage 4 is the only stage on which the frozen number is a measurement, and it rises 0.246 -> 0.577. On stages 1-3 the frozen number is noise (stage 2 falls
0.067 -> 0.033 although the correct score rises 0.232 -> 0.766).

## Suggested fix (evaluator side)

Key the lookup by stage, e.g. `s.rec_by_seq[stage][seq]` (store `s.rec_by_seq[s.stage]` in `Env:packet`, look up with `r.stage` / `d.stage` in `E.score`), or make `seq` unique per stream
(do not reset `nseq` in `W.new`). The controller-visible record format is unchanged by either fix.
