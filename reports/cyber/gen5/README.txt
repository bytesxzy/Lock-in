Generation 5 (the default controller after the round-1/2 upgrade).  In these files the variant "new" is generation 5 (G.build({})) and "gen4" is the generation-4 controller (G.build({legacy_defaults = true})).
In reports/cyber/final/ the variant "new" is generation 4 (the previous final controller).

  new_heldF.lua / new_heldF.txt   the single confirmation run on heldF (16 streams) at work budgets 1/4, 2/4, 4/4 of the frozen budget
  report_heldF.txt                the paired report: ../baselines_heldF.lua (passive, triage, sweeper, OLD recorded BEFORE the run) + new_heldF.lua
  Reproduce:  lua exec_eval_1.lua cyber-eval --set heldF --variants new,gen4 --budgets 1,2,4 --save new_heldF.lua --summary
              lua exec_eval_1.lua cyber-report ../baselines_heldF.lua new_heldF.lua
