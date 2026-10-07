-- Extended twin-world noninterference test (audit "cheat"): the unchanged final controller (G.build({}), all generation-5 defaults) is run on two worlds that differ in a HIDDEN fact
-- chosen to be one that a new mechanism (fq2, upair, tlsel, qr, the exact persistence read, the revoke window, the scan/expo/beacon rules) could only react to by LEAKING;
-- the sequence of everything the controller emits (tool requests, actions, reports with forecasts and timeline) must be identical up to the first world message that differs.
-- usage: BUNDLE=... lua twin_ext.lua
dofile((arg[0]:match("^(.*)/[^/]*$") or ".") .. "/loadb.lua")
local U = require("asi.util")
local E = require("asi.cyber.eval")
local Env = require("asi.cyber.env")
local G = require("asi.cyber.guest")
local W = require("asi.cyber.world")
local art = G.build({})
local function logged(seed, set, twin, nstages, rounds, hook)
  local log = {}
  local function snap(vm, a, n) local h = 1469598103934665603; for i = 0, n - 1 do local v = vm:mread(a + i); h = (h ~ (math.type(v) == "integer" and v or -7)) * 1099511628211 end return tostring(h) end
  E.run(art, {seed = seed, set = set, kind = "new", limit_stages = nstages, rounds = rounds, twin = twin, on_env = function(env)
    if hook then hook(env) end
    local orig = env.exec
    env.exec = function(self, vm, idx, rd, ra, rb, imm, t)
      local r = vm.r
      local a_, b_ = r[ra], r[rb]
      local gin = (idx == 2) and snap(vm, a_, 4) or (idx == 3) and snap(vm, a_, 3) or (idx == 4) and snap(vm, a_, 64) or "-"
      log[#log + 1] = {"g", idx .. gin}
      local c, d = orig(self, vm, idx, rd, ra, rb, imm, t)
      local out = (idx == 1) and snap(vm, a_, 120) or (idx == 2) and snap(vm, b_, 32) or tostring(r[rd])
      log[#log + 1] = {"w", idx .. out}
      return c, d
    end
  end})
  return log
end
local function firstdiff(a, b)
  for i = 1, math.min(#a, #b) do if a[i][2] ~= b[i][2] then return i end end
  if #a ~= #b then return math.min(#a, #b) + 1 end
  return nil
end
local seeds = {}
for x in (os.getenv("SEEDS") or "1 2 3 5 7 9"):gmatch("%d+") do seeds[#seeds + 1] = tonumber(x) end
local NST = tonumber(os.getenv("NST") or "2")
local ROUNDS = tonumber(os.getenv("ROUNDS") or "30")
local total, leaks, vacuous, identical = 0, 0, 0, 0
local rows = {}
local function report(name, seed, a, b)
  total = total + 1
  local first = firstdiff(a, b)
  if not first then identical = identical + 1; rows[#rows + 1] = string.format("%-34s seed %-3d IDENTICAL whole run (%d messages)", name, seed, #a); return end
  local who = (a[first] and a[first][1]) or (b[first] and b[first][1])
  if who == "g" then leaks = leaks + 1 end
  rows[#rows + 1] = string.format("%-34s seed %-3d first difference at message %d of %d produced by %s%s", name, seed, first, #a, who == "w" and "the WORLD" or "THE GUEST (LEAK)", "")
end
for _, seed in ipairs(seeds) do
  local S = Env.Stream.new{seed = seed, set = "dev"}.specs
  local base = logged(seed, "dev", nil, NST, ROUNDS)
  local nonprot = nil
  for h = 0, S[1].nh - 1 do if not S[1].prot[h] and h ~= S[1].dc then nonprot = h; break end end
  local perturb = {
    {"persist+autostart bit (exact read)", function(w, k) if k == 1 then local ho = w.host[nonprot]; ho.persist = true; ho.cfg = ho.cfg | 8; ho.respawn = 18 end end},
    {"persist+autostart, stage 2", function(w, k) if k == 2 then local ho = w.host[nonprot]; ho.persist = true; ho.cfg = ho.cfg | 8; ho.respawn = 18 end end},
    {"stolen user 3 (credential audit)", function(w, k) if k == 1 then w.user[math.min(3, S[1].nu - 1)].stolen = true end end},
    {"exposure bits on a host (expo/scan)", function(w, k) if k == 1 then w.host[nonprot].cfg = w.host[nonprot].cfg | 3 end end},
    {"campaign 1 start +5", function(w, k) if k == 1 and w.camps[1] then w.camps[1].start = w.camps[1].start + 5; w.camps[1].next_t = w.camps[1].start end end},
    {"campaign 1 vector -> exploit/cred", function(w, k) if k == 1 and w.camps[1] then local c = w.camps[1]; c.vec = (c.vec == "cred") and "misconfig" or "cred"; if c.vec == "cred" then c.host = S[1].gw; c.user = 0 end end end},
    {"campaign 1 beacon period 3<->6", function(w, k) if k == 1 and w.camps[1] then w.camps[1].beacon = (w.camps[1].beacon == 3) and 6 or 3 end end},
    {"campaign 1 stealth 99", function(w, k) if k == 1 and w.camps[1] then w.camps[1].stealth = 99 end end},
    {"all hosts blind (sensor coverage)", function(w, k) if k == 1 then for h = 0, S[1].nh - 1 do w.host[h].agent = false end end end},
    {"revoked-user lag state", function(w, k) if k == 1 then w.user[0].stolen = true; w.user[0].revoked = true; w.user[0].reissue_t = 5 end end},
    {"ghost flag (no channel)", function(w, k) if k == 1 then w.host[0].ghost = true end end},
  }
  for _, p in ipairs(perturb) do
    if nonprot then
      local log = logged(seed, "dev", p[2], NST, ROUNDS)
      report(p[1], seed, base, log)
    end
  end
  -- scorer-only labels randomised: chain / decoy / true_id / fake flags of every record (never put on the wire)
  local log = logged(seed, "dev", nil, NST, ROUNDS, function(env)
    local s = env.s
    local pb = s.pop_batch
    local n = 0
    s.pop_batch = function(self)
      local out = pb(self)
      for _, rec in ipairs(out) do n = n + 1; rec.chain = (n % 3 == 0) or nil; rec.decoy = (n % 5 == 0) or nil; rec.true_id = (n * 7919) % 1000; rec.fake = (n % 7 == 0) or nil end
      return out
    end
  end)
  report("scorer labels randomised", seed, base, log)
  -- the set label (dev vs val vs held share the generator parameters): same world, different label
  for _, lab in ipairs({"val", "diag", "held"}) do
    local lg = logged(seed, lab, nil, NST, ROUNDS)
    report("set label " .. lab .. " (same world)", seed, base, lg)
  end
end
for _, r in ipairs(rows) do print(r) end
print(string.format("TOTAL %d twin runs: %d identical whole-run, %d first-difference-by-world, %d GUEST-PRODUCED first differences (leaks)", total, identical, total - identical - leaks, leaks))
