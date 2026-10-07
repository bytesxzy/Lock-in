-- Reproduction of the stage collision in the frozen temporal scorer (E.score, "5 temporal reconstruction").
--   Env:packet stores every delivered record in ONE table per stream:   s.rec_by_seq[rec.seq] = rec
--   but W.new sets nseq = 1, so `seq` restarts at 1 in every stage.  E.score then resolves delivered records and submitted timeline entries with s.rec_by_seq[seq],
--   which for stages 1-3 returns the record that a LATER stage delivered under the same number (normally stage 4's).
-- This script runs streams, captures every delivered record under its true key (stage, seq), and prints per stage
--   * how many delivered records are resolved to a different record by the shipped lookup, and how many of those change the chain label,
--   * the temporal score exactly as E.score computes it (shipped lookup, "frozen") and the same formula with (stage, seq) keys ("truth"), tick-weighted per stage.
-- Nothing in the scorer or the controller is modified; the controller never sees any of this.
-- usage: BUNDLE=/path/to/bundle.lua lua scorer_defect.lua SET [first last] [cfg tokens: key=int | flag]      (run from a directory next to load.lua; here: work_timeline)
dofile("../load.lua")
local G = require("asi.cyber.guest")
local E = require("asi.cyber.eval")
local Env = require("asi.cyber.env")
local cfg = {}
local set = arg[1]
local lo, hi = tonumber(arg[2]) or 1, tonumber(arg[3]) or 99
local first = (tonumber(arg[2]) ~= nil) and 4 or 2
for i = first, #arg do local k, v = arg[i]:match("^([%w_]+)=(-?%d+)$"); if k then cfg[k] = tonumber(v) else cfg[arg[i]] = true end end
local art = G.build(cfg)
local S = {}   -- per stage accumulators
for st = 1, 4 do S[st] = {deliv = 0, collide = 0, flip = 0, fsum = 0, fn = 0, tsum = 0, tn = 0} end
for si, seed in ipairs(Env.seeds(set)) do if si >= lo and si <= hi then
  local recs = {}
  local row, env = E.run(art, {seed = seed, set = set, kind = "new", variant = "cand", on_env = function(env)
    local exec = env.exec
    env.exec = function(self, vm, idx, ...)
      local r1, r2 = exec(self, vm, idx, ...)
      if idx == 1 then       -- CSENSE: the records delivered so far in this stage are in s.rec_by_seq under their stage-local seq (a later stage overwrites them)
        local s = self.s
        recs[s.stage] = recs[s.stage] or {}
        for _, d in ipairs(s.delivered) do if d.stage == s.stage and not recs[s.stage][d.seq] then recs[s.stage][d.seq] = s.rec_by_seq[d.seq] end end
      end
      return r1, r2
    end
  end})
  local s = env.s
  -- 1. how often does the shipped lookup return another record?
  for st = 1, 4 do for q, rec in pairs(recs[st] or {}) do
    S[st].deliv = S[st].deliv + 1
    local looked = s.rec_by_seq[q]
    if looked ~= rec then
      S[st].collide = S[st].collide + 1
      if (looked and looked.chain or false) ~= (rec.chain or false) then S[st].flip = S[st].flip + 1 end
    end
  end end
  -- 2. the temporal score of E.score, with the shipped lookup (frozen) and with (stage, seq) keys (truth)
  local function lookup_frozen(stage, q) return s.rec_by_seq[q] end
  local function lookup_truth(stage, q) return recs[stage] and recs[stage][q] end
  for _, mode in ipairs({"frozen", "truth"}) do
    local lk = (mode == "frozen") and lookup_frozen or lookup_truth
    local chainby = {}
    for _, d in ipairs(s.delivered) do
      local rec = lk(d.stage, d.seq)
      if rec and rec.chain then chainby[d.stage] = chainby[d.stage] or {}; chainby[d.stage][d.t] = (chainby[d.stage][d.t] or 0) + 1 end
    end
    for gt = 1, 192 do
      local r = s.reports[gt]
      if r then
        local live = 0
        for tt = r.t - 12, r.t do live = live + ((chainby[r.stage] or {})[tt] or 0) end
        if live >= 2 then
          local seqs = {}
          for i = 0, 7 do local q = r.words[9 + i]; if q and q ~= 0 then seqs[#seqs + 1] = q end end
          local good, ordered, pairs_ = 0, 0, 0
          for i, q in ipairs(seqs) do
            local rec = lk(r.stage, q)
            if rec and rec.chain then good = good + 1 end
            if i > 1 then
              local pr_ = lk(r.stage, seqs[i - 1])
              if rec and pr_ then pairs_ = pairs_ + 1; if rec.true_id and pr_.true_id and rec.true_id >= pr_.true_id then ordered = ordered + 1 end end
            end
          end
          local prec = (#seqs > 0) and good / #seqs or 0
          local ord = (pairs_ > 0) and ordered / pairs_ or ((#seqs > 0) and 1 or 0)
          local v = prec * ord * math.min(1, #seqs / math.min(8, live))
          local a = S[r.stage]
          if mode == "frozen" then a.fsum = a.fsum + v; a.fn = a.fn + 1 else a.tsum = a.tsum + v; a.tn = a.tn + 1 end
        end
      end
    end
  end
end end
for st = 1, 4 do
  local a = S[st]
  print(string.format("stage %d  delivered %6d  resolved to another record %6d (%.1f%%)  chain label flipped %5d | scored ticks frozen %4d truth %4d | frozen score sum %.3f %d  truth score sum %.3f %d",
    st, a.deliv, a.collide, 100 * a.collide / math.max(1, a.deliv), a.flip, a.fn, a.tn, a.fsum, a.fn, a.tsum, a.tn))
end
