THIRD PASS (controller v3, guest image sha256 cf2f188d45424f719301a3d522f446683fdc4d19da8a6ae71d98fc7670cc73b5): first and only run on the
fresh held-out set heldD (9301-9316), with ablations on heldD / val / ood / adv, and budget variants. Kept unedited.
Some rows files for held / heldB / heldC / dev / diag / val were interrupted when the controller was revised again (v4) and are missing or partial.
What it showed on heldD (single pass, budget 4/4): defensive skill 0.531 vs OLD 0.241 (2.20x) and triage 0.278; geometric mean of the per-axis ratios
against OLD over the jointly supported axes with a positive denominator 1.55x (95% bootstrap CI 1.29-2.10): the 2x composite target is not met.
It also showed that the epistemic probing bonus (EXPLB = 40) made the controller over-probe (ablating tools or information gain IMPROVED utility on heldD,
ood and adv); a smaller bonus (20) was selected on the development sets, giving v4. heldD is therefore burned for v4; heldE (9401-9416) is the confirmation set.
