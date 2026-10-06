FIRST HELD-OUT PASS (controller v1, guest image sha256 0d8889620da81f1f0a4dbcfc8b2164cb6545173e59c927052d9130aa714b2dbe)

These are the results of the first, single pass of the cyber controller over the held-out sets held (9001-9016) and heldB (9101-9116), plus
ablations on held/ood/adv, exactly as recorded before any change. They are kept unedited.

They exposed a defect in the controller's own temporal-link mechanism: on held, disabling it IMPROVED defensive skill by 0.134
(paired se 0.037) -- the 'explain-away' step cleared too many anomaly features (lateral, external, new-image evidence among them) of events
that merely resembled the consequence of a normal cause. The fix (clear only rare / off-profile / bulk features) was selected on the
DEVELOPMENT sets (dev, diag, val, ood, adv), after which held and heldB are no longer clean held-out sets for the revised controller.
The revised controller (v2) is therefore confirmed on a FRESH set, heldC (9201-9216), run once; see reports/cyber/v2_*.
