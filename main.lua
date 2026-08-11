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
--     Master/Ultra flicker).  Vanilla's f0 shade map ({0,3,3}) collapses
--     DMG colors 2 and 3 onto one shade, so on hardware the ball is
--     two-tone; the wrap REPLACES the whole return, so it is not bound by
--     that map and can hand back three distinct colors (see the third
--     color note below).  On "f0x" blocks we swap the light/dark pair,
--     which keeps the flicker in the ball's own colors.
--
-- The third color (0.1.15).  Verified by reading the generated tilesheet
-- pixels, not assumed: the ball tiles use ALL THREE opaque DMG indices --
-- 1 = bottom crescent + center dot, 2 = upper body mass, 3 = perimeter
-- outline ring.  So a third region has always been there; what the
-- developer actually wants coloured (a band along the crescent seam, as
-- on a real Poke Ball) is NOT that region -- those pixels are index 2,
-- indistinguishable from the body.
--
-- So an optional `line` color comes with re-indexed art: a copy of the
-- generated sheet in which, for the six ball tiles only, the seam pixels
-- become index 3 and the outline ring becomes index 2.  Rendered with
-- { accent, body, line } that is exactly the band; rendered with
-- { accent, body, body } it is pixel-identical to vanilla, which is why
-- balls with no `line` never touch it.  The copy is REBUILT AT RUNTIME
-- from the player's own extracted sheet -- no ROM-derived art is shipped
-- in this repo (see BAND_TILES).
--
-- The substitution is deliberately made at AnimPlayer:sheetImage rather
-- than by patching the battle_anims registry.  A `tilesheet:0` patch
-- would be global -- every mode, and every other animation drawing from
-- tileset 0 (BLOCKBALL_ANIM, SOFTBOILED and the spiral-balls emitters all
-- reuse these exact tiles) -- and would collide with any other mod
-- patching that record.  The wrap instead swaps the image for the frames
-- of a ball toss/shake by a ball that has a `line`, under ADVANCED, with
-- the option on: nothing else in the game ever sees the re-indexed sheet.
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
  local VERSION = "0.1.17"
  mod.exports.version = VERSION

  mod.options:define({
    { key = "enabled", type = "toggle",
      label = "Colored balls (ADVANCED mode)", default = true },
    { key = "snag_ball_color", type = "toggle",
      label = "Rocket-colored SNAG BALL", default = true },
    { key = "center_balls", type = "toggle",
      label = "Colored balls at POKeMON CENTER", default = true },
    { key = "ball_band", type = "toggle",
      label = "Black band on thrown balls", default = true },
    { key = "dev_all_balls_in_marts", type = "toggle",
      label = "DEV: every ball sold in marts", default = false },
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
  -- `line` (optional, 0.1.15) is the third color: the band along the seam
  -- between the two halves.  Absent = the ball renders exactly as it did
  -- before 0.1.15, vanilla art and all.  Given to the four native balls
  -- whose series art has a visible black band AND whose own two colors
  -- leave room for it to read.
  --
  -- ULTRA_BALL is deliberately left without one: its accent is already
  -- { 40, 40, 40 }, so a black band would sit against a near-black
  -- crescent and read as nothing.  The nine custom_pokeballs entries are
  -- likewise left alone -- those colors were sampled from that mod's own
  -- art and this mod has no basis to invent a band for someone else's
  -- ball.  Their author (and Kanto Balls, for GS/PREMIER) can opt in
  -- through registerColors at any time.
  local BLACK = { 0, 0, 0 }
  local COLORS = {
    -- native
    POKE_BALL   = { body = { 224,  72,  56 }, accent = { 248, 216, 208 },
                    line = BLACK },
    GREAT_BALL  = { body = {  56, 112, 216 }, accent = { 208, 224, 248 },
                    line = BLACK },
    ULTRA_BALL  = { body = { 232, 192,  40 }, accent = {  40,  40,  40 } },
    MASTER_BALL = { body = { 152,  72, 200 }, accent = { 232, 200, 248 },
                    line = BLACK },
    SAFARI_BALL = { body = { 112, 160,  72 }, accent = { 224, 232, 200 },
                    line = BLACK },
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
  --     MY_BALL = { body = {r,g,b}, accent = {r,g,b},
  --                 line = {r,g,b} },   -- optional, 0.1.15+
  --   }) end
  --
  -- `line` is the band along the seam.  Omit it and the ball renders
  -- two-tone on vanilla art exactly as it did before 0.1.15 -- which is
  -- also what happens if the player turns the band option off, or if this
  -- mod is an older copy that has never heard of the key.  So supplying
  -- it is always safe and never a hard dependency.
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
    -- optional keys: validated only when present, never required
    local line = c.line
    if line ~= nil then
      if type(line) ~= "table" or #line < 3 then return false end
      for i = 1, 3 do
        if type(line[i]) ~= "number" then return false end
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
          .. "(need { body = {r,g,b}, accent = {r,g,b}, "
          .. "line = {r,g,b} optional })", tostring(id))
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
  -- the battle whose chain is running, for seams that only see the
  -- AnimPlayer (sheetImage below has no route back to the BattleState)
  local activeBattle
  BattleState.ballChain = function(self, tossAnim, caught, shakes, ball)
    self._pbcBall = ball
    activeBattle = self
    return vanillaBallChain(self, tossAnim, caught, shakes, ball)
  end

  -- ------------------------------------------------------------------
  -- The re-indexed ball tilesheet (see the third-color note at the top).
  --
  -- Built at runtime from the player's OWN extracted sheet rather than
  -- shipped as a file: this art is ROM-derived, and the whole engine is
  -- built so Nintendo's graphics come out of the player's cartridge dump
  -- and are never redistributed.  A mod has no business being the one
  -- exception.  What ships here is only the pixel-role table below --
  -- which pixels of six 8x8 tiles play which part -- and the image is
  -- reproduced from the player's file every session.
  --
  -- BAND_TILES: tile id -> the pixels whose DMG color index changes, in
  -- tile-local coordinates.  `body` are the perimeter outline pixels
  -- (index 3 -> 2, so they join the body); `line` are the seam pixels
  -- (index 2 -> 3, so they become the band).  Everything else is copied
  -- untouched, so with a { accent, body, body } palette the result is
  -- pixel-identical to vanilla.
  --
  -- Tiles 2/18 are the upright ball (TOSS/GREATTOSS/ULTRATOSS, mirrored
  -- for the right half, which is why their band data is symmetric) and
  -- 6/7/22/23 the tilted one (SHAKE).  Derived from the 0.1.75 extraction
  -- of Red and Yellow, whose move_anim_0.png are byte-identical.
  -- ------------------------------------------------------------------
  local BAND_TILES = {
    [2]  = { body = { {6,4}, {7,4}, {4,5}, {5,5}, {3,6}, {3,7} },
             line = {} },
    [6]  = { body = { {5,4}, {6,4}, {7,4}, {3,5}, {4,5}, {2,6}, {2,7} },
             line = {} },
    [7]  = { body = { {0,4}, {1,5}, {2,5}, {3,6}, {3,7} },
             line = {} },
    [18] = { body = { {2,0}, {2,1}, {2,2}, {2,3}, {3,4}, {3,5}, {4,6},
                      {5,6}, {6,7}, {7,7} },
             line = { {3,1}, {4,1}, {5,1}, {5,2}, {6,2}, {7,2} } },
    [22] = { body = { {1,0}, {1,1}, {1,2}, {1,3}, {2,4}, {2,5}, {3,6},
                      {4,6}, {5,7}, {6,7}, {7,7} },
             line = { {6,2}, {7,2}, {2,3}, {3,3}, {4,3}, {5,3}, {6,3} } },
    [23] = { body = { {4,0}, {4,1}, {4,2}, {4,3}, {3,4}, {3,5}, {1,6},
                      {2,6}, {0,7} },
             line = { {2,0}, {3,0}, {1,1}, {2,1}, {0,2}, {1,2} } },
  }

  -- the generated sheets are GB grays: index 1 = 170, 2 = 85, 3 = 0
  -- (tools/extract/gfx.py GB_SHADES).  LOVE 11 takes 0-1 floats.
  local SHADE_BODY, SHADE_LINE = 85 / 255, 0

  -- Built once, lazily: a graphics context exists at draw time but not
  -- necessarily at load, and a headless run must not fault here.  Any
  -- failure warns once and falls back to the vanilla sheet, which renders
  -- the ball two-tone -- never a crash, never a missing sprite.
  --
  -- Failures here report through Runtime.reportError, not just mod.log:
  -- the developer tests on iOS where there is no console, and the whole
  -- symptom of a failed rebuild is "the band just isn't there" -- which
  -- is indistinguishable from the option being off or the ball having no
  -- `line`.  The mod manager's [ERRS] screen is the only channel that
  -- tells those apart on device.
  local Runtime = require("src.mods.Runtime")
  local function bandFail(fmt, ...)
    local msg = string.format(fmt, ...)
    mod.log:warn("%s", msg)
    Runtime.reportError("pokeball_colors", msg)
  end

  local bandImage           -- love Image, or false once a build has failed
  local function bandSheet(ap)
    if bandImage ~= nil then return bandImage or nil end
    bandImage = false                       -- never retry per frame
    local sheet = ap and ap.data and ap.data.tilesheets
                  and ap.data.tilesheets[0]
    if not (sheet and sheet.path and love and love.image
            and love.image.newImageData and love.graphics
            and love.graphics.newImage) then
      bandFail("no band: tilesheet 0 or graphics unavailable")
      return nil
    end
    local ok, img = pcall(function()
      local id = love.image.newImageData(sheet.path)
      local cols = math.floor(id:getWidth() / 8)
      local function paint(list, v)
        for i = 1, #list do
          local p = list[i]
          id:setPixel(p[1], p[2], v, v, v, 1)
        end
      end
      for tile, spec in pairs(BAND_TILES) do
        local tx, ty = (tile % cols) * 8, math.floor(tile / cols) * 8
        local function at(list) local out = {}
          for i = 1, #list do out[i] = { tx + list[i][1], ty + list[i][2] } end
          return out
        end
        paint(at(spec.body), SHADE_BODY)
        paint(at(spec.line), SHADE_LINE)
      end
      return love.graphics.newImage(id)
    end)
    if not (ok and img) then
      bandFail("no band: sheet rebuild failed (%s)", tostring(img))
      return nil
    end
    bandImage = img
    return img
  end

  -- The ball a given AnimPlayer is drawing right now.  Toss rows carry
  -- opts.ball; SHAKE_ANIM rows and the resting lockedBall do not, so the
  -- chain's ball covers those.
  local function ballOf(ap)
    if not ap then return nil end
    return ap._pbcBall
      or (ap._pbcMove and BALL_MOVES[ap._pbcMove]
          and activeBattle and activeBattle._pbcBall)
      or nil
  end

  -- Does this ball render with a band right now?  Every gate the color
  -- wrap applies, so the art and the palette can never disagree.
  local function bandColor(ball)
    if not ball then return nil end
    if PaletteFX.mode ~= "redpp" then return nil end
    if not mod.options:get("enabled") then return nil end
    if not mod.options:get("ball_band") then return nil end
    if ball == "SNAG_BALL" and not mod.options:get("snag_ball_color") then
      return nil
    end
    local c = COLORS[ball]
    return c and c.line or nil
  end

  -- ------------------------------------------------------------------
  -- tilesheet substitution.  Only tileset 0, only while a ball anim is
  -- playing, only for a ball that has a `line`: every other animation
  -- drawing from this sheet (BLOCKBALL_ANIM, SOFTBOILED, the spiral-ball
  -- emitters) and every other color mode keeps the vanilla art.
  --
  -- Deliberately does NOT write self.images -- that is the AnimPlayer's
  -- own cache of the vanilla sheets and must not be poisoned with ours.
  -- ------------------------------------------------------------------
  AnimPlayer._pbcOriginals.sheetImage = AnimPlayer._pbcOriginals.sheetImage
    or AnimPlayer.sheetImage
  local vanillaSheetImage = AnimPlayer._pbcOriginals.sheetImage
  AnimPlayer.sheetImage = function(self, ts)
    if ts == 0 and self._pbcMove and BALL_MOVES[self._pbcMove]
       and bandColor(ballOf(self)) then
      local img = bandSheet(self)
      if img then return img end
    end
    return vanillaSheetImage(self, ts)
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
    -- Slots are DMG color indices 1/2/3.  Slot 3 is the outline ring on
    -- vanilla art and the seam band on the re-indexed sheet; either way
    -- painting it `body` is the pre-0.1.15 two-tone ball, which is the
    -- fallback whenever this ball has no `line` or the band is off.
    --
    -- The band does NOT take part in the flicker: vanilla's f0x map is
    -- { 3, 0, 3 }, which swaps indices 1 and 2 and leaves index 3 on the
    -- dark shade, so a band that held still through the Master/Ultra
    -- flash is what the hardware does.
    local line = bandColor(ball)
    return { accent, body, line and norm(line) or body }
  end

  -- ------------------------------------------------------------------
  -- DEV: every ball sold in marts (default OFF).
  --
  -- Testing what this mod does means throwing every ball, and some are
  -- hard to come by in a normal save -- the MASTER BALL most of all.  With
  -- the toggle on, every mart stocks every ball the game knows about,
  -- including balls added by other mods, so one shop trip covers the whole
  -- test matrix.
  --
  -- A cosmetics mod selling items is a real intrusion on a save, which is
  -- why it is off by default, prefixed DEV: in the menu, and reversible:
  -- the entry is COPIED before the append, so the underlying data table is
  -- never mutated and turning the toggle back off restores the vanilla
  -- shelf with nothing left behind.  Balls already bought stay in the bag,
  -- as any bought item would.
  --
  -- Mechanism (the pattern snag_quest proved, and for the same reason):
  -- mart stock is static data, so `text_pointers:patch(... { mart = {
  -- __append = ids } })` cannot be conditioned on an option.  Wrapping
  -- Data:textEntry -- the single lookup both mart-opening paths call
  -- (OverworldController.lua ~2670, Commands.open_mart ~854) -- can be.
  --
  -- ItemEffects.BALLS is the authoritative ball set, not `def.ball`: the
  -- ROM-extracted item records carry no `ball` field, so the five natives
  -- would be missed.  Mods register into BALLS to make their ball throwable
  -- at all, so this picks them up for free.
  -- ------------------------------------------------------------------
  local Data = require("src.core.Data")
  local ItemEffects = require("src.inventory.ItemEffects")

  Data._pbcOriginals = Data._pbcOriginals or { textEntry = Data.textEntry }
  local vanillaTextEntry = Data._pbcOriginals.textEntry
  Data.textEntry = function(self, mapLabel, textConst)
    local entry = vanillaTextEntry(self, mapLabel, textConst)
    if not (entry and entry.mart) then return entry end
    if not mod.options:get("dev_all_balls_in_marts") then return entry end

    local stock, have = {}, {}
    for i, id in ipairs(entry.mart) do
      stock[i] = id
      have[id] = true
    end
    -- sorted, so the shelf is in the same order every time it opens
    -- rather than in pairs() order, which is not stable across runs
    local add = {}
    for id in pairs(ItemEffects.BALLS or {}) do
      if not have[id] and self.items and self.items[id] then
        add[#add + 1] = id
      end
    end
    table.sort(add)
    for _, id in ipairs(add) do stock[#stock + 1] = id end

    local copy = {}
    for k, v in pairs(entry) do copy[k] = v end
    copy.mart = stock
    return copy
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
    -- TODO/CONFIRM: `line` is deliberately NOT used here yet.  The obvious
    -- move is to feed it into this darkest slot so the machine and the
    -- toss agree, but the machine draws a DIFFERENT sprite (the heal
    -- machine sheet's ball quad, not the anim tilesheet), and this path's
    -- whole shade-slot mapping is still unconfirmed on device -- so what
    -- shade 3 actually covers there is a guess, and a band and an outline
    -- are not the same region.  Confirm the mapping from a screenshot
    -- first, then decide.  Until then the machine keeps the darkened body
    -- it has always used and nothing about it changes in 0.1.15.
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
