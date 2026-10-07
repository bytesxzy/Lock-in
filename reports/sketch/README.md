# `sketch.lua` — a sandboxed code workspace for the reasoning system

Everything here is part of the single bundle `exec_eval_1.lua` (modules `asi.sketch`, `asi.sketch.synth`, `asi.sketch.fix`, `asi.sketch.agent`, `asi.sketch.bench`, `asi.sketch.cli`).
Pure Lua 5.4: no model, no network, no subprocess. The full description is the `SKETCH WORKSPACE` section of the bundle's header; this file lists what is in this directory and how to reproduce it.

## What it is

The system gets **one file to write code in, `sketch.lua`, and a set of tools to work on it**. The tools are the only way in: the coding agent uses exactly the interface an operator uses
(`ws:call(tool, args)`), so every observation and every change is costed in deterministic integer units, checked against a policy (capabilities, file names, size limits, a total budget, a call
limit, sandbox limits), appended to a hash-chained audit log and replayable.

| tools | what they do |
|---|---|
| `list read check diff log help` | look at the file, its revisions and the audit trail |
| `append edit replace write` | change the file (`edit` = line ranges, `replace` = unique exact text; `write` replaces everything and costs more) |
| `run test` | execute a function / a table of cases in the sandbox (steps, memory and CPU limited, results copied out as plain data) |
| `snapshot rollback` | revision ring (a rollback is a new revision) |
| `synth fill repair` | reasoning tools that only **propose** code: synthesis from examples, completion of a sketch with holes, mutation repair of a failing function |
| `export` | write the stamped file to the path the operator configured (off by default; never a path the caller chooses) |

Status codes: 0 ok, 1 invalid, 2 denied, 3 quota, 4 the content failed (syntax error, failing test, text not found), 5 the sandbox stopped the program.

## Commands

```
lua exec_eval_1.lua sketch-new                       # create sketch.lua + sketch.ws (the audit state)
lua exec_eval_1.lua sketch-solve task.lua            # the coding agent writes a function for a task (examples -> code), tests it in the sandbox, logs every call
lua exec_eval_1.lua sketch-call edit --args '{from = 3, to = 3, text = "-- fixed"}'     # one metered, policy-checked tool call
lua exec_eval_1.lua sketch-show --log 5              # file, revision, last audit entries
lua exec_eval_1.lua sketch-replay                    # re-execute every logged call on a fresh workspace; every status, cost, digest and the chain head must reproduce
lua exec_eval_1.lua sketch-import                    # adopt an edit made outside the workspace (logged as an ordinary write)
lua exec_eval_1.lua sketch-bench --baseline --sketches      # the 54-task benchmark with the lookup-table and unpruned baselines, plus 6 sketches and 6 seeded bugs
lua exec_eval_1.lua selftest sketch                  # 219 checks (including 36 sandbox attack programs)
```

A task file is a data literal that is parsed, never executed: `{name = "f", params = {"xs"}, examples = {{args = {{1, 2}}, out = 3}, ...}, validate = {...}}` or
`{name = "f", sketch = "function f(x) ... HOLE_INT(x) ... end", cases = {...}}`.

## Files in this directory

* `BENCH.txt` — output of `sketch-bench --baseline --sketches` on the final bundle: 54 tasks (a few hand-picked examples each, 14 validation cases, 40 **hidden** cases the agent never sees).
  Program found for 52 tasks, accepted by the agent for 52, **correct on all 40 hidden cases for 51**, hidden-case accuracy 0.958, 1,428,832 candidates in total (about 67 s).
  Baselines: a lookup table of the training examples is right on 11.7% of the hidden cases; the same enumerator without observational equivalence finds a program for 51 of 54 tasks at the full
  budget (52 with it). At tighter per-task budgets (`BENCH_budgets.txt`, separate runs of `sketch-bench --synth-only --baseline --max-candidates N`): 47 vs 43 programs found at 20,000 candidates
  (with vs without observational equivalence), 51 vs 45 at 50,000 and 52 vs 51 at 200,000. Not solved: `odd_sq_sum` (two nested higher-order operations) and `sum_sq2` (`a*a + b*b`, not reached within the
  200,000-candidate budget). `all_pos` fits the validation cases and is wrong on 10 of 40 hidden cases (a coincidence of the arithmetic): validation is only as good as its cases.
  `fill` completed 4 of 6 sketches (`sign_s` and `collatz` are out of reach). `repair` fixed 5 of 6 seeded bugs against the visible tests; four are right on all hidden cases, `count_big` on 35 of 40;
  the sixth bug (`is_between`) is not exposed by the 10 random tests, so nothing is repaired (38 of 40 hidden cases).
* `example/` — a workspace written **by the coding agent** (no human edits): `sketch.lua` (27 functions, 120 lines, revision 32, stamped with its digest and chain head), `sketch.ws` (the saved
  workspace: policy, revision ring and the audit log of 220 tool calls), the `task_*.lua` files it was given and `order.txt` (the order they were solved in).
  Verify: `cd example && lua ../../../exec_eval_1.lua sketch-replay --dir .` prints `replay of 220 logged calls: every status, cost, result digest and the chain head reproduce` and
  `sketch.lua: stamp, digest and chain head match`.

## Limits (all measured or structural, none hidden)

* The DSL has **no loops and no recursion** (list combinators `map filter countby fold any all` over enumerated lambdas replace them), so tasks like gcd or digit sums are out of reach.
* Examples are a weak specification. A program that fits a handful of examples can be a coincidence; counter-example refinement, validation cases and hidden cases are how this is measured.
* `fill` handles at most 3 integer / boolean holes; `repair` makes single-token edits (and pairs of them) and is only as good as the tests it is given.
* The sandbox is **in-process** (a fresh environment, a per-instruction hook for steps / memory / CPU, size-checked string builders, a restricted string metatable, limit sentinels that `pcall`
  cannot swallow). It is not an operating-system boundary; the memory limit reads the interpreter's counter and the CPU safety net uses `os.clock`, so outcomes at the very edge of a limit can
  vary between machines. Everything else is deterministic.
* This is a program synthesiser and a tool-using agent over a small typed language, not a general-purpose code generator: it has no natural-language understanding and no way to write arbitrary Lua.
