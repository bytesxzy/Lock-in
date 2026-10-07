# work_belief NOTES (agent "belief")

Bundle copy: work_belief/exec_eval_1.lua (edit with small patches only). M1 tokens in work_belief/M1.txt.
Diagnostics (all read evaluator truth, never the controller): hs5.lua (per-stream decomposition), hs6.lua (mass by situation), utl.lua (user timelines),
evdump.lua (records at a host, captured per stage -- NOTE s.rec_by_seq collides across stages, seq restarts per stage), collect.lua + runcollect.sh
(per-entity-tick dump of truth + report + guest internal state, in work_belief/data), py/*.py (offline fitting; numpy only).

## Findings (M1, 46 dev streams)
* hidden_state per stream = clip(1 - sse/const) with const = n*base*(1-base) pooled over host-comp, user-stolen, host-persist entities of the stream.
  Mean 0.035. Pooled sse/const ~ 1.18 (host 0.63, user 0.47, pers 0.085 on val).
* The report is hugely OVERCONFIDENT: reported 0.43 -> 6% true, 0.69 -> 14%, 0.81 -> 25%, 0.95 -> 63% (hosts). Engine EB log-odds slope is only ~0.27 nat/bit
  (correlated evidence double counted); ON (sticky onset) is under-weighted (1.05 nat per ON bit).  Decoy hosts sit at the EB clamp (PC 0.8) for tens of ticks.
* Persistence report: flat 6/255 on every host; truth persist = 0.13% of host ticks; exact reads (cfg bit 3) are 100% reliable; 'KILL did not last' hypothesis
  (EB2=80) is right ~1% of the time but reported at 0.35-0.9.
* Users: after REVOKE the truth stays stolen for 3 more ticks (reissue lag) but the guest resets its belief at once: dt=1..3 after revoke y=0.5, reported 0.003.
  ~50% of REVOKEs are on users that are not stolen (misconfig-vector entries emit AUTH-from-EXT for a RANDOM user).  Stolen detection == delivery of an
  AUTH-from-EXT record (70/71 episodes); 9-10 of 80 stolen episodes (244 of 664 stolen user ticks) never get one (dropped) and stay silent.
* Offline (numpy, LOSO over sets) a fixed documented map  lo_h = 0.388 EB + 1.656 ON - 106 (x16 log2 units),  lo_u = 0.38 EB1 + 0.86 ONU - 89, pending-revoke
  window keeps the at-revoke belief for 3 ticks, persistence 0 except exact-read-positive (0.985):  hidden_state 0.035 -> ~0.43 (no decision change).
* Info efficiency: only 65 scored VERIFY probes in 46 streams (23 y=1 gain 0.86, 38 y=0 gain 0.08).  Under honest calibrated reports efficiency would fall
  0.39 -> 0.32 (the y=0 'gain' came from overconfident pre-probe reports).  Calibrated pre-probe belief splits probes cleanly: qpre>=0.05: 22 probes P(y)=0.82
  (nearly all the gain); qpre<0.05: 39 probes P(y)=0.05.  => gate probes on the calibrated posterior (efficiency 0.57-0.63 offline, and ~39 fewer probes).
* Interface regularities used / to disclose: exact persistence read (HOST/CONFIG payload cfg bit 3); revoke/reissue lag of 3 ticks (tuned constant);
  AUTH from external = onset evidence (already in M1).

## Status log
(see below, appended as work proceeds)

### Log 1 (report layer, probe gating, forecasts)
* NAME COLLISION: cfg.rl already exists (follow-up clean multiplier, default 12).  My flag is cfg.qr (report layer); never use cfg.rl.
* GL: at most 4 call arguments; static symbol names must be unique (C_QP exists: mine are BQH/BQU/BQP).
* qr=1 (report layer; also rlp=1 probe evidence at full strength): decisions identical (skill diff exactly 0), hidden_state 0.03 -> 0.44, diagnosis 0.87 -> 0.95,
  info 0.38 -> 0.31 (honest pre-probe reports remove the 'gain' that overconfident reports used to get from corrected false alarms).
* qpg=N (probe gate on calibrated posterior, BQH >= N/1024): fewer wasted probes: qpg=51: info +0.10, skill +0.0028; qpg=64: info +0.14, skill +0.0035 (t 1.8),
  cross_env -0.015 (noise from 2 streams; chaotic dependence on the labels the probes would have produced).  qpg=77: cross_env -0.028 (fails the 0.02 gate).
* fqc=1: forecasts: no window running past the episode end (hit rate 51% vs 71%), pooled per-type record as prior of the per-bin record, no orphan registrations:
  calibration +0.15 (0.19 -> 0.34).  fqb=1 (needs fqc): forecast probability = logistic mix of the model (log-odds, weight 0.22) and the HOST's own base rate for
  such a window (weight 0.77, bias -0.42; development fit): calibration 0.46.  A hard 'edge over host base rate' filter (fqe) is far too strict (<20 forecasts per
  stream scores 0: cliff), do not use it as is.

### Log 2 (calibrated posterior as a decision input)
* Using the calibrated posterior BQH as a decision input is worth more than the report itself: in M1, 149 of 377 KILLs went to hosts whose calibrated posterior was
  <= 0.3 (96% of them clean: decoys / evidence-engine clamp), costing services.
  - qsh=N: hosts with BQH < N/1024 are not candidates in c_decide_host (a SHIELD-level block was worse, -0.016: the blocked best candidate starves the others).
  - qvo=1: the value of a VERIFY probe (c_voi_host) is computed on BQH instead of PC (makes qpg redundant): info efficiency +0.20.
  Together with qr rlp fqc fqb: skill +0.0178 (t 5.4), fp +0.062, info +0.206, hidden_state +0.398, calibration +0.253, diagnosis +0.078, planning +0.017,
  retention +0.052, recovery -0.008, causal -0.003, temporal -0.003 (all vs M1, 46 dev streams).
* qdc=1/2 (expected losses and candidate floor on BQH instead of PC): +0.0012..0.0014 more skill only (t ~2): not retained for now.
* The scorer judges an action's target by the truth of the PREVIOUS tick: an immediate (same tick) response to a fresh onset counts as a false positive for the fp axis.

### Log 3 (continuation instance)
* Re-established (results/bel_r2_best = M1 + qr=1 rlp=1 fqc=1 fqb=1 qsh=205 qvo=1; identical to bel_c2_qvo1 within 0.0001): skill +0.0177 (t 5.4) vs M1 on 46 dev;
  all-axes composite 0.329 -> 0.433; hs 0.03->0.43, diag 0.87->0.95, info 0.38->0.63, calib 0.19->0.44, fp 0.86->0.93, retention 0.45->0.50, recovery -0.008.
  devX/devY were NOT used so far (no bel_*.devX/devY files): both confirmation runs are still available.
* Brier mass after qr (hs6 on val+ood / dev+diag+adv, pooled const 776 / 860): host y=1 36%/34%, user y=1 24%/26%, persistence y=1 undetected 2%/7%, all y=0 < 6%.
* Silent stolen users: 8 of 79 stolen episodes (226 of 654 stolen user-ticks; 55% of the user sse) NEVER get belief > 0.15 (all last until the stage ends).
  In val 206 the lateral AUTH record AUTH(u, dst, src=compromised host) names the stolen user, but EB1 stays at the -120 clamp.
* HOST BEACONS: of the 883 compromised host-ticks (sse 569), 298 have a beacon record (CONN host->EXT, a3=10 attr=0, the only EXT conn with that signature)
  delivered within the last 8 ticks; they carry 244 of the 569 sse with mean reported p 0.16.  P(y | n beacon recs within 10 ticks, deduped) = 0.007 (n=0), 0.37 (1),
  0.81 (2), 1.0 (3+), while the report is 0.06-0.09 in all of them.  Benign EXT conns (a3 3/4: update/offsite/decoy) recur at the same host often (P(y)=0.01-0.02),
  so a rate feature on EXT conns is useless; the signature (rare, concentrated at one host) is what carries the evidence.  The engine's beacon evidence decays
  between beacons (+40 per beacon, -7 per quiet tick, period 6): no accumulation.
* Offline ceilings (py/ceiling.py, c3 data): hs 0.433; perfect users 0.673; perfect hosts 0.731; perfect persistence 0.461; silent hosts reported 0.3 -> 0.57.
  The oracle beacon-signature feature (a3=10, which no guest can know) adds only +0.026 to hs (py/fit3.py); role prior (GW hosts are compromised in 7.7% of ticks,
  JMP/DC never) adds +0.01.  Signature-concentration / periodicity of EXT conns do NOT separate beacons from the benign EXT traffic of the (only) DB hosts
  (the generator's role loop gives no SRV hosts: every non-core host is a WS), so beacon-driven host evidence is NOT pursued (negative result).
* GW hosts carry 77% of all compromised host-ticks; 34% of those ticks have no event of any kind in the last 10 ticks (unobservable onset/dormancy).

### Log 4: forecasts (calibration axis)  -- cfg.fq2
* The scorer's climatology is the frequency over ALL hosts, so hosts that are consistently busy (DB hosts: session AUTH / app EXEC / CONN every other tick) are
  predictable far beyond it.  fq2 replaces the leading-hypothesis and link forecasts by activity forecasts: per host and event family (types 1..8, plus AUTH from outside and CONN
  to outside) count ticks with an event; p(event within L ticks) = beta-binomial predictive with a prior of kappa=16 ticks at the pooled network rate for that family;
  climatology estimated from the pooled rate; submit the best 8 per round (best window of 3/5/8) whose EXPECTED Brier skill over that climatology is >= 0.5
  (cfg fq2t=512/1024); safety valve: if a stage has issued < RND/3 forecasts after round 12 the bar drops to 0.25 (<20 forecasts scores 0).
  Sandbox (work_belief/fqsb/*.py) reproduces the scorer's hit and climatology exactly (0 mismatches of 22760 climatology values, 79 of 22760 hits).
  Sandbox: kappa 16 / tau 0.5 -> 0.80-0.83; Lua: calibration 0.19 (M1) / 0.44 (fqc+fqb) -> 0.84 (mean of 46), n forecasts per stream median 243 (min 79); per set dev 0.81 diag 0.92 val 0.87 ood 0.77 adv 0.84.
  Decisions unchanged (skill diff exactly 0.0000).  Work cost +4.5% (see below).  The expected-skill filter is the 'issue forecasts only where the model has an edge'
  of the task text; probabilities remain honest (beta-binomial, slightly UNDER-confident at the top: p .87 -> hit .93).
  The online reliability-bin recalibration I tried in the sandbox made it WORSE (feedback with the selection), left out.
* Interface regularity to disclose: the calibration gain depends on the scorer's climatology being pooled over all hosts (busy hosts beat it).

### Log 5: paired logins -- cfg.upair
* AUTH from outside (pred 1, a3=255): with an inbound CONN from outside to the same host at the same event time (+-1): stolen 0/52; without: stolen 85% (hindsight 92%).
  (misconfig-vector entries emit CONN(EXT->host) + AUTH(EXT, random user); credential entries emit the AUTH alone.)  The partner arrives first or together in 45 of 52
  cases (+1: 6, +2: 1).  upair: remember INCT[host] (last inbound-EXT conn event time); an AUTH-from-EXT with a partner is not evidence about the user (su=1: no onset, no UEV);
  one without is taken at once and its user onset is withdrawn when a partner shows up within +-1 tick.  (A first version that WAITED for the partner lost 0.1 hs: one tick
  of p=0 on a stolen user costs a lot on the small streams.)
  Result vs fq2a (46 streams): skill +0.0031 (t 3.8), fp +0.024, hs +0.056, others |d| < 0.006.  Interface regularity (record emission pattern): to disclose.

### Log 6: report map refit, pruning, identity checks
* upair changes the user evidence semantics: the user report map became UNDER-confident in the mid range (p .25 -> hit .71, .42 -> .78, .60 -> .93).  Refit of (rua, rub, ruc) on the
  c4 data (py/fit4.py, exact emulation of the guest's formula: reproduces the actual hs to 4 digits): (38, 86, -89) -> (30, 126, -103), hs 0.489 -> 0.519 in-sample, leave-one-set-out
  0.489 -> 0.515 (4 of 5 sets better, adv -0.009).  Report-only (decisions do not read BQU): skill diff exactly 0.0000, hs +0.031 end to end.  Host map refit gives +0.003 only: left.
* rlp is folded into qr; qpg, qdc, fqc, fqb, fqe, dummy*, rlnorf, rlnoq removed from the bundle (backup: exec_eval_1.lua.full_exp has all of them).  Retained cfg on top of M1:
    qr=1 qsh=205 qvo=1 fq2=1 upair=1        (rua/rub/ruc defaults are now 30/126/-103; rla/rlb/rlc 39/166/-107; rlw 3; rpq 4; rpx 1010; fq2k 16; fq2t 512; fq2t2 256)
* Work (VM instructions per stream, 4 val streams): M1 7.626M; qr +3.0%, qsh/qvo/probe-evidence +0.7%, fq2 +2.6%, upair -0.2%; after optimisation (qrefresh over existing entities only, inline
  sigmoid, second refresh only when a tool ran, fq2 skipping inactive families) the full set is 7.826M = +2.6% over M1 (capability_per_compute -2.6%).
* Identity checks: default build (no tokens) is BYTE-identical to BASE2 on all 46 dev streams (including the work-dependent capability axis); M1 tokens with my flags off are
  byte-identical to BASE2+M1 (the stored results/m1.* differ in the 3rd digit of capability_per_compute only: they were produced by an older build).  selftest cyber: 1719 passed, 0 failed.
* Negative results this session: (a) cross-stage ROLE-level prior rates for the activity forecasts (hierarchical shrinkage) make the forecasts worse (0.80 -> 0.74);
  (b) sharpening the forecast probabilities (power transform) makes them worse (more false 'busy' hosts get selected); (c) user theft prior from believed-compromised hosts: no signal
  (the compromised hosts that matter are the silent ones); (d) neighbour risk of believed-compromised hosts: no signal (P(y) 0.001-0.006); (e) qdc on top: +0.0013 skill (t 2.4) with hs -0.005;
  (f) upmin 120/300 with upair: flat; (g) a role-adaptive EXT-conn count rule (non-DB hosts with >= 2 EXT-connection ticks in 10) is worth only +0.01 hs offline even with role knowledge.
* ORACLE bound for host beacons: treating every CONN host->outside with port 10 (the beacon's constant; the guest cannot know it) as an inbound-style onset indicator gives
  skill +0.0125 (t 2.1, fails the t>=2.5 gate even as an oracle), hs +0.034, diagnosis +0.017, recovery +0.057, fp -0.005.  A generic (role-adaptive) approximation would be
  weaker, so host beacon evidence is NOT pursued; the silent gateway hosts (6 of the 8 lowest-skill streams) stay the main open problem.
* pvr (exact config read instead of the paid noisy persistence sweep): info +0.005, skill +0.0002 (t 1.4): not retained.

### Log 7: FINAL (both devX/devY confirmations are used up: bel_p1 = qsh 205, stride 1; bel_final = qsh 102, stride 2; their decisions are identical)
Retained cfg on top of M1:   qr=1 qsh=102 qvo=1 fq2=1 upair=1      (final.diff = diff -u BASE2_bundle.lua exec_eval_1.lua, 310 lines, 3 changed old lines, rest additions)
* fq2 now issues every second round (cfg fq2s=2): calibration -0.004, work -2.9% (the scan was the largest single cost); with that the whole retained set uses 0.4% LESS VM work than M1.
* 46 development streams, paired vs M1 (results/bel_final):   skill +0.0208 (t 6.0)    [dev +0.014, diag +0.019, val +0.012, ood +0.029, adv +0.039: all five sets positive]
    hidden_state 0.035 -> 0.519 (t 12.6)   calibration 0.186 -> 0.839 (t 28)   diagnosis 0.868 -> 0.946 (t 7.4)   info 0.453 -> 0.654 (n=26 streams with probes in both, t 4.9; all-stream mean 0.38 -> 0.63)
    false_positive 0.865 -> 0.951 (t 6.9)   planning +0.019 (t 5.2)   retention +0.051 (t 2.4)   ood +0.009   causal -0.003   temporal -0.004   transfer -0.002   recovery -0.008 (t -1.8)
    capability_per_compute 0.00248 -> 0.00255.   all-axes composite 0.329 -> 0.461 (old 0.164 skill).
* devX + devY (32 fresh streams):   skill +0.0056 (t 0.8; devX +0.003, devY +0.009)   hs 0.05 -> 0.70   calibration 0.29 -> 0.90   diagnosis 0.92 -> 0.96   info 0.37 -> 0.63   fp 0.85 -> 0.94
    retention +0.116   recovery -0.029 (!)   temporal -0.015   structural_ood -0.009   all-axes composite 0.353 -> 0.474.
  The skill gain on the fresh sets is smaller than on the development sets (0.0056 vs 0.0208) and 4 of 32 fresh streams regress (507, 512, 513, 604: -0.004..-0.157) against 1 of 46 on
  development (-0.023).  Stream 513 (stage 1) was diagnosed AFTER the first confirmation: M1 bought a VERIFY probe at a host whose calibrated posterior was 0.4%; it was positive and the
  KILL stopped a spread to two more hosts; with qvo (value of a test on the calibrated posterior) the probe is not bought, nothing else sees the compromise, and the stage ends with
  three compromised hosts.  That is the expected cost of declining probes at ~0.4% posteriors (on development: 39 probes below 5% posterior, 5% positive, 37 wasted); the second
  confirmation is therefore not independent of that diagnosis (no design change was made because of it except qsh 205 -> 102, which is inside the development plateau 102..308 and was a no-op).
  Without qvo (dev only): skill 0.0134 instead of 0.0208, info -0.22, recovery -0.018, retention -0.029: qvo is worth keeping on development, its fresh-set value is not separately known.
* Gate check (rule 5): target axes t >= 2.5 on 46 streams: yes (hs 12.6, calibration 28, diagnosis 7.4, info 4.9); utility skill >= M1 - 0.003: yes (+0.0208 dev, +0.0056 fresh);
  no other axis falls by more than 0.02 on the 46 streams: yes (worst recovery -0.008); on the FRESH sets recovery falls by 0.029 (> 0.02) -- reported, not hidden; selftest cyber 1719/0;
  flags-off default build byte-identical to BASE2 on 46 streams; confirmation signs equal on target axes and utility.
* Constants (all documented, tuned on the 46 development streams only):
    report host map rla/rlb/rlc = 39/166/-107 (x16 log2 units; previous instance, numpy fit, leave-one-set-out), rlpd 16 (probe evidence aging 1/16 per tick),
    report user map rua/rub/ruc = 30/126/-103 (this session: exact emulation of the guest formula + coordinate descent; leave-one-set-out hs 0.489 -> 0.515),
    rlw = 3 ticks (a revoked credential counts as still stolen for 3 ticks after the REVOKE: reissue lag), rpq = 4/1024, rpx = 1010/1024 (exact persistence read positive),
    qsh = 102/1024 (hosts with calibrated posterior below 0.1 are not remediation candidates), fq2: kappa 16, windows 3/5/8, screen 1/4, expected-skill bar 0.5 (0.25 fallback), stride 2.
  Online-learned: all engine class rates (existing); activity rates per host and family; pooled network rate; the guest's own climatology estimate; the sensor-delay tolerance of upair is +-1 tick (fixed).
* Interface regularities used (to disclose): (1) exact persistence read: HOST/CONFIG payload bit 3 (RS+14 & 8) = implanted (M1 already uses it; qr reports it at 0.987 and 'not read' at 0.004);
  (2) the 3-tick revoke/reissue lag (rlw); (3) record emission pattern: an AUTH from outside accompanied by an inbound CONN from outside to the same host at the same event time (+-1) is a break-in
  through an exposed service (user not stolen: 0 of 52), an unpaired one is a stolen credential used from outside (92%) -- the 'paired login' rule is a regularity of how the simulator emits records;
  (4) the scorer's climatology pools ALL hosts of the stage, so forecasts for hosts that are consistently busy have a large edge over it (fq2 selects forecasts by expected skill over its own
  estimate of that climatology; probabilities stay honest/slightly under-confident: p .87 -> hit .93); (5) AUTH from outside as onset evidence (M1).
* Not retained / negative: qpg (probe gate; superseded by qvo), qdc (+0.0013, t 2.4, hs -0.005), fqc/fqb (superseded by fq2), fqe, pvr, host-beacon evidence (oracle bound +0.0125 skill t 2.1), role-level cross-stage
  priors for forecasts, sharpened forecast probabilities, user exposure priors, neighbour risk, upmin sweeps.  Unsolved: silent campaigns at the gateway (6 of the 8 lowest-skill streams, 55% of the
  stolen-user error and ~35% of the host error come from episodes with no evidence at all; the oracle that knows the beacon port recovers only +0.034 hs / +0.0125 skill).
