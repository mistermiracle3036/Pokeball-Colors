-- Pokeball Colors
--
-- Under COLORS = ADVANCED (PaletteFX.mode "redpp"), every ball toss,
-- ball shake, and the resting caught ball render in that ball's own
-- colors instead of the SGB zone palette under the sprite.
--
-- How (all verified against engine source, gen1recomp-dev):
--   * BattleState:animSpriteColors(s, px, py) is the single funnel that
--     resolves colors for every anim-layer OAM sprite (BattleState.lua
--     ~5228; drawAnimLayer builds its colorFn from it, for both the
--     playing animation and the resting lockedBall).  We wrap it.
--   * Ball toss tiles run under rOBP0: s.obp == "f0", or "f0x" while
--     DoBallTossSpecialEffects has the palette complemented (the
--     Master/Ultra flicker).  Under the f0 shade map ({0,3,3}) the
--     sprite has exactly two effective slots: DMG color 1 -> lightest
--     shade (ball body), colors 2/3 -> darkest (outline/band).  So a
--     ball color is a { light, dark } pair; on "f0x" blocks we swap the
--     pair, which keeps the flicker in the ball's own colors.
--   * Which ball is in flight: toss rows carry opts.ball into
--     AnimPlayer:start (BattleState.lua ~1188), and
--     BattleState:ballChain(tossAnim, caught, shakes, ball) sees the
--     ball for the whole toss/poof/shake chain (~4502) -- SHAKE_ANIM
--     rows carry shakes but not the ball, so we remember it from the
--     chain.  Both trackers below feed the wrap.
--   * The balls registry schema (src/mods/Schemas.lua R.balls) is
--     strictly validated and has NO color field, so colors live here,
--     keyed by item id.  mod.exports.colors is the table itself: other
--     mods can add entries for their own balls (e.g. a snag ball).
--
-- Untouched on purpose: POOF clouds (ambient zone colors, like vanilla),
-- every non-ball animation, all color modes other than ADVANCED
-- (animSpriteColors returns nil in the mono modes and we pass that
-- through), and the GEN1/MODERN catch math (pure cosmetics).

return function(mod)
  local VERSION = "0.1.14"
  mod.exports.version = VERSION

  mod.options:define({
    { key = "enabled", type = "toggle",
      label = "Colored balls (ADVANCED mode)", default = true },
    { key = "snag_ball_color", type = "toggle",
      label = "Rocket-colored SNAG BALL", default = true },
    { key = "center_balls", type = "toggle",
      label = "Colored balls at POKeMON CENTER", default = true },
  })

  local PaletteFX = require("src.render.PaletteFX")
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")

  -- { body = the ball's main color, accent = its smaller highlight },
  -- 0-255 RGB.  CONFIRMED from a 0.1.0 capture: under the f0 shade map
  -- the ball sprite's BODY is DMG colors 2/3 (the "dark" slot -- about
  -- 2x the pixel area) and the accent is color 1, i.e. the opposite of
  -- what 0.1.0 assumed.  So `body` goes to slots 2/3 and `accent` to
  -- slot 1.  Native colors follow the series art; the nine
  -- custom_pokeballs colors were sampled from that mod's own
  -- assets/balls/*.png.
  local COLORS = {
    -- native
    POKE_BALL   = { body = { 224,  72,  56 }, accent = { 248, 216, 208 } },
    GREAT_BALL  = { body = {  56, 112, 216 }, accent = { 208, 224, 248 } },
    ULTRA_BALL  = { body = { 232, 192,  40 }, accent = {  40,  40,  40 } },
    MASTER_BALL = { body = { 152,  72, 200 }, accent = { 232, 200, 248 } },
    SAFARI_BALL = { body = { 112, 160,  72 }, accent = { 224, 232, 200 } },
    -- custom_pokeballs (harmless entries if that mod is absent)
    QUICK_BALL  = { body = { 232, 216,  56 }, accent = {  40,  88, 168 } },
    TIMER_BALL  = { body = { 232, 232, 232 }, accent = { 192,  56,  48 } },
    NET_BALL    = { body = {  80, 176, 168 }, accent = { 216, 240, 236 } },
    DUSK_BALL   = { body = {  64,  88,  64 }, accent = { 200, 160,  48 } },
    HEAVY_BALL  = { body = { 144, 152, 160 }, accent = {  48,  56,  64 } },
    REPEAT_BALL = { body = { 224, 104,  56 }, accent = { 240, 224, 128 } },
    DREAM_BALL  = { body = { 232, 152, 192 }, accent = { 248, 224, 232 } },
    LEVEL_BALL  = { body = { 224, 184,  72 }, accent = {  48,  40,  32 } },
    DIVE_BALL   = { body = {  88, 152, 224 }, accent = { 216, 240, 248 } },
  }
  mod.exports.colors = COLORS

  -- What this mod owns, for other mods to check before touching
  -- anything (see the ownership note in the README):
  --   colors           -- the color table and the rendering
  --   caughtBallField  -- mon.caughtBall, written at catch time.  Other
  --                       mods may READ it freely (a ribbon for balls
  --                       caught in X, etc); do not write it.  Absent on
  --                       mons caught before 0.1.12 or with this mod
  --                       uninstalled, so always nil-check it.
  mod.exports.owns = { colors = true, caughtBallField = "mon.caughtBall" }

  -- ------------------------------------------------------------------
  -- Public registration API for other ball mods.
  --
  --   local pbc = mod.find("pokeball_colors")
  --   if pbc then pbc.exports.registerColors({
  --     MY_BALL = { body = {r,g,b}, accent = {r,g,b} },
  --   }) end
  --
  -- Owns the only-if-absent rule so callers cannot get it wrong: a key
  -- already present (a user override, or another mod that got there
  -- first) is never overwritten.  Safe to call at any time -- colors are
  -- read at draw time -- though game.ready is the conventional spot.
  -- Returns added, skipped.
  -- ------------------------------------------------------------------
  -- A color entry is OPAQUE past the keys validated here.  Anything else
  -- a caller puts on it (their own bookkeeping, a future key this mod
  -- does not know yet) is stored untouched and never rejected, so a
  -- newer caller keeps working against an older copy of this mod.  By
  -- the same rule an RGB list is checked for AT LEAST three numbers, not
  -- exactly three -- a fourth element (alpha, say) is the caller's
  -- business and only the first three are ever read.
  local function validColor(c)
    if type(c) ~= "table" then return false end
    for _, k in ipairs({ "body", "accent" }) do
      local v = c[k]
      if type(v) ~= "table" or #v < 3 then return false end
      for i = 1, 3 do
        if type(v[i]) ~= "number" then return false end
      end
    end
    return true
  end

  mod.exports.registerColors = function(colors)
    if type(colors) ~= "table" then
      mod.log:warn("registerColors: expected a table of id -> color")
      return 0, 0
    end
    local added, skipped = 0, 0
    for id, c in pairs(colors) do
      if type(id) ~= "string" or not validColor(c) then
        mod.log:warn("registerColors: bad entry for %s "
          .. "(need { body = {r,g,b}, accent = {r,g,b} })", tostring(id))
        skipped = skipped + 1
      elseif COLORS[id] ~= nil then
        skipped = skipped + 1          -- already set: never clobber
      else
        COLORS[id] = c
        added = added + 1
      end
    end
    if added > 0 then
      mod.log:info("registerColors: added %d ball color(s)", added)
    end
    return added, skipped
  end

  -- One warning per unknown ball id actually seen on screen, so a mod
  -- author whose ball renders in vanilla colors gets a reason instead of
  -- silence.  Seen-set, so this never spams per frame.
  local warnedMissing = {}
  local function warnMissingColor(ball)
    if ball and not warnedMissing[ball] then
      warnedMissing[ball] = true
      mod.log:warn("no color registered for ball %s -- it renders in "
        .. "vanilla colors. Its mod can call "
        .. "mod.find(\"pokeball_colors\").exports.registerColors{...}",
        tostring(ball))
    end
  end

  -- SNAG_BALL is deliberately absent above.  Snag Quest (>= 0.11.x) owns
  -- the whole SNAG_BALL record -- tossAnim, flicker AND its color -- and
  -- registers that color into this table on game.ready, only when the key
  -- is absent.  Since exports.colors IS this table and the wrap below
  -- reads it at draw time, their entry applies with no work here.
  --
  -- DO NOT re-add a SNAG_BALL entry and DO NOT patch that ball's record:
  -- check mod.find("snag_quest").exports.owns before touching any field
  -- on it.  Two mods writing one registry field is a silent
  -- last-writer-wins conflict (registry ops FOLD -- src/mods/Registry.lua)
  -- that only shows up as a player noticing the wrong animation.

  -- anims that are part of a ball chain but don't carry the ball id
  -- themselves; the ballChain tracker supplies it for these
  local BALL_MOVES = {
    TOSS_ANIM = true, GREATTOSS_ANIM = true, ULTRATOSS_ANIM = true,
    SHAKE_ANIM = true,
  }

  local function norm(c)
    return { c[1] / 255, c[2] / 255, c[3] / 255 }
  end

  -- ------------------------------------------------------------------
  -- tracker 1: what the AnimPlayer is playing right now (toss rows
  -- carry opts.ball; every start overwrites both fields, so nothing
  -- goes stale between rows)
  -- ------------------------------------------------------------------
  AnimPlayer._pbcOriginals = AnimPlayer._pbcOriginals
    or { start = AnimPlayer.start }
  local vanillaStart = AnimPlayer._pbcOriginals.start
  AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts)
    self._pbcMove = moveId
    self._pbcBall = opts and opts.ball or nil
    return vanillaStart(self, moveId, attackerIsPlayer, opts)
  end

  -- ------------------------------------------------------------------
  -- tracker 2: the ball of the current toss chain (covers the SHAKE
  -- rows and the resting lockedBall, which never see opts.ball)
  -- ------------------------------------------------------------------
  BattleState._pbcOriginals = BattleState._pbcOriginals or {
    ballChain = BattleState.ballChain,
    animSpriteColors = BattleState.animSpriteColors,
  }
  local vanillaBallChain = BattleState._pbcOriginals.ballChain
  BattleState.ballChain = function(self, tossAnim, caught, shakes, ball)
    self._pbcBall = ball
    return vanillaBallChain(self, tossAnim, caught, shakes, ball)
  end

  -- ------------------------------------------------------------------
  -- the wrap: recolor ball sprites, pass everything else through
  -- ------------------------------------------------------------------
  local vanillaColors = BattleState._pbcOriginals.animSpriteColors
  BattleState.animSpriteColors = function(self, s, px, py)
    local out = vanillaColors(self, s, px, py)
    if not out then return out end                    -- mono modes / no zone
    if PaletteFX.mode ~= "redpp" then return out end  -- ADVANCED only
    if not mod.options:get("enabled") then return out end
    -- ball toss/shake tiles run under rOBP0 ("f0"/"f0x"); leave rOBP1
    -- and ambient-e4 sprites (move anims, emitters) alone
    if s.obp ~= "f0" and s.obp ~= "f0x" then return out end

    local ap = self.animPlayer
    local ball
    if self.animPlaying and ap then
      ball = ap._pbcBall
        or (ap._pbcMove and BALL_MOVES[ap._pbcMove] and self._pbcBall)
        or nil
    elseif ap and self.lockedBall then
      -- the resting closed ball through the caught text
      ball = self._pbcBall
    end

    if ball == "SNAG_BALL" and not mod.options:get("snag_ball_color") then
      return out
    end
    local c = ball and COLORS[ball]
    if not c then
      if ball then warnMissingColor(ball) end
      return out
    end

    local accent, body = norm(c.accent), norm(c.body)
    if s.obp == "f0x" then
      -- DoBallTossSpecialEffects has rOBP0 complemented this block:
      -- keep the flicker, in the ball's own colors
      accent, body = body, accent
    end
    -- f0 shade map slots: DMG color 1 -> slot 1, colors 2/3 -> slots 2/3.
    -- The body region is colors 2/3 (confirmed 0.1.0), so it goes last.
    return { accent, body, body }
  end

  -- Log who owns what, so "which mod colored this ball" is answerable
  -- from the load log instead of by experiment.
  local snag = mod.find("snag_quest")
  if snag then
    local owns = snag.exports and snag.exports.owns
    mod.log:info("pokeball_colors: snag_quest %s present; owns=%s",
      tostring(snag.version),
      owns and "declared (SNAG_BALL deferred to it)" or "not declared")
  end

  -- ------------------------------------------------------------------
  -- Pokemon Center heal machine: each lit ball in the machine renders
  -- in the colors of the ball that mon was actually caught in.
  --
  -- The engine does not record a mon's caught ball anywhere (grepped
  -- 0.1.75), so we do: pokemon.caught fires with the live mon table and
  -- the ball id (BattleState.lua:4470), and arbitrary mon fields
  -- persist through save/load (SaveSerializer is a generic recursive
  -- dump; precedent: snag_quest's mon.snagged).  Mons caught before
  -- this version installed have no field and default to POKE_BALL --
  -- canon enough, and self-corrects as the party turns over.
  -- ------------------------------------------------------------------
  mod.events:on("pokemon.caught", function(p)
    if p and p.mon and p.ball and p.mon.caughtBall == nil then
      p.mon.caughtBall = p.ball
    end
  end)

  local gameRef
  mod.events:on("game.ready", function(p) gameRef = p and p.game end)

  -- ------------------------------------------------------------------
  -- The draw seam.  fxHeal is a LOCAL closure inside
  -- OverworldState:drawWorld (OverworldController.lua:4522), so it
  -- cannot be wrapped, and drawWorld push/pops transforms internally so
  -- drawing after it returns lands in the wrong space.  Instead: wrap
  -- drawWorld, and ONLY while self.healAnim exists, temporarily shim
  -- love.graphics.draw.  The shim recognizes the ball draws exactly --
  -- image == self.healMachineImg AND quad == self.healMachineQuads[2]
  -- (the ball quad; [1] is the monitor) -- counts them, and the i-th
  -- ball is party slot i (stepHealAnim lights balls in party order).
  -- Around just those draws it applies a PaletteFX palette built from
  -- our color table, exactly the mechanism the machine's own jingle
  -- flash uses (fxHeal sends permuted GRAYS through the same shader).
  --
  -- The shim exists only for the few seconds the heal anim runs, and is
  -- restored via pcall even if vanilla throws.
  --
  -- Shade-slot mapping (TODO/CONFIRM on first screenshot): assumed
  -- shade0 = white highlight (kept), shade1 = accent, shade2 = body,
  -- shade3 = dark outline (body darkened).  If balls come out inverted,
  -- swap accent/body here -- same fix as battle 0.1.0 -> 0.1.1.
  -- ------------------------------------------------------------------
  local OverworldState = require("src.world.OverworldController")

  -- copy of the machine's flash beat map (a local in OverworldController:
  -- FlashSprite8Times swaps the two middle shades in place)
  local HEAL_FLASH_MAP = { [0] = 0, [1] = 2, [2] = 1, [3] = 3 }

  local function ballPalette(c, flashed)
    local dark = { math.floor(c.body[1] * 0.35),
                   math.floor(c.body[2] * 0.35),
                   math.floor(c.body[3] * 0.35) }
    local pal = { PaletteFX.GRAYS[1], c.accent, c.body, dark }
    if flashed then pal = PaletteFX.permute(pal, HEAL_FLASH_MAP) end
    return pal
  end

  OverworldState._pbcOriginals = OverworldState._pbcOriginals
    or { drawWorld = OverworldState.drawWorld }
  local vanillaDrawWorld = OverworldState._pbcOriginals.drawWorld
  OverworldState.drawWorld = function(self, ...)
    local ha = self.healAnim
    if not (ha and PaletteFX.mode == "redpp"
            and mod.options:get("enabled")
            and mod.options:get("center_balls")) then
      return vanillaDrawWorld(self, ...)
    end

    local lg = love.graphics
    local vanillaDraw = lg.draw
    local ballIndex = 0
    lg.draw = function(img, quad, ...)
      if img ~= nil and img == self.healMachineImg
         and self.healMachineQuads and quad == self.healMachineQuads[2] then
        ballIndex = ballIndex + 1
        local party = gameRef and gameRef.save and gameRef.save.party
        local mon = party and party[ballIndex]
        local ball = (mon and mon.caughtBall) or "POKE_BALL"
        local c = COLORS[ball]
        if not c then warnMissingColor(ball) end
        if c then
          local sh = PaletteFX.shader()
          if sh then
            local prev = lg.getShader()
            PaletteFX.sendColors(sh, ballPalette(c, not ha.visible))
            lg.setShader(sh)
            vanillaDraw(img, quad, ...)
            lg.setShader(prev)
            return
          end
        end
      end
      return vanillaDraw(img, quad, ...)
    end

    local ok, err = pcall(vanillaDrawWorld, self, ...)
    lg.draw = vanillaDraw
    if not ok then error(err) end
  end

  mod.log:info("pokeball_colors %s loaded", VERSION)
end
