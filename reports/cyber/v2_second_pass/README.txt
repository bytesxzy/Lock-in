SECOND PASS (controller v2, guest image sha256 ddd017290cb1762614a3fb232b4470ca82abb35c3f471eceeef499a481cde742): first run of the revised
controller on the FRESH held-out set heldC (9201-9216) plus re-runs on the other sets. Kept unedited.
Defects it exposed in v2, both in the controller (not the benchmark):
  * 9208: the controller exceeded the per-round tool allowance (4-6 'tool denied' violations per stream)
  * 9216 at 1/4 of the work budget: the stream was cut off by the work limit (skill 0 by the scoring rule)
  * the reported persistence beliefs were systematically overconfident, so hidden_state_inference averaged exactly 0 on heldC
They were fixed (tool guard in c_tool, predictive compute pacing in c_meta, persistence report shrink) and checked on the development sets.
heldC is therefore no longer clean for the revised controller (v3); the confirmation set for v3 is heldD (9301-9316), run once.
