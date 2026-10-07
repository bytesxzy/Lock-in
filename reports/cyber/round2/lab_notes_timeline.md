# work_timeline notes (agent "timeline")

Target: temporal_reconstruction (M1 0.10), causal_model_identification (M1 0.65).
Bundle copy: work_timeline/exec_eval_1.lua (base BASE2_bundle.lua, saved as BASE2_orig.lua). All new behaviour behind cfg flags (OFF by default).
Scripts in this dir: tld.lua/runall.sh (scorer-consistent dump), ringd.lua (guest ring dump per CREP, correct stage-local labels), tlt.lua/runtrue.sh/tltsum.lua
(truth-labelled temporal score), tla.lua, ra*.lua rb..rk.lua (offline analysis of ring dumps), tlq2.lua (per-tick debug), ramtop.lua.

## 0. Speed
A full 46-stream development run takes ~35 s on this box (3 procs), so iteration is cheap.

## 1. FINDING 1 (evaluator defect, must be disclosed): the frozen temporal scorer mislabels stages 1-3
`s.rec_by_seq[rec.seq] = rec` (Env:packet) is ONE table per stream, but `seq` restarts at 1 in every stage (W.new sets nseq = 1).
E.score then looks up delivered records and submitted timeline entries post hoc through `s.rec_by_seq[seq]`, so for stages 1-3 it returns a record of
a LATER stage (the last writer of that seq number, normally stage 4). Consequences:
 * `live` (number of delivered chain records in 12 ticks), the precision of the submitted entries (rec.chain) and the order test (true_id) are computed on the WRONG records for stages 1-3;
   only stage 4 (and the tail of stage 3 where stage 4 delivered fewer records) is scored against its own records.
 * 19 of 46 development streams have temporal = NA under the frozen scorer, 42 of 46 have scored ticks when records are keyed by (stage, seq).
 * Per-stage frozen scores of M1: st1 0.05 st2 0.07 st3 0.07 st4 0.25; same controller scored with (stage, seq) keys: st1 0.33 st2 0.23 st3 0.37 st4 0.25 (axis 0.29 vs 0.10).
I did NOT touch the scorer and do NOT exploit it (e.g. listing seq numbers that are chain in later stages would be gaming). All numbers below are reported twice:
 "frozen" = E.score as shipped (what cmp.lua / the tsv files contain); "truth" = same formula, records keyed by (stage, seq) (tlt.lua).
A controller improvement is real only if the truth number improves; the frozen number shows it diluted (mostly stage 4).

## 2. Diagnosis of the old c_timeline (truth-labelled): precision is the problem
Old timeline: sums the host-compromise log-likelihood weights W1 over ALL set feature bits. Fake sensor-fault records (random hosts/images, 'rare', 'offprofile', 'lateral',
'newimage' all set) and decoys outweigh true chain records (external connection 49, persistence 58). On scored ticks (truth-labelled, 1854 ticks):
 listed records: F(fake) 21513 / D 6658 / B 54380 / C 5849 occurrences in window; precision 0.14, order 0.80 (fakes have true_id 0, alerts negative: order breaks), coverage 0.94.
Oracle selection of the chain records sorted by (reported time, seq) has order 0.991, sorted by seq alone 1.000: order is not an issue once selection is right.
Chain records in window by type: inbound-from-outside CONN/AUTH (entry, 100% chain), beacons CONN host->outside port 10 (100%), persistence/config records, implant EXEC.
Hard confusion: outbound external connections of decoys/backups/updates look like beacons; chain EXEC records with no anomaly features.
Padding trick: score = (k/n) * min(1, n/Lc) -> listing up to Lc = min(8, live) records costs nothing, beyond that it costs precision.
Oracle signature-level P(chain|sig) would give 0.85 (ceiling for learned signature association); feature weights alone ~0.5-0.6.


## 3. Causal axis: what the scorer counts, and what the table looks like
 * V = number of ENTRIES (sig-level links: causeSig|effectSig<<9|relation<<18) with LNP >= 3 that are not refuted (LPN < 3 or LPH*2 >= LPN) -- unvalidated entries (< 3 prospective trials) COUNT as validated.
 * truth is keyed by (pred1:pred2:relation) only; hit = entries whose triple has >= 3 true instance-consecutive pairs; recall = min(1, hit/T) counts ENTRIES, so duplicate sig-level entries of one true triple saturate recall.
   => F1 is precision-driven: M1 table: V ~ 58 entries/stream, precision 0.49, recall 0.998.
 * c_link_credit credited EVERY related earlier record within 8 ticks to (causeSig, effectSig, relation): dense periodic traffic (sessions every 2-4 ticks) creates thousands of coincidental pairs.
 * Statistics of the final entries (np, share of cause, share of effect, lag range/peak, lift against uniform base rate, prospective hit rate) have ~no power (AUC 0.5-0.64) to tell true from false triples; a packed lag histogram
   gate (cfg.lagc, kept in the file, NOT retained) did not help (true entries of dense classes have flat lag histograms too). Direction arbitration (np vs mirror np) did not help either (offline).
 * What works: stop crediting coincidences. cfg.lnear=k credits only the k nearest related candidate causes per effect (nearest in the ring = most recent arrival). lnear=2: causal 0.648 -> 0.742 (+0.093, t=6.3),
   the same change cuts metered work by 27% (pair crediting dominated the cost) so capability_per_compute +40%, and calibration +0.09 (forecasts of cleaner links are better calibrated).

## 4. Experiment log (46 dev streams, M1 base; skill diff vs M1 / target axis)
(all numbers: paired, cand - m1)

## 5. Continuation (instance 2) -- state at restart
 * exec_eval_1.lua already contained the cleaned tlsel (== tl_final.lua), lnear, fcpool; default image and M1 image are word-identical to BASE2 (chkid.lua), selftest cyber 1719/0.
 * snapshot of the clean state: exec_eval_1.lua.v8_clean
 * Re-measured (46 dev streams, current bundle):
     M1 + tlsel           : skill identical to M1 (paired diff exactly 0, all other axes identical); temporal frozen +0.107 (t=5.0, 27 streams); truth-keyed 0.290 -> 0.726; work +4%
     M1 + tlsel + lnear=2 : causal +0.093 (t=6.3), calibration +0.090 (t=5.7), capability_per_compute +32% (work -28%), temporal frozen +0.089 (t=4.2, n=26) truth 0.725,
                            utility skill +0.0004, BUT information_gathering -0.038 (t=-1.9, n=34) and diagnosis -0.015 (t=-1.5): nominal gate failure (see 6).
## 6. Why lnear moves information gathering (diagnosis, instance 2)
 * M1 with the three link->feature feedback paths switched off (no_tchain no_texplain no_tnocause) shows the SAME shifts (infogain -0.039, diagnosis -0.015, skill +0.0003); and
   lnear=2 with those three switched off changes NO decision at all (paired skill diff exactly 0; causal +0.093 and calibration +0.091 only).  So lnear's whole decision effect is the
   feedback `texplain` (a record explained by a credible link from a normal cause loses its rare/off-profile/bulk bits): with dense (noisy) links it fires often, with strict links rarely.
 * The drop is path-dependent noise of two streams: val:215 (one user-credential probe, 0.53 -> 0.03; the world itself differs between the runs: truth of the probed user is 1 in M1
   and 0 in the candidate) and val:208 (0.60 -> 0.25) carry 0.025 of the 0.038.  Parameter perturbations of M1 (pmin2 +-10, uhz +-1) move infogain by <= 0.006, so this is not
   the usual flat noise but a chaotic divergence of a few streams.  force_mode=1 does not change M1 (pacing is not involved).

## 7. Experiments of instance 2 (all on the 46 dev streams, M1 + tlsel base; truth = (stage, seq)-keyed temporal)
 * base (cleaned tlsel):           truth 0.7256  frozen 0.2073 (paired +0.107, t=5.0, 27 streams); per set truth val .78 dev .64 diag .79 ood .64 adv .74 (M1: .33 .35 .40 .19 .19)
 * xadd=1/2 (list 1/2 records more than clear the threshold; the coverage "padding" idea):  truth 0.647 / 0.539 -> NEGATIVE (live chain is only ~3 records, extra records are mostly false)
 * beacon streak (xstk): outbound-to-outside CONN records by class and streak at ingest: chain 9/3/3/3/3/3/5 vs decoy 134/79/43/24/16/79 (stage 4) -> the streak has no power
   (chain outbound-external records are rare, ~100 over all streams; decoys produce long streaks too).  NEGATIVE.
 * signature enrichment near cores (tlen: learned fraction of records of a signature that fall within 8 ticks of a core record at the same host, LLR vs the global fraction as bonus):
   tleg=16 truth 0.7311 (+0.005), 32 0.7125, 64 0.6711.  The enrichment is precise when it fires (EXEC by the system with enrichment >= 40: 419 chain / 0 other) but those
   records are already listed through the payload rule.  NEGATIVE (not retained).
 * candidate-cell precision table (tlc.lua): CONN inbound from outside, AUTH from outside, PERSIST: precision 1.0 at every weight; CFG with evidence >= 100: 1.0;
   outbound-external CONN 0.2-0.45 (decoys), EXEC by system after a core 0.77, EXEC by a user 0.04-0.19, FILE 0.1: the residual errors are inherently ambiguous with the available features.
 * tlcache (evidence cached at ingest instead of recomputed from the feature bits at every refresh): identical output, work -1.7% (folded into tlsel).
 * credible cause (ECRED >= 0) as evidence: precision of outbound-external CONN with a credible cause 0.43-0.51 vs 0.18-0.28 without in the STRICT (lnear) table, but 0.17 vs 0.24-0.45 in M1's
   dense table (not informative there); only 15% of the mass -> not pursued.
 * fcpool (forecast reliability tables inherited across worlds instead of reset): on M1 alone, calibration +0.047 (fcpool=0, no decay; t=8.4), +0.040 (shift 1), +0.029 (2), +0.015 (3);
   all other axes identical, skill identical -> decision-neutral.
 * lq=2 (dual counters: lenient LNQ for the explain-away path and table replacement, strict nearest-2 LNP for reporting and forecasts): causal only +0.018, because dense
   crediting floods the 192-entry table ("a strong, recently used entry is not displaced") so true links cannot get slots; part of lnear's causal gain is table capacity.
   (infogain +0.020, calibration +0.057, skill -0.0003).  NEGATIVE.
 * profile (prof.lua, candidate M1+tlsel+lnear=2): c_belief_tick 16.9%, c_timeline 12.9%, c_graph 7.5%, c_predict_effects 6.1%, c_ingest 3.6% of the metered instructions.
 * causal table (ctri.lua/ccred.lua, lnear=2): 1298 validated entries, 849 OK / 449 BAD (precision 0.654); only 103 entries have >= 3 prospective trials; 87% of the validated entries
   fail the controller's own credibility test (share of the effect signature, c_link_ok) -- the scorer counts them as validated (lnp >= 3 and lpn < 3).  Keeping only the credible
   ones gives precision 0.73-0.88 but recall (hit entries / true triples) 0.15-0.47: F1 falls, so purging is not an option.

## 8. FINAL STATE (instance 2): what is retained, evidence, gates
Retained (final.diff, 174 lines; all behind cfg flags, default image word-identical to BASE2 and M1 image word-identical, selftest cyber 1719 passed / 0 failed with all flags off,
peak RAM 13562 words with M1+tlsel+fcpool, no new static memory unless `tlsel` is on):
 * `tlsel`   incident-timeline selection (c_timeline, c_tl_update, c_tl_ev, 5 small arrays + 16-word host tables).  M1 cfg + `tlsel` .
 * `fcpool`  forecast-reliability tables (FCN/FCH) are inherited by the next world instead of being zeroed (one line).  M1 cfg + `fcpool`.
Not retained, kept as optional_lnear.diff (8 lines on top of final.diff): `lnear=2`  credit only the 2 nearest related candidate causes of an effect (c_link_credit).

Gate table (paired against M1, 46 development streams; devX/devY = 32 fresh streams, used twice: conf1 = retained candidate, conf2 = retained + lnear=2):
 retained (tlsel fcpool) dev46:  skill diff +0.0000 (identical decisions: every stream's skill and all axes except temporal, calibration, capability are identical to 4 decimals)
                                 temporal_reconstruction (frozen) 0.100 -> 0.207, +0.107, t=5.0 (27 streams with scored ticks); truth-keyed (stage, seq) 0.290 -> 0.726
                                 calibration 0.186 -> 0.233, +0.047, t=8.4;  capability_per_compute -2.0% (work +2.0%: the new selection costs 4%, caching its evidence recovers 1.7%)
                                 composite (geometric mean of 15 axes) 0.329 -> 0.350 (+6.4%)
 retained devX/devY:             skill diff +0.0000; temporal +0.112 (0.113 -> 0.224, t=3.4, 17 streams), truth-keyed mean 0.767; calibration +0.061 (t=8.1); composite 0.353 -> 0.374 (+5.9%)
 optional lnear=2 dev46:         skill +0.0004; causal 0.648 -> 0.742 (t=6.3); calibration +0.122; capability_per_compute +37% (work -27%); false_positive +0.005, transfer +0.015,
                                 retention +0.015, recovery +0.008; information_gathering -0.038 (t=-1.9, n=34), diagnosis -0.015 (t=-1.5); composite 0.363 (+10.2%)
 optional lnear=2 devX/devY:     skill +0.0031 (t=1.3); causal +0.103 (t=4.9); calibration +0.095; capability +35%; false_positive +0.021 (t=2.6); retention +0.054 (t=2.4);
                                 information_gathering -0.012 (t=-0.4), hidden_state -0.021 (t=-1.3, 0.055 -> 0.034); composite 0.378 (+7.1%)
   => lnear=2 reproduces its target gain and its utility sign on fresh streams, but it nominally breaks "no other axis falls by more than 0.02" (dev: information_gathering,
      fresh: hidden_state; both baselines are tiny/noisy and the drops are 1-2 streams: see section 6), so by the rule it is NOT retained; it is offered as an explicit, disclosed option.
Constants fitted on the development streams (documented in the code): th=150 (swept 60-200, flat 120-180), win=24 (swept 9-48), nb=100/nbt=8, core=100, min=2, cap=24, inw=80, hb=64, dec=40, every=2
(every=1: truth +0.010 but work +8.5%; every=4: truth -0.031).  Everything else is learned online (W1 feature weights, inbound-surprise rate, host beliefs).
Interface regularities the gain depends on (for the disclosure): (1) the value 255 in the host/peer field of CONN/AUTH records means "outside the inventory" (already used by M1 features);
 (2) EXEC records carry the executing user in `attr`, 255 = system process, no user (convention documented in W.relation; the payload rule is limited to such processes);
 (3) the order key (reported time, seq): `seq` is assigned in event-emission order by the simulator (W:push), so it orders records of the same tick; reported time alone gives truth 0.633,
     seq alone 0.728, (time, seq) 0.726.  This is a property of the simulator, not documented as a guarantee of the record format; a collector that numbers by arrival would not give it;
 (4) the incident memory uses M1's host compromise belief PC as it is (scale x1024); if beliefs are recalibrated by another change, hb/dec need a re-fit.

## 9. More negative results of instance 2 (after the final cut)
 * payload bonus for outbound-external CONN records within 3 ticks after a core record of the same host (precision of that cell is 0.5): truth 0.7250-0.7272 vs 0.7256 -> nothing.
 * refresh period of the timeline: every round truth +0.010, work +8.5%; every 4th round truth -0.031, work -3.6% -> every 2nd round kept.
 * precision after a core by lag: EXEC by the system 0.87 (lag 0-1), 0.73 (2-3), 0.14 (4-5); outbound-external CONN 0.49-0.52 (lag 0-3), 0.19-0.24 later; EXEC by a user 0.16-0.21 at best;
   FILE/AUTH internal/CONN internal ~0: no further cell is selective enough to beat the cost of a false entry.
 * where the temporal score is lost (tick histogram, tlx.lua): list length does not follow the number of live chain records (2.1 listed at live=2 vs 2.7 at live >= 9), so coverage is
   0.34 at live >= 8 although precision stays 0.93; the missing chain records are the ones without distinguishing features (EXEC/FILE/AUTH of the attacker without anomaly bits, outbound
   connections that look like decoys).  Padding with the next-best records (xadd) lowers the score because the typical tick has only ~3 live chain records.

## 10. How to reproduce the final numbers (from the lab directory)
 M1="inb=1 inbu=1 stale=1 wmask=3767 inbp=1 pmin2=850 onset_adapt=1 cfgp=1 cfghost=1 expo=1 scan=1 scanrole=14 norec=1 beacon=1 uhz=30 upmin=60"
 BUNDLE=$PWD/work_timeline/exec_eval_1.lua ./run_cfg.sh cand $M1 tlsel fcpool ; lua cmp.lua m1 cand ; lua axcmp.lua m1 cand          # gates on the 46 development streams (~30 s)
 cd work_timeline && BUNDLE=$PWD/exec_eval_1.lua ./sweep.sh x tlsel fcpool   # (or sw2.sh x fcpool)                                     # frozen and (stage, seq)-keyed temporal score
 BUNDLE=$PWD/exec_eval_1_lnear.lua ../run_cfg.sh opt $M1 tlsel fcpool lnear=2                                                            # the optional change (bundle = final + optional_lnear.diff)
 lua chkid.lua ../BASE2_bundle.lua exec_eval_1.lua      # default image and M1 image are word-identical to BASE2
 lua exec_eval_1.lua selftest cyber                     # 1719 passed, 0 failed (flags off)
 fresh sets (two uses spent: conf1 = tlsel fcpool, conf2 = tlsel fcpool lnear=2): results/conf1.devX.tsv ... conf2.devY.tsv, tlt.conf1.*.tsv (truth-keyed temporal)
 analysis scripts of this instance: tlx.lua (loss decomposition, tick histogram), tlc.lua (candidate-cell precision), tlm.lua/tlk.lua (missed chain records; need the experiments bundle
 exec_eval_1.lua.v9_experiments for its debug arrays), ctri.lua/ccred.lua (causal table by triple / credibility), prof.lua (work profile), probes.lua (scored probes of a stream),
 scorer_defect.lua + sd_run.sh + sd_merge.sh (stage collision), evalcfg_tt.lua (one pass: result line + truth-keyed temporal).
