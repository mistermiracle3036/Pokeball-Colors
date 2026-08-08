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
  local VERSION = "0.1.8"
  mod.exports.version = VERSION

  mod.options:define({
    { key = "enabled", type = "toggle",
      label = "Colored balls (ADVANCED mode)", default = true },
    { key = "snag_ball_color", type = "toggle",
      label = "Rocket-colored SNAG BALL", default = true },
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
  mod.exports.owns = { colors = true }  -- this mod owns COLOR only

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
    if not c then return out end

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

  mod.log:info("pokeball_colors %s loaded", VERSION)
end
