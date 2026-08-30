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
--   * Colors live here, keyed by item id, rather than on the ball's own
--     record.  mod.exports.colors is the table itself and registerColors
--     is the supported way in.
--     CORRECTION (0.1.21): this note used to say the balls registry
--     "is strictly validated and has NO color field".  That is wrong.
--     Verified on engine 0.1.78 by registering one: Schemas.check's
--     spec.fields path preserves unknown keys and errors only on a
--     near-miss typo of a known field.  A ball CAN carry its own colour
--     and this mod could read it -- an ergonomics change, not a
--     capability one, and deliberately not made (see the Gold note at
--     the bottom for why no new Gen 1-only depth is being added).
--
-- Untouched on purpose: POOF clouds (ambient zone colors, like vanilla),
-- every non-ball animation, all color modes other than ADVANCED
-- (animSpriteColors returns nil in the mono modes and we pass that
-- through), and the GEN1/MODERN catch math (pure cosmetics).

return function(mod)
  local VERSION = "0.1.57"
  mod.exports.version = VERSION

  mod.options:define({
    { key = "enabled", type = "toggle",
      -- Not "(ADVANCED mode)" any more: that is a Gen 1 colour mode, and
      -- this switch gates the Gen 2 work too.
      label = "Colored balls", default = true },
    { key = "center_balls", type = "toggle",
      label = "Colored balls at POKeMON CENTER", default = true },
    { key = "ball_art_takeover", type = "toggle",
      label = "My ball colors over other mods", default = false },
    { key = "gen2_recolor", type = "toggle",
      -- "GEN 2", not "GOLD family": this covers Gold, Silver AND Crystal,
      -- and naming one of the three in a setting that governs all of them
      -- reads as though the other two are excluded.
      label = "Recolor balls in GEN 2 games", default = true },
    { key = "dev_all_balls_in_marts", type = "toggle",
      label = "DEV: every ball sold in marts", default = false },
  })

  local PaletteFX = require("src.render.PaletteFX")
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")
  local Runtime = require("src.mods.Runtime")
  -- Resolves a sheet path for the editor preview.  A plain require, not a
  -- guarded one: Assets is shared by both generations, and reading it as a
  -- bare value is what gen2check cannot follow -- it degrades the site to an
  -- "unresolved:" note, which would hide the next REAL finding here.
  local Assets = require("src.render.Assets")

  -- Forward declarations.  Lua compiles a name used before its `local` as a
  -- GLOBAL, which is nil at runtime and fails silently -- the trap this
  -- project has been bitten by before.  These are assigned further down but
  -- read by the resolver machinery above their assignment, so they are
  -- declared here on purpose.
  local activeBattle      -- the BattleState whose ball chain is running
  local gameRef           -- the live game, from game.ready
  local goldPinFor        -- Gold only: fn(ball, mon, battle) -> name, row
  local goldBallPaletteBase -- Gold: BattleState.ballPalette as it was BEFORE
                          -- this mod wrapped it, recorded by
                          -- installGoldCenter.  Kept here rather than read
                          -- back off the engine table so goldSeed never has
                          -- to index an engine module as a value (gen2check
                          -- degrades that to an `unresolved:` note, which
                          -- would hide the next real finding at the site).
  local previewBallArt    -- fn(game, entry) -> Image of the REAL ball, or nil
                          -- (defined below BAND_TILES, whose seam coordinates
                          -- it reuses; the editor screen is registered above
                          -- that point, so it has to be an upvalue like
                          -- goldPinFor rather than a local at the use site)
  local throwCache        -- resolver result and saved-override cache per throw

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
  -- ULTRA_BALL takes the OTHER flavour, `outline` (0.1.36).  It used to be
  -- gold over a near-black crescent, which meant its toss strobe read as
  -- gold-ball/black-ball rather than as one ball flickering.  Two yellows
  -- with a black rim keeps it unmistakably an Ultra Ball, turns the strobe
  -- into a shimmer between the two golds, and puts the black where the
  -- sprite already has a region for it.  The nine custom_pokeballs entries are
  -- likewise left alone -- those colors were sampled from that mod's own
  -- art and this mod has no basis to invent a band for someone else's
  -- ball.  Their author (and Too Many Balls, mod id kanto_balls, for
  -- GS/PREMIER) can opt in through registerColors at any time.
  local BLACK = { 0, 0, 0 }
  local COLORS = {
    -- native
    -- Every native ball defaults to `outline` (the black rim on the vanilla
    -- art) rather than `line` (the re-indexed seam band).  Developer call,
    -- 2026-08-29: the band should be something a player opts into per ball
    -- from the editor, not what RESTORE DEFAULT hands back.  It also makes
    -- Gen 1 agree with Gen 2, where slot 3 is the outline and no banded art
    -- exists at all.  The whole `line` path -- BAND_TILES, bandSheet, the
    -- sheetImage swap -- is untouched and still reached by any ball whose
    -- saved entry chooses BAND.
    POKE_BALL   = { body = { 224,  72,  56 }, accent = { 248, 216, 208 },
                    outline = BLACK },
    GREAT_BALL  = { body = {  56, 112, 216 }, accent = { 208, 224, 248 },
                    outline = BLACK },
    ULTRA_BALL  = { body = { 248, 208,  64 }, accent = { 176, 120,  16 },
                    outline = BLACK },
    MASTER_BALL = { body = { 152,  72, 200 }, accent = { 232, 200, 248 },
                    outline = BLACK },
    SAFARI_BALL = { body = { 112, 160,  72 }, accent = { 224, 232, 200 },
                    outline = BLACK },
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

  -- Per-save player choices. The editor stores the third visible colour once
  -- plus which region receives it; a four-colour Game Boy OBJ sprite has one
  -- transparent slot and only three visible slots, so band and outline cannot
  -- be independently coloured at the same time.
  local COLOR_SAVE_KEY = "ball_color_overrides"
  local EDITOR_SCREEN = "PokeballColorEditor"
  local EDITOR_PC_ROW = "pokeball_colors_editor"

  local function rgbCopy(c)
    return { c[1], c[2], c[3] }
  end

  local function entryCopy(c)
    if not c then return nil end
    local out = { body = rgbCopy(c.body), accent = rgbCopy(c.accent) }
    if c.line then out.line = rgbCopy(c.line) end
    if c.outline then out.outline = rgbCopy(c.outline) end
    return out
  end

  local function savedOverrides()
    local rows = mod.save:get(COLOR_SAVE_KEY)
    return type(rows) == "table" and rows or {}
  end

  local function savedEntry(id)
    local row = savedOverrides()[id]
    if type(row) ~= "table" or type(row.body) ~= "table"
       or type(row.accent) ~= "table" or type(row.third) ~= "table" then
      return nil
    end
    local out = { body = rgbCopy(row.body), accent = rgbCopy(row.accent) }
    out[row.style == "outline" and "outline" or "line"] = rgbCopy(row.third)
    return out
  end

  local function saveEntry(id, entry, style)
    local rows = savedOverrides()
    rows[id] = {
      body = rgbCopy(entry.body), accent = rgbCopy(entry.accent),
      third = rgbCopy(entry.line or entry.outline or entry.body),
      style = style == "outline" and "outline" or "line",
    }
    mod.save:set(COLOR_SAVE_KEY, rows)
    throwCache = {}
  end

  local function clearSavedEntry(id)
    local rows = savedOverrides()
    rows[id] = nil
    mod.save:set(COLOR_SAVE_KEY, rows)
    throwCache = {}
  end

  -- What this mod owns, for other mods to check before touching
  -- anything (see the ownership note in the README):
  --   colors           -- the color table and the rendering
  --   caughtBallField  -- mon.caughtBall, written at catch time.  Other
  --                       mods may READ it freely (a ribbon for balls
  --                       caught in X, etc).  Do not write it WHILE THIS
  --                       MOD IS INSTALLED.  If you need the field to
  --                       exist without this mod, write it only when
  --                       exports.owns.caughtBallField is absent, and
  --                       never overwrite a non-nil value -- then the two
  --                       writers can never disagree, and neither has to
  --                       know the other's load order.  Absent on mons
  --                       caught before 0.1.12 or with this mod
  --                       uninstalled, so always nil-check it.
  --   caughtBallColor / caughtBallPalette -- written only for balls whose
  --     colour is dynamic, so the Center can show what a ball actually
  --     looked like when it caught something.  Same rule as caughtBall:
  --     read freely, do not write while this mod is installed.
  mod.exports.owns = {
    colors = true,
    caughtBallField = "mon.caughtBall",
    caughtBallColorField = "mon.caughtBallColor",
    caughtBallPaletteField = "mon.caughtBallPalette",
    caughtBallPaletteRowField = "mon.caughtBallPaletteRow",
    colorResolvers = true,
    colorEditorSave = COLOR_SAVE_KEY,
    colorEditorScreen = EDITOR_SCREEN,
  }

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
    for _, k in ipairs({ "line", "outline" }) do
      local v = c[k]
      if v ~= nil then
        if type(v) ~= "table" or #v < 3 then return false end
        for i = 1, 3 do
          if type(v[i]) ~= "number" then return false end
        end
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

  -- ------------------------------------------------------------------
  -- Dynamic colors (0.1.25), for a ball whose colour is not a constant --
  -- Too Many Balls' KECLEON BALL is the first.
  --
  --   pbc.exports.registerColorResolver("KECLEON_BALL", function(ctx)
  --     return { body = {r,g,b}, accent = {r,g,b}, line = {r,g,b} }
  --   end)
  --
  -- ctx carries `ball`, `surface` ("battle" | "catch"), and whatever the
  -- calling site has: `battle`, `mon`, `game`.  Return nil to fall back to
  -- the static entry, so a resolver that has nothing to say in a given
  -- situation costs nothing.
  --
  -- RESOLVED ONCE PER THROW, not per frame, and this is the part worth
  -- knowing: the colour funnel is HOT.  animSpriteColors runs once per OAM
  -- sprite plus up to three more for a tile straddling an attribute cell,
  -- and bandColor is asked again from sheetImage for every sprite -- tens
  -- of calls a frame, thousands a second.  A resolver is called once when
  -- the chain starts and the answer is held for the whole toss/wobble/rest,
  -- which is also what makes the ball a stable colour rather than a strobe.
  -- (A per-frame `live` mode would be a real visual effect but needs the
  -- resolver to be trivial; not built, and the cache is the only thing that
  -- would have to change.)
  --
  -- A resolver that throws is disabled for the session and reported to
  -- [ERRS] rather than being retried every frame inside a draw loop.
  -- ------------------------------------------------------------------
  -- ------------------------------------------------------------------
  -- Self-check: the band sheet is only correct if WE supply the palette.
  --
  -- The re-indexed sheet moves the seam onto DMG index 3 and the outline
  -- onto 2, which is right when animSpriteColors hands back
  -- { accent, body, line } and WRONG if anything blits it raw: index 3 is
  -- black, so the ball comes out GB-grey with a black band.  That is not
  -- hypothetical -- Gold & Silver Sprites 1.4.2 ships its own pre-coloured
  -- ball art and wraps AnimPlayer.draw/drawSprites to pass `colorFn = nil`
  -- in true-colour mode, so our colour wrap is never called while our sheet
  -- wrap still fires.  Reported from a Yellow save; grey ball, black band.
  --
  -- We cannot see that from here: colorFn is nilled downstream of us (they
  -- load first at priority 99, so their wrap is inside ours and we only
  -- ever see the original argument).  So detect it by RESULT instead.
  -- Across one ball chain, substituting the sheet without our colour pass
  -- running is a contradiction -- it cannot happen when we are the ones
  -- painting -- and it is checked at the START of the next chain, when both
  -- answers are known.  One throw looks wrong, then the band switches off
  -- for the session and the other mod's own art shows through, which is
  -- the right outcome: their balls are already coloured.
  --
  -- Deliberately not keyed on that mod's id.  Any mod that suppresses the
  -- anim palette pass produces the same contradiction and gets the same
  -- answer, including ones written after this.
  -- ------------------------------------------------------------------
  -- `conflictDetected` means "another mod owns the ball animation and our
  -- palette never reaches it".  What happens then is the PLAYER'S choice:
  -- defer (default) and let that mod's own artwork show, or take the ball
  -- back with "My ball colors over other mods" -- see bakedSheet below.
  -- 0.1.31: the verdict is keyed on whether we EXPECTED to colour this
  -- ball, not on whether we swapped the band sheet in.  0.1.30 used the
  -- sheet swap, which only ever happens for a ball that HAS a `line` -- so
  -- a PREMIER BALL (a colour but no band, like every mod ball) never
  -- tripped the detector, the conflict was never noticed, and the takeover
  -- toggle could not engage whichever way it was set.  Reported from
  -- device, and the reason 0.1.30 looked like it did nothing.
  --
  -- `colorPassEverRan` also gates the band swap now.  Until our palette has
  -- been seen to reach a ball once, the re-indexed sheet is not safe to
  -- serve: raw-blitted it is grey with a black band, which is the original
  -- screenshot.  Costs the black band on the first throw of a session.
  local chainWanted, bandColorRan = false, false
  local conflictDetected, colorPassEverRan = false, false

  local RESOLVERS = {}
  local resolverDead = {}
  throwCache = {}

  mod.exports.registerColorResolver = function(id, fn)
    if type(id) ~= "string" or id == "" or type(fn) ~= "function" then
      mod.log:warn("registerColorResolver: need (ballId, function)")
      return false
    end
    if RESOLVERS[id] ~= nil then return false end   -- never clobber
    RESOLVERS[id] = fn
    mod.log:info("registerColorResolver: %s is now dynamic", id)
    return true
  end

  -- The one place a ball's colour is decided.  Everything below reads
  -- through this rather than indexing COLORS, so a resolver reaches every
  -- surface at once.
  local function resolveEntry(ball, ctx)
    if not ball then return nil end
    local custom = savedEntry(ball)
    if custom then return custom end
    local fn = RESOLVERS[ball]
    if fn and not resolverDead[ball] then
      local hit = throwCache[ball]
      if hit ~= nil then
        if hit ~= false then return hit end
      else
        local ok, entry = pcall(fn, ctx or { ball = ball, surface = "battle" })
        if not ok then
          resolverDead[ball] = true
          throwCache[ball] = false
          mod.log:warn("color resolver for %s errored: %s", ball,
            tostring(entry))
          Runtime.reportError("pokeball_colors",
            string.format("%s resolver failed", tostring(ball)))
        elseif entry ~= nil and validColor(entry) then
          throwCache[ball] = entry
          return entry
        else
          if entry ~= nil then
            mod.log:warn("color resolver for %s returned a bad entry; "
              .. "using its static color", ball)
          end
          throwCache[ball] = false
        end
      end
    end
    return COLORS[ball]
  end

  -- Public, so a mod reading exports.colors directly does not silently miss
  -- a resolver-backed ball.
  mod.exports.resolveColor = function(id, ctx) return resolveEntry(id, ctx) end

  -- ------------------------------------------------------------------
  -- BALL COLOR EDITOR: one wardrobe-style screen on every generation.
  --
  -- It is reached through the shared ui.pc.items hook. Red/Blue/Yellow use
  -- the saved entries only while ADVANCED colours are active, exactly like
  -- the rest of this mod; Gold/Silver/Crystal use them directly.
  -- ------------------------------------------------------------------
  local VISIBLE_EDITOR_ROWS = 8
  local VANILLA_BALLS = {
    MASTER_BALL = true, ULTRA_BALL = true, GREAT_BALL = true,
    POKE_BALL = true, SAFARI_BALL = true, PARK_BALL = true,
    FRIEND_BALL = true, HEAVY_BALL = true, LEVEL_BALL = true,
    LURE_BALL = true, FAST_BALL = true, MOON_BALL = true,
    LOVE_BALL = true,
  }
  local GENERIC_PRESETS = {
    -- NOT "CLASSIC": with DEFAULT now first in the cycle, a preset called
    -- CLASSIC read as "put it back how it was" while actually painting the
    -- ball Poke Ball red.  Every preset name here is a colourway.
    { name = "CRIMSON", body = {224,72,56}, accent = {248,216,208},
      third = {0,0,0}, style = "outline" },
    { name = "OCEAN", body = {48,112,224}, accent = {192,232,248},
      third = {8,32,96}, style = "outline" },
    { name = "FOREST", body = {64,152,80}, accent = {208,240,184},
      third = {16,56,24}, style = "line" },
    { name = "GOLD", body = {248,208,64}, accent = {176,120,16},
      third = {0,0,0}, style = "outline" },
    { name = "PURPLE", body = {152,72,200}, accent = {232,200,248},
      third = {40,16,64}, style = "line" },
    { name = "MONO", body = {120,120,120}, accent = {232,232,232},
      third = {24,24,24}, style = "outline" },
  }
  local BALL_PRESETS = {
    POKE_BALL = {
      { "CRIMSON", {224,72,56}, {248,216,208}, {0,0,0}, "outline" },
      { "PREMIER", {240,240,232}, {224,72,56}, {120,24,24}, "line" },
      { "ROCKET", {48,48,56}, {240,48,40}, {0,0,0}, "outline" },
    },
    GREAT_BALL = {
      { "AZURE", {56,112,216}, {208,224,248}, {0,0,0}, "outline" },
      { "COBALT", {32,72,168}, {112,200,248}, {8,24,72}, "outline" },
      { "SCARLET", {200,48,56}, {248,200,112}, {72,8,16}, "line" },
    },
    ULTRA_BALL = {
      { "GOLD RIM", {248,208,64}, {176,120,16}, {0,0,0}, "outline" },
      { "RETRO", {232,192,40}, {40,40,40}, {24,24,24}, "outline" },
      { "PLATINUM", {216,224,232}, {104,112,128}, {24,24,32}, "outline" },
    },
    MASTER_BALL = {
      { "VIOLET", {152,72,200}, {232,200,248}, {0,0,0}, "outline" },
      { "GALAXY", {64,40,144}, {216,120,240}, {16,8,48}, "outline" },
      { "PEARL", {240,224,248}, {176,112,208}, {72,32,96}, "line" },
    },
    SAFARI_BALL = {
      { "OLIVE", {112,160,72}, {224,232,200}, {0,0,0}, "outline" },
      { "MARSH", {72,112,72}, {176,200,136}, {24,48,32}, "line" },
      { "DESERT", {184,144,72}, {240,216,152}, {72,48,16}, "outline" },
    },
    PARK_BALL = {
      { "PARK", {232,136,72}, {248,224,176}, {88,48,16}, "line" },
      { "BLOOM", {208,88,144}, {248,208,224}, {88,24,56}, "outline" },
    },
    FRIEND_BALL = {
      { "FRIEND", {104,184,80}, {232,216,72}, {24,72,32}, "line" },
      { "JADE", {40,144,112}, {176,240,184}, {8,56,48}, "outline" },
    },
    HEAVY_BALL = {
      { "STEEL", {144,152,160}, {216,224,232}, {48,56,64}, "outline" },
      { "IRON", {72,80,96}, {168,176,192}, {16,24,32}, "line" },
    },
    LEVEL_BALL = {
      { "LEVEL", {224,184,72}, {248,224,152}, {48,40,32}, "line" },
      { "VOLCANO", {208,72,32}, {248,184,48}, {64,16,8}, "outline" },
    },
    LURE_BALL = {
      { "LURE", {64,144,216}, {192,232,248}, {16,56,104}, "line" },
      { "DEEP SEA", {32,72,152}, {80,208,216}, {8,24,72}, "outline" },
    },
    FAST_BALL = {
      { "FAST", {232,96,48}, {248,224,72}, {96,24,8}, "line" },
      { "FLASH", {248,208,40}, {248,248,200}, {184,48,16}, "outline" },
    },
    MOON_BALL = {
      { "MOON", {80,88,120}, {216,224,232}, {24,24,48}, "outline" },
      { "ECLIPSE", {32,32,56}, {232,192,72}, {0,0,16}, "line" },
    },
    LOVE_BALL = {
      { "LOVE", {224,104,144}, {248,216,224}, {104,24,56}, "line" },
      { "HEART", {192,48,88}, {248,176,200}, {72,8,32}, "outline" },
    },
  }

  -- Too Many Balls' balls (kanto_balls, BALL_PALETTES).  Two colourways
  -- each, derived from that mod's own palette rows so the alternates read as
  -- variants of the ball rather than unrelated colours.  DEFAULT is always
  -- available above them and is what the ball ships as, so nothing here
  -- needs to restate it.  Ids absent when that mod is not installed simply
  -- never match -- presetsForBall falls to the generic list.
  local TMB_PRESETS = {
    -- ALTERNATES ONLY.  0.1.49 gave each of these balls a first preset named
    -- after the ball and derived from Too Many Balls' own palette row, so it
    -- sat next to ORIGINAL looking like a second copy of it -- and on ORIGIN
    -- BALL the two rows literally read ORIGIN and ORIGINAL.  The ball's own
    -- colour IS ORIGINAL and nothing here restates it: every row below is a
    -- genuine departure, and none is named after its ball.
    PREMIER_BALL  = { { "ONYX", {56,56,64}, {200,200,208}, {16,16,16} },
                      { "CORAL", {240,120,96}, {248,216,200}, {96,32,24} } },
    NEST_BALL     = { { "AMBER", {216,160,48}, {248,224,152}, {72,48,8} },
                      { "COBALT", {40,80,192}, {176,208,248}, {8,24,72} } },
    HEAL_BALL     = { { "MINT", {120,216,184}, {224,248,240}, {24,80,64} },
                      { "PLUM", {120,64,136}, {232,208,240}, {40,16,48} } },
    MIRROR_BALL   = { { "PRISM", {136,168,232}, {232,216,248}, {40,40,88} },
                      { "COPPER", {192,112,56}, {240,208,168}, {72,32,8} } },
    SILPH_BALL    = { { "NEON", {64,224,208}, {248,120,200}, {16,48,56} },
                      { "SLATE", {96,104,120}, {208,216,228}, {24,28,40} } },
    SNARE_BALL    = { { "BRIAR", {104,80,56}, {200,184,128}, {32,24,16} },
                      { "CITRUS", {216,208,64}, {248,248,192}, {88,80,8} } },
    CATALYST_BALL = { { "EMBER", {224,96,48}, {248,200,120}, {72,24,8} },
                      { "JADE", {48,160,120}, {200,240,220}, {8,56,40} } },
    DRIFT_BALL    = { { "STORM", {88,104,136}, {200,216,240}, {24,32,48} },
                      { "PEACH", {248,176,136}, {248,232,216}, {112,56,32} } },
    KECLEON_BALL  = { { "CITRUS", {216,208,64}, {248,248,192}, {88,80,8} },
                      { "COBALT", {40,80,192}, {176,208,248}, {8,24,72} } },
    CRADLE_BALL   = { { "DAWN", {248,192,152}, {248,232,216}, {96,56,40} },
                      { "MIDNITE", {40,40,56}, {168,176,216}, {8,8,16} } },
    ACE_BALL      = { { "TROPHY", {216,176,64}, {248,232,176}, {72,56,16} },
                      { "JADE", {48,160,120}, {200,240,220}, {8,56,40} } },
    LUXURY_BALL   = { { "VELVET", {96,32,56}, {232,184,120}, {32,8,16} },
                      { "IVORY", {240,236,224}, {200,192,168}, {56,52,40} } },
    CHERISH_BALL  = { { "ROSE", {232,128,160}, {248,216,224}, {88,24,48} },
                      { "SNOW", {236,240,248}, {184,200,224}, {56,64,80} } },
    CAGE_BALL     = { { "RUST", {152,88,48}, {216,168,112}, {48,24,8} },
                      { "MOSS", {80,136,72}, {200,232,176}, {16,48,24} } },
    CRYSTAL_BALL  = { { "FROST", {120,184,224}, {232,244,252}, {24,48,72} },
                      { "AMETHYS", {152,104,200}, {232,208,248}, {48,24,72} } },
    STRANGE_BALL  = { { "VOID", {40,32,64}, {136,120,200}, {8,8,24} },
                      { "CORAL", {240,120,96}, {248,216,200}, {96,32,24} } },
    ORIGIN_BALL   = { { "RELIC", {168,144,96}, {232,216,176}, {56,40,24} },
                      { "ONYX", {56,56,64}, {200,200,208}, {16,16,16} } },
    BEAST_BALL    = { { "AETHER", {224,232,240}, {120,200,216}, {40,56,72} },
                      { "CORAL", {240,120,96}, {248,216,200}, {96,32,24} } },
    GS_BALL       = { { "ANTIQUE", {168,136,64}, {224,208,160}, {48,32,8} },
                      { "JADE", {48,160,120}, {200,240,220}, {8,56,40} } },
    QUICK_BALL    = { { "SPARK", {248,232,96}, {248,248,216}, {96,72,8} },
                      { "SLATE", {96,104,120}, {208,216,228}, {24,28,40} } },
    TIMER_BALL    = { { "MIDNITE", {40,40,56}, {216,64,64}, {8,8,16} },
                      { "SAND", {216,192,136}, {248,240,216}, {88,72,32} } },
    NET_BALL      = { { "REEF", {64,184,144}, {240,232,168}, {16,56,48} },
                      { "SUNSET", {232,128,72}, {248,208,152}, {88,32,16} } },
    DUSK_BALL     = { { "TWILITE", {88,72,136}, {232,176,96}, {24,16,48} },
                      { "ASH", {136,136,144}, {232,232,236}, {40,40,48} } },
    REPEAT_BALL   = { { "ECHO", {160,120,200}, {232,216,248}, {48,24,72} },
                      { "MOSS", {80,136,72}, {200,232,176}, {16,48,24} } },
    DREAM_BALL    = { { "LULLABY", {136,168,216}, {240,240,248}, {32,48,80} },
                      { "PEACH", {248,176,136}, {248,232,216}, {112,56,32} } },
    DIVE_BALL     = { { "ABYSS", {16,40,88}, {80,168,200}, {0,8,24} },
                      { "LAGOON", {56,184,192}, {208,244,248}, {8,64,72} } },
  }

  -- The Gold-family palette a ball's throw ACTUALLY resolves to, or nil.
  local function goldSeed(id)
    if not (gameRef and gameRef.data and gameRef.data.gen2Palettes) then
      return nil, nil
    end
    local okBS, BS2 = pcall(require, "src.ui.gen2.BattleState")
    -- `and` TRUNCATES a call to one value, so folding this into the
    -- condition made `name` always nil, every lookup miss, and every ball
    -- open on the red POKE_BALL fallback until the player cycled a preset.
    -- The engine documents the same trap at BattleAnimView.lua:57.
    -- Deliberately the chain from BENEATH our own wrap.  Since 0.1.52 that
    -- wrap answers with this mod's colour for an un-customised cart ball, so
    -- asking it here would make ORIGINAL report our colour as the ball's own
    -- -- the one thing it must never do.  goldBallPaletteBase is what was
    -- installed before us: Too Many Balls' wrap when that mod is present,
    -- the cart's own table otherwise.
    local name
    if goldBallPaletteBase then
      local okName, res = pcall(goldBallPaletteBase, {}, id)
      if okName and type(res) == "string" then name = res end
    elseif okBS and type(BS2) == "table"
           and type(BS2.ballPalette) == "function" then
      local okName, res = pcall(BS2.ballPalette, {}, id)
      if okName and type(res) == "string" then name = res end
    end
    local set = gameRef.data.gen2Palettes.battleObjects
    local row = name and set and set[name]
    if type(row) == "table" and row[2] and row[3] and row[4] then
      return { accent = rgbCopy(row[2]), body = rgbCopy(row[3]),
               outline = rgbCopy(row[4]) }, name
    end
    return nil, name
  end

  -- This mod's OWN colourway for a ball -- the first entry of whichever
  -- table covers it.  This is what RESTORE DEFAULT hands back, and it is
  -- deliberately not "whatever the game would draw untouched": the point of
  -- the mod is its palette, so its palette is the baseline.  A ball nothing
  -- covers falls to what the game draws, then to the generic list, rather
  -- than being asserted as red.
  local function fromRow(row)
    return { name = row[1], body = rgbCopy(row[2]), accent = rgbCopy(row[3]),
             third = rgbCopy(row[4]), style = row[5] or "outline" }
  end

  local function defaultPreset(id)
    -- The CART's own balls are this mod's to dress: its colourway is their
    -- default.  A ball another mod ADDED is that mod's, and its default stays
    -- whatever its author registered -- developer's call, and the same
    -- ownership line the Gen 2 note below draws.  Too Many Balls' rows reach
    -- us through goldSeed, so "whatever TMB says" needs no coordination and
    -- no second copy of their table.
    if BALL_PRESETS[id] then return fromRow(BALL_PRESETS[id][1]) end
    local own = goldSeed(id)
    if own then
      return { name = "ORIGINAL", body = rgbCopy(own.body),
               accent = rgbCopy(own.accent),
               third = rgbCopy(own.outline), style = "outline" }
    end
    -- No native answer -- a Gen 1 boot, or a ball whose mod registered no
    -- Gold palette.  resolveEntry is the Gen 1 counterpart of goldSeed: it
    -- reads COLORS, which is where another mod's registerColors lands, so a
    -- mod ball still defaults to its author's colour.  TMB_PRESETS is NOT a
    -- fallback -- since 0.1.53 it holds alternates only, and defaulting to
    -- one would hand the player a colourway nobody chose.
    local mine = resolveEntry(id, { ball = id, surface = "editor",
                                    game = gameRef })
    if mine and mine.body and mine.accent then
      return { name = "ORIGINAL", body = rgbCopy(mine.body),
               accent = rgbCopy(mine.accent),
               third = rgbCopy(mine.line or mine.outline or mine.body),
               style = mine.line and "line" or "outline" }
    end
    local g = GENERIC_PRESETS[1]
    return { name = g.name, body = rgbCopy(g.body), accent = rgbCopy(g.accent),
             third = rgbCopy(g.third), style = g.style }
  end

  -- Does this mod paint this ball on a Gen 2 boot with nothing saved?
  -- Only the cart's own balls, so a mod ball keeps its author's colour
  -- unless the player picks something else in the editor.
  local function assertsGoldDefault(id)
    return BALL_PRESETS[id] ~= nil
      and mod.options:get("enabled")
      and mod.options:get("gen2_recolor")
  end

  -- defaultPreset's {third, style} shape as the {line|outline} shape the
  -- colour entries use.
  local function entryFromPreset(p)
    local out = { body = rgbCopy(p.body), accent = rgbCopy(p.accent) }
    out[p.style == "line" and "line" or "outline"] = rgbCopy(p.third)
    return out
  end

  local function presetsForBall(id)
    local rows = BALL_PRESETS[id] or TMB_PRESETS[id]
    local out = {}
    if rows then
      for i, row in ipairs(rows) do
        out[i] = { name = row[1], body = row[2], accent = row[3],
          third = row[4], style = row[5] or "outline" }
      end
    else
      for i, g in ipairs(GENERIC_PRESETS) do out[i] = g end
    end
    -- The ball's OWN colour, kept as a named choice.  Called ORIGINAL and not
    -- GEN 2 because for a mod-added ball it is not the cart's colour at all --
    -- goldSeed walks the ballPalette wrap chain, so on a Too Many Balls ball
    -- it returns the palette THAT mod registered.  ORIGINAL is true for both.
    -- Only Gen 2 has one to offer: Gen 1 has no native ball colour, the
    -- vanilla ball being two SGB zone shades.
    local native = goldSeed(id)
    if native then
      out[#out + 1] = { name = "ORIGINAL", body = native.body,
                        accent = native.accent, third = native.outline,
                        style = "outline" }
    end
    return out
  end

  local function ballCatalog(game)
    local data = game and game.data or {}
    local records = data.gen2Balls or data.balls or {}
    -- Every ball the game knows, mod-added included.  The old SHOW MOD BALLS
    -- toggle is gone: hiding balls you own from a list of balls you own is
    -- not a preference, and since 0.1.52 a mod ball defaults to its author's
    -- colour anyway, so there is nothing to hide FROM.
    local includeMods = true
    local out, seen = {}, {}
    local function add(id)
      if seen[id] then return end
      seen[id] = true
      local item = data.items and data.items[id]
      out[#out + 1] = {
        id = id,
        label = (item and item.name) or id:gsub("_", " "),
        index = item and item.index or 9999,
      }
    end
    for id in pairs(records) do
      if VANILLA_BALLS[id] or includeMods then add(id) end
    end
    -- On Gen 2 the balls REGISTRY is not where mod balls live.  Nothing at
    -- Gold's throw site reads a mod's ball record, so Too Many Balls
    -- deliberately registers only an ITEMS record there and stamps
    -- `pocket = "BALL"` at game.ready (kanto_balls/main.lua:460-495) --
    -- which is exactly the test Gold itself uses to decide something is a
    -- ball (gen2/BattleState.lua:3181).  Walking gen2Balls alone therefore
    -- showed the player nothing but the natives.
    if includeMods and data.items then
      for id, def in pairs(data.items) do
        if type(def) == "table" and (def.pocket == "BALL" or def.ball) then
          add(id)
        end
      end
    end
    table.sort(out, function(a, b)
      if a.index ~= b.index then return a.index < b.index end
      return a.label < b.label
    end)
    return out
  end

  -- One [ERRS] line per ball that cannot be seeded, once each.  Silent here
  -- means "looks like a red Poke Ball for no stated reason".
  local seedFailed = {}
  local function seedFail(fmt, ...)
    local msg = "editor seed: " .. string.format(fmt, ...)
    if seedFailed[msg] then return end
    seedFailed[msg] = true
    mod.log:warn("%s", msg)
    Runtime.reportError("pokeball_colors", msg)
  end

  local function editableEntry(id)
    local saved = savedOverrides()[id]
    -- ORDER MATTERS, and it changed in 0.1.48.  On a Gen 2 boot this mod
    -- does NOT colour throws -- Gold owns its own ball palettes and we
    -- decorate -- so the truth about what a ball looks like there is Gold's
    -- palette, not our COLORS table.  Seeding from COLORS first meant the
    -- five balls we happen to carry showed our Gen 1 colours: the editor
    -- offered a PURPLE Master Ball on a game that throws a green one.
    -- So: a saved override, then what the game will actually draw, and only
    -- then our own table for a Gen 1 boot.
    local base = savedEntry(id)
    -- What is ACTUALLY on screen, in the order the throw resolves it: a
    -- saved override, then this mod's asserted colourway for a cart ball,
    -- then the ball's own palette.  Seeding from anything else is how 0.1.46
    -- ended up offering colours the game was not drawing.
    if not base and assertsGoldDefault(id) then
      base = entryFromPreset(defaultPreset(id))
    end
    local goldName
    if not base then base, goldName = goldSeed(id) end
    if not base then
      base = resolveEntry(id, { ball = id, surface = "editor",
                                game = gameRef })
    end
    if not base and gameRef and gameRef.data and gameRef.data.gen2Palettes then
      -- Report rather than silently show red.  A mod ball with no resolvable
      -- palette is indistinguishable on screen from one whose owner simply
      -- chose red, which is what made CATALYST BALL and ORIGIN BALL
      -- unexplainable from a screenshot (device, 0.1.46).  Names which of
      -- the two halves failed.
      seedFail("%s: %s", tostring(id),
        goldName and ("palette " .. tostring(goldName) .. " has no row")
          or "no palette name")
    end
    base = base or COLORS.POKE_BALL
    local style = type(saved) == "table" and saved.style
      or (base.outline and "outline" or "line")
    return {
      body = rgbCopy(base.body), accent = rgbCopy(base.accent),
      third = rgbCopy(base.line or base.outline or base.body),
      style = style == "outline" and "outline" or "line",
    }
  end

  local function entryFromWorking(w)
    local out = { body = rgbCopy(w.body), accent = rgbCopy(w.accent) }
    out[w.style] = rgbCopy(w.third)
    return out
  end

  local function persistWorking(id, w)
    saveEntry(id, entryFromWorking(w), w.style)
  end

  -- Capability, not a version name -- the same test the Gold block at the
  -- bottom of this file uses.  It matters to the editor because the STYLE
  -- row is meaningless on Gen 2: Gold's ball art has no re-indexed variant,
  -- so slot 3 is the outline whatever the row says.
  local function isGen2(game)
    game = game or gameRef or mod.game
    return not not (game and game.data and game.data.gen2Palettes)
  end

  local function openColorEditor(game)
    game = game or gameRef or mod.game
    if not (game and game.stack) then return false end
    mod.ui.push(game, EDITOR_SCREEN)
    return true
  end

  mod.content.screens:register(EDITOR_SCREEN, {
    new = function(game)
      local Font, Theme = mod.ui.Font, mod.ui.Theme
      local balls = ballCatalog(game)
      local selected, scroll = 1, 0
      local mode, editRow = "list", 1
      local ball, working
      local presetIndex = 1
      local presets = GENERIC_PRESETS
      local restoredAll = false      -- one-shot confirmation on the list
      local rgbPart, rgbChannel, rgbStep = "body", 1, 8
      local self = { game = game, isOpaque = true, isModOptions = true }

      local function ensureVisible()
        if selected <= scroll then scroll = selected - 1 end
        if selected > scroll + VISIBLE_EDITOR_ROWS then
          scroll = selected - VISIBLE_EDITOR_ROWS
        end
      end

      -- The STYLE row exists only where it can do something.  Gold, Silver
      -- and Crystal have no re-indexed ball art, so slot 3 is the outline
      -- whatever the row says -- 0.1.44 made it merely inert, and the
      -- developer's call on 0.1.46 was that an inert row should not be on
      -- screen at all.  Every other row shifts up by one there.
      local function editRows()
        if isGen2(self.game) then
          return { "PRESET", "BODY", "ACCENT", "THIRD", "RESTORE DEFAULT",
                   "DONE" }
        end
        return { "PRESET", "STYLE", "BODY", "ACCENT", "THIRD",
                 "RESTORE DEFAULT", "DONE" }
      end

      -- What the visible row at `i` means, so the handlers below never have
      -- to know which layout is on screen.
      local function rowKind(i)
        return editRows()[i]
      end

      -- Does the working entry match one of the presets?  If it does not,
      -- the PRESET row must not claim it does: opening a ball seeds the
      -- editor from that ball's OWN colours and applies no preset, so
      -- showing "CLASSIC" there was a label that described nothing on
      -- screen -- and on a ball whose own colours happened to be reddish it
      -- read as "the default is wrong" (device, 0.1.46).
      local function sameRgb(a, b)
        return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
      end
      local function matchingPreset(w, list)
        for i, p in ipairs(list or {}) do
          if sameRgb(p.body, w.body) and sameRgb(p.accent, w.accent)
             and sameRgb(p.third, w.third) then
            return i
          end
        end
        return 0                        -- 0 == "not a preset"; shows DEFAULT
      end

      local function beginEdit()
        ball = balls[selected]
        if not ball then return end
        working = editableEntry(ball.id)
        presets = presetsForBall(ball.id)
        presetIndex = matchingPreset(working, presets)
        editRow, mode = 1, "edit"
      end

      -- Every stop in the cycle is a NAMED colourway now.  0.1.49 kept a
      -- nameless DEFAULT at index 0 that meant "clear the override"; the
      -- developer's call is that a preset row should offer names, and that
      -- the game's own colours belong in the list under an obvious one --
      -- GEN 2 -- rather than hiding behind the word default.  Index 0 now
      -- only ever means "hand-edited RGB that matches no preset", which the
      -- row reports as CUSTOM and which cycling steps off.
      local function applyPreset()
        local p = presets[presetIndex]
        if not p then return end
        working = {
          body = rgbCopy(p.body), accent = rgbCopy(p.accent),
          third = rgbCopy(p.third), style = p.style,
        }
        persistWorking(ball.id, working)
      end

      local function adjust(v, direction)
        return math.max(0, math.min(255, v + direction * rgbStep))
      end

      function self:update(_dt)
        local input = game and game.input
        if not input then return end
        if mode == "list" then
          local last = #balls + 1        -- the RESTORE ALL row
          if input:wasPressed("up") or input:wasPressed("down")
             or input:wasPressed("b") then
            restoredAll = false
          end
          if input:wasPressed("up") and #balls > 0 then
            selected = selected > 1 and selected - 1 or last
            ensureVisible()
          elseif input:wasPressed("down") and #balls > 0 then
            selected = selected < last and selected + 1 or 1
            ensureVisible()
          elseif input:wasPressed("a") then
            if selected > #balls then
              -- RESTORE ALL: the RESTORE DEFAULT row applied to every ball
              -- in the list at once.  Clearing, for the reason given there:
              -- a cart ball then takes this mod's colourway and a mod-added
              -- ball its author's, with nothing pinned.
              for _, item in ipairs(balls) do
                clearSavedEntry(item.id)
              end
              restoredAll = true
            else
              beginEdit()
            end
          elseif input:wasPressed("b") then
            game.stack:pop()
          end
          return
        end

        if mode == "rgb" then
          if input:wasPressed("up") then
            rgbChannel = rgbChannel > 1 and rgbChannel - 1 or 3
          elseif input:wasPressed("down") then
            rgbChannel = rgbChannel < 3 and rgbChannel + 1 or 1
          elseif input:wasPressed("left") then
            working[rgbPart][rgbChannel] =
              adjust(working[rgbPart][rgbChannel], -1)
            persistWorking(ball.id, working)
          elseif input:wasPressed("right") then
            working[rgbPart][rgbChannel] =
              adjust(working[rgbPart][rgbChannel], 1)
            persistWorking(ball.id, working)
          elseif input:wasPressed("a") then
            rgbStep = rgbStep == 1 and 8 or (rgbStep == 8 and 32 or 1)
          elseif input:wasPressed("b") then
            mode = "edit"
          end
          return
        end

        -- Everything below dispatches on the row's NAME, never its number,
        -- so the Gen 2 layout (no STYLE row) needs no parallel index math.
        local rows = editRows()
        local function toggleStyle()
          working.style = working.style == "line" and "outline" or "line"
          persistWorking(ball.id, working)
        end
        if input:wasPressed("up") then
          editRow = editRow > 1 and editRow - 1 or #rows
        elseif input:wasPressed("down") then
          editRow = editRow < #rows and editRow + 1 or 1
        elseif input:wasPressed("left") or input:wasPressed("right") then
          local direction = input:wasPressed("right") and 1 or -1
          local kind = rowKind(editRow)
          if kind == "PRESET" and #presets > 0 then
            -- 1..#presets.  From CUSTOM (0) a step enters the list at
            -- whichever end the player moved toward.
            if presetIndex == 0 then
              presetIndex = direction > 0 and 1 or #presets
            else
              presetIndex = ((presetIndex - 1 + direction) % #presets) + 1
            end
            applyPreset()
          elseif kind == "STYLE" then
            toggleStyle()
          end
        elseif input:wasPressed("a") then
          local kind = rowKind(editRow)
          if kind == "PRESET" then
            if presetIndex == 0 then presetIndex = 1 end
            applyPreset()
          elseif kind == "STYLE" then
            toggleStyle()
          elseif kind == "BODY" or kind == "ACCENT" or kind == "THIRD" then
            rgbPart = kind:lower()
            rgbChannel, mode = 1, "rgb"
          elseif kind == "RESTORE DEFAULT" then
            -- CLEARING is the whole operation now.  0.1.51 wrote this mod's
            -- colourway instead, because back then clearing on Gold handed
            -- the ball to the cart palette.  0.1.52 removed that reason: with
            -- nothing saved, customGoldPalette already asserts our colourway
            -- for a cart ball and stays out of the way for a mod-added one.
            -- So clearing now means exactly "this mod's default" on both
            -- generations -- and, unlike a written entry, it does not PIN a
            -- mod ball's colour where that mod could later retune it.
            clearSavedEntry(ball.id)
            working = editableEntry(ball.id)
            presetIndex = matchingPreset(working, presets)
          elseif kind == "DONE" then
            mode = "list"
          end
        elseif input:wasPressed("b") then
          mode = "list"
        end
      end

      local previewCanvas

      local function drawBallPreview(x, y, w)
        if not w then return end
        local G = love.graphics
        previewCanvas = previewCanvas or G.newCanvas(48, 48)

        -- Gen 1's Advanced colour pass is applied to the completed 160x144
        -- frame, after this screen returns. Clearing the active shader here
        -- therefore is not enough: raw RGB primitives are still quantized by
        -- that later pass. Bake the preview into a tiny drawable and ask the
        -- renderer to replay it after the final palette composite, using the
        -- same true-colour UI seam as engine-authored sprite previews.
        G.push("all")
        G.setCanvas(previewCanvas)
        -- Binding a Canvas does NOT reset the transform or the scissor, and
        -- Gen 2 draws every state inside Playfield.push (Playfield.lua:58-66),
        -- which sets BOTH: a translate to the letterbox origin and a scissor
        -- in SCREEN space.  Inherited into a 48x48 canvas that put the drawing
        -- outside it and clipped whatever was left, so on Gold/Crystal the
        -- preview came out fully blank.  Gen 1 never showed it because its
        -- states draw into Renderer's 160x144 UI canvas at identity.  The
        -- engine warns about exactly this at Game2.lua:1441.  push("all")
        -- saved both, so pop() puts them back.
        G.origin()
        G.setScissor()
        G.clear(0, 0, 0, 0)
        local previousShader = G.getShader()
        G.setShader()
        G.setColor(1, 1, 1, 1)

        -- The REAL sprite, whenever the sheet can be read.  That is the whole
        -- point of the swatch: someone picking colours should be looking at
        -- the ball that will be thrown.
        local art = previewBallArt and previewBallArt(
          -- `true`: the third colour always paints now, so the seam/outline
          -- choice is entirely the entry's own style.
          self.game or gameRef, w, true,
          isGen2(self.game))
        if art then
          art:setFilter("nearest", "nearest")
          -- 16x16 art at 3x.  The ball's own pixels occupy x 2..13, y 4..15
          -- of that frame, so shifting by -(2*3)+6 = 0 and -(4*3)+6 = -6
          -- lands its 12x12 box centred in the 48x48 canvas.
          G.draw(art, 0, -6, 0, 3, 3)
        else
          -- FALLBACK only: no cache yet, an unreadable sheet path, a headless
          -- run.  An approximation of the ball in the same three regions --
          -- close enough to keep the editor usable, and never what the player
          -- sees when the art is available.
          local function set(c)
            G.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
          end
          local rim  = (w.style == "outline") and w.third or BLACK
          local seam = (w.style == "line") and w.third or BLACK
          set(rim)
          G.circle("fill", 24, 24, 22)                            -- perimeter
          set(w.accent)
          G.circle("fill", 24, 24, 20)                            -- lower half
          set(w.body)
          G.arc("fill", "pie", 24, 24, 20, math.pi, 2 * math.pi)  -- upper mass
          set(seam)
          G.rectangle("fill", 4, 21, 40, 5)                       -- the seam
          set(rim)
          G.circle("fill", 24, 24, 6)                             -- button ring
          set(w.accent)
          G.circle("fill", 24, 24, 4)                             -- button face
        end

        G.setShader(previousShader)
        G.pop()

        -- On Gen 2 this inline draw IS the preview: markUiSpriteRedraw only
        -- records while currentPass == "ui" (PaletteFX.lua:389), and that pass
        -- is set in Renderer:beginFrame, which only Gen 1's Game.lua calls
        -- (Game2 has its own present path and never reaches Renderer:endFrame's
        -- replay at Renderer.lua:1232).  So clear the shader around it rather
        -- than trusting whatever is bound to leave true RGB alone.  Harmless on
        -- Gen 1, where the replay still lands on top of it.
        local boundShader = G.getShader()
        G.setShader()
        G.setColor(1, 1, 1, 1)
        G.draw(previewCanvas, x - 24, y - 24)
        G.setShader(boundShader)
        PaletteFX.markUiSpriteRedraw(previewCanvas, nil, x - 24, y - 24)
      end

      -- Left/right affordance on the rows that cycle, the way Trainer
      -- Journey marks its PACE row.  It uses ASCII "<VALUE>", which is not
      -- an option here: neither `<` nor `>` is in the Gold charmap at all.
      -- Real arrow glyphs are, and Theme already names the one that is the
      -- SAME code on both generations:
      --   Theme.cursor       0xED  right arrow, red AND gold
      --   Theme.cursorHollow 0xEC  hollow right arrow, both
      --   0x71 left arrow, GOLD ONLY -- red has no left arrow at any code
      -- So the left arrow is drawn only where it exists, and the row still
      -- reads as adjustable on Gen 1 from the right arrow alone.
      -- ARROWS.  Established by rendering the actual glyph tiles out of both
      -- the red and gold font.png (mainBase 0x80, 16 per row), not by
      -- trusting the charmap table -- which lists arrows that are blank:
      --
      --   0xEC  hollow right triangle   present, identical on both
      --   0xED  filled right triangle   present, identical on both  (cursor)
      --   0xEE  filled DOWN triangle    present, identical on both  (more)
      --   0xDF  charmap says "left"     TILE IS EMPTY on both
      --   0xEB  charmap says "right"    empty on gold, a stub on red
      --   0x71  charmap says "left"     lives in the SWAPPABLE $60 extra
      --                                 page (extraBase 0x60, and
      --                                 FontBattleExtra can replace it), so
      --                                 0.1.46 drew whatever happened to
      --                                 hold that slot -- the stray symbol
      --                                 beside every preset name
      --
      -- So there is no left arrow to borrow, on either generation.  Draw one
      -- instead: the exact horizontal mirror of the 0xED tile, as rectangles,
      -- which is pixel-identical to the font's own arrow and needs no glyph
      -- at all.  Rows are { xOffset, width } within the 8x8 cell.
      local LEFT_ARROW_ROWS = {
        { 5, 2 }, { 4, 3 }, { 3, 4 }, { 2, 5 }, { 3, 4 }, { 4, 3 }, { 5, 2 },
      }
      local function drawLeftArrow(x, y)
        local G = love.graphics
        local r, g, b, a = G.getColor()
        G.setColor(0, 0, 0, 1)
        for i, row in ipairs(LEFT_ARROW_ROWS) do
          G.rectangle("fill", x + row[1], y + i - 1, row[2], 1)
        end
        G.setColor(r, g, b, a)
      end

      local CYCLER_RIGHT = 136          -- last column inside the frame

      -- rightEdge lets the RGB screen keep its values clear of the ball,
      -- which now sits at x 96..144.
      local function drawCycler(text, y, changeable, rightEdge)
        text = tostring(text or "")
        rightEdge = rightEdge or CYCLER_RIGHT
        local w = (Font.width and Font.width(text)) or (#text * 8)
        local vx = rightEdge - w
        Font.draw(text, vx, y)
        if not changeable then return end
        Font.drawCode(Theme.cursor, rightEdge, y)
        drawLeftArrow(vx - 8, y)
      end

      local function label(s, n)
        s = tostring(s or "")
        return #s > n and s:sub(1, n) or s
      end

      function self:draw()
        local G = love.graphics
        G.setColor(0, 0, 0, 1)
        Font.drawBox(0, 0, 20, 18)
        if mode == "list" then
          Font.draw("BALL COLORS", 8, 8)
          if #balls == 0 then
            Font.draw("NO BALLS FOUND", 16, 32)
          end
          for row = 1, VISIBLE_EDITOR_ROWS do
            local i, item = scroll + row, balls[scroll + row]
            local y = 24 + (row - 1) * 8
            if item then
              if i == selected then Font.drawCode(Theme.cursor, 8, y) end
              Font.draw(label(item.label, 12), 16, y)
              if savedOverrides()[item.id] then Font.draw("*", 112, y) end
            elseif i == #balls + 1 then
              -- the RESTORE ALL row, last in the list
              if i == selected then Font.drawCode(Theme.cursor, 8, y) end
              Font.draw("RESTORE ALL", 16, y)
            end
          end
          -- More-below marker, the way Trainer Journey marks its scrolling
          -- lists.  Theme.moreArrow (0xEE) is a filled DOWN triangle and is
          -- the same tile on both generations -- one of only three arrows
          -- that actually exist (see the note by drawLeftArrow).  The ball
          -- list scrolls and had nothing saying so.
          if scroll + VISIBLE_EDITOR_ROWS < #balls + 1 then
            Font.drawCode(Theme.moreArrow or 0x7e, 136,
              24 + (VISIBLE_EDITOR_ROWS - 1) * 8)
          end
          if restoredAll then
            Font.draw("ALL RESTORED", 16, 120)
          else
            Font.draw("A: EDIT", 16, 120)
            Font.draw("B: EXIT", 96, 120)
          end
        elseif mode == "edit" then
          Font.draw(label(ball and ball.label, 18), 8, 8)
          local rows = editRows()
          local styleRowY
          for i, row in ipairs(rows) do
            local y = 24 + (i - 1) * 8
            if i == editRow then Font.drawCode(Theme.cursor, 8, y) end
            Font.draw(label(row, 9), 16, y)
            if row == "STYLE" then styleRowY = y end
          end
          -- DEFAULT, not a preset name, when the colours on screen are the
          -- ball's own.  Opening a ball applies no preset, so naming one
          -- there described nothing the player could see.
          local presetLabel = presetIndex > 0 and presets[presetIndex]
            and presets[presetIndex].name or "CUSTOM"
          drawCycler(label(presetLabel, 8), 24, #presets > 0)
          -- Only Gen 1 has a STYLE row, and it is now the ONLY thing that
          -- decides where the third colour lands.  The old global band
          -- toggle is gone: it contradicted this row, since turning it off
          -- made slot 3 paint nothing while the row still offered a choice.
          if styleRowY then
            drawCycler(working.style == "line" and "BAND" or "OUTLINE",
              104, true)
          end
          drawBallPreview(120, 60, working)
          -- x=96, not 88: "A: SELECT" is nine glyphs from x=16 and the font
          -- advances a flat 8px, so it ENDS at 88 -- the two hints ran
          -- together as "A: SELECTB: BACK".
          Font.draw("A: SELECT", 16, 120)
          Font.draw("B: BACK", 96, 120)
        else
          Font.draw(label(ball and ball.label, 18), 8, 8)
          Font.draw(string.upper(rgbPart) .. " RGB", 8, 24)
          local names = { "R", "G", "B" }
          for i = 1, 3 do
            local y = 48 + (i - 1) * 16
            if i == rgbChannel then Font.drawCode(Theme.cursor, 16, y) end
            Font.draw(names[i], 32, y)
            drawCycler(("%03d"):format(working[rgbPart][i]), y, true, 88)
          end
          drawBallPreview(120, 60, working)
          Font.draw("STEP " .. rgbStep .. " (A)", 16, 104)
          -- "LEFT/RIGHT" ran into "B: BACK" the same way, and there is no
          -- room for both plus a gap inside an 18-column box.  The hint goes:
          -- the arrows drawn either side of the value already say it.
          Font.draw("B: BACK", 16, 120)
        end
        G.setColor(1, 1, 1, 1)
      end

      ensureVisible()
      return self
    end,
  })

  mod.hooks:wrap("ui.pc.items", function(next_, game, rows)
    local out = next_(game, rows)
    if type(out) ~= "table" then return out end
    for _, row in ipairs(out) do
      if row.id == EDITOR_PC_ROW then return out end
    end
    local editor = {
      id = EDITOR_PC_ROW, label = "BALL COLORS",
      onSelect = function(_menu, liveGame)
        openColorEditor(liveGame or game)
      end,
    }
    local at = #out + 1
    for i, row in ipairs(out) do
      if row.id == "decoration" or row.cancel or row.id == "cancel" then
        at = i
        break
      end
    end
    table.insert(out, at, editor)
    return out
  end)

  -- Gen 2's bedroom item-PC menu predates generic onSelect rows. The storage
  -- PC and every Gen 1 PC already call them directly, so this narrow adapter
  -- is needed only when that module exists.
  local okItemPc, Gen2ItemPc = pcall(require, "src.ui.gen2.ItemPcMenu")
  if okItemPc and type(Gen2ItemPc) == "table"
     and type(Gen2ItemPc.choose) == "function" then
    Gen2ItemPc._pbcEditorOriginals = Gen2ItemPc._pbcEditorOriginals
      or { choose = Gen2ItemPc.choose }
    local vanillaItemPcChoose = Gen2ItemPc._pbcEditorOriginals.choose
    Gen2ItemPc.choose = function(menu, ...)
      local row = menu.entries and menu.entries[menu.index]
      if row and row.id == EDITOR_PC_ROW and type(row.onSelect) == "function" then
        row.onSelect(menu, menu.game)
        return
      end
      return vanillaItemPcChoose(menu, ...)
    end
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
  -- (activeBattle is forward-declared at the top; see the note there)
  BattleState.ballChain = function(self, tossAnim, caught, shakes, ball)
    self._pbcBall = ball
    activeBattle = self
    -- verdict on the chain that just finished: we had a colour for that
    -- ball and our palette never reached it, so something else is drawing
    -- the ball animation
    if chainWanted and not bandColorRan and not conflictDetected then
      conflictDetected = true
      mod.log:warn("another mod is drawing the ball animation without this "
        .. "mod's palette; deferring to its art unless the player has asked "
        .. "to override")
      Runtime.reportError("pokeball_colors", "another mod owns ball art")
    end
    throwCache = {}          -- a new throw re-asks every resolver exactly once
    bandColorRan = false
    chainWanted = ball ~= nil and mod.options:get("enabled")
      and PaletteFX.mode == "redpp"
      and resolveEntry(ball, { ball = ball, surface = "battle",
                               battle = self, game = gameRef }) ~= nil
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

  -- ------------------------------------------------------------------
  -- THE REAL BALL, for the editor preview.
  --
  -- The upright resting ball is two 8x8 tiles stacked, with the right half
  -- an X-mirror of the left.  The art is byte-identical on both
  -- generations -- verified against the developer's own imported red/ and
  -- gold/ caches on 2026-08-29 -- so one builder serves both; only the
  -- sheet lookup differs:
  --
  --   Gen 1  battle_anims.tilesheets[0], tiles 2 (top) and 18 (bottom),
  --          which is what the BAND_TILES note above calls the upright ball.
  --   Gen 2  battle_anims.gfx.BATTLE_ANIM_GFX_POKE_BALL, tiles 0 and 1.
  --          That is BATTLE_ANIM_OAMSET_0A (x -8/0, y -8/0, attr 32 =
  --          X-flip), which FRAMESET_POKE_BALL_4 plays as its single
  --          resting frame.
  --
  -- Only the tile INDICES are in this repo.  The pixels are read from the
  -- player's own imported cache every session, exactly as bandSheet does,
  -- so no ROM-derived art enters the repo or the zip.
  --
  -- Colours are BAKED into a 16x16 image rather than sent through a
  -- palette shader.  The preview is drawn with the shader deliberately
  -- cleared (see drawBallPreview), and baking is the one form that
  -- survives both generations' very different present passes unchanged.
  --
  -- Which region the third colour paints is decided HERE, from the same
  -- inputs the throw uses, so the swatch cannot disagree with the ball:
  --   * Gen 2 has no re-indexed art -- slot 3 is the outline, always.
  --   * Gen 1 with the band option ON and a `line` colour: the seam
  --     becomes the third colour and the outline joins the body, which is
  --     exactly what the BAND_TILES re-index does.
  --   * Gen 1 with an `outline` colour: slot 3 is the outline.
  --   * Band option OFF: slot 3 falls back to the body, matching
  --     thirdColor returning nil.
  -- ------------------------------------------------------------------
  local BALL_ART_W, BALL_ART_H = 16, 16
  -- ball pixels occupy x 2..13, y 4..15 of that 16x16 once mirrored
  local BALL_ART_BOX = { x = 2, y = 4, w = 12, h = 12 }

  -- Failures here report to [ERRS], not just mod.log: the developer tests on
  -- iOS where there is no console, and a failed art load looks exactly like
  -- "the update did nothing" -- which is precisely how 0.1.44's wrong data
  -- key survived a device round trip.  Same reasoning as bandFail below.
  local artFailed = false
  local function artFail(fmt, ...)
    if artFailed then return end             -- once, not per frame
    artFailed = true
    local msg = string.format(fmt, ...)
    mod.log:warn("%s", msg)
    Runtime.reportError("pokeball_colors", msg)
  end

  local ballSrc      -- { top = grid, bottom = grid } | false
  local ballArtCache -- key -> Image

  -- grey value -> DMG index.  255 is index 0, which the OAM layer draws as
  -- transparent, so it stays transparent here too.
  local function shadeIndex(v)
    if v > 212 then return 0 end
    if v > 127 then return 1 end
    if v > 42  then return 2 end
    return 3
  end

  local function ballSource(game)
    if ballSrc ~= nil then return ballSrc or nil end
    ballSrc = false
    -- The two generations file this table under DIFFERENT keys, which is
    -- the whole reason 0.1.44's preview silently fell back to primitives on
    -- Gold: Gen 1 is game.data.battle_anims (BattleState.lua:670 hands it
    -- straight to AnimPlayer.new), Gen 2 is game.data.gen2BattleAnims
    -- (Game2.lua:939, read as self.anims at gen2/BattleState.lua:293).
    local data = game and game.data
    local anims = data and (data.gen2BattleAnims or data.battle_anims)
    if not (anims and love and love.image) then
      artFail("ball preview: no battle_anims table on this boot")
      return nil
    end
    local ok, res = pcall(function()
      local path, topTile, botTile
      local gfx = anims.gfx and anims.gfx.BATTLE_ANIM_GFX_POKE_BALL
      if gfx and gfx.image then
        path, topTile, botTile = gfx.image, 0, 1
      else
        local sheet = anims.tilesheets and anims.tilesheets[0]
        path, topTile, botTile = sheet and sheet.path, 2, 18
      end
      if not path then return nil end
      -- Assets.resolve turns the Gen 2 cache's relative asset path into a
      -- real one; the Gen 1 tilesheet path is already absolute and passes
      -- through.  Falls back to a raw read if resolution ever fails.
      local okData, id = pcall(Assets.imageData, path)
      if not okData or not id then id = love.image.newImageData(path) end
      local cols = math.floor(id:getWidth() / 8)
      local function grid(tile)
        local tx, ty = (tile % cols) * 8, math.floor(tile / cols) * 8
        local out = {}
        for y = 0, 7 do
          for x = 0, 7 do
            local r = id:getPixel(tx + x, ty + y)
            out[y * 8 + x + 1] = shadeIndex(math.floor(r * 255 + 0.5))
          end
        end
        return out
      end
      return { top = grid(topTile), bottom = grid(botTile) }
    end)
    if not (ok and res) then
      artFail("ball preview: art read failed (%s)", tostring(res))
      return nil
    end
    ballSrc = res
    return res
  end

  -- tile-local seam pixels, taken from the one table that already knows
  -- them rather than restated here
  local function seamSet(tile)
    local out = {}
    for _, pix in ipairs(BAND_TILES[tile] and BAND_TILES[tile].line or {}) do
      out[pix[2] * 8 + pix[1] + 1] = true
    end
    return out
  end

  previewBallArt = function(game, entry, bandOn, gen2)
    local src = ballSource(game)
    if not (src and entry and entry.body and entry.accent) then return nil end
    local third = entry.third or entry.line or entry.outline
    -- which region slot 3 paints, and whether the seam is repainted
    local seamIsThird = (not gen2) and bandOn and entry.style ~= "outline"
    local outlineColor
    if seamIsThird then
      outlineColor = entry.body                     -- outline joins the body
    elseif gen2 or bandOn then
      outlineColor = third or entry.body
    else
      outlineColor = entry.body                     -- thirdColor returns nil
    end
    local seamColor = seamIsThird and third or nil

    local key = table.concat({
      tostring(entry.body[1]), entry.body[2], entry.body[3],
      entry.accent[1], entry.accent[2], entry.accent[3],
      third and third[1] or "-", third and third[2] or "-",
      third and third[3] or "-",
      seamIsThird and "S" or "O", gen2 and "2" or "1", bandOn and "B" or "n",
    }, ",")
    ballArtCache = ballArtCache or {}
    if ballArtCache[key] then return ballArtCache[key] end

    local seamTop = seamSet((gen2 and 0) or 2)
    local seamBot = seamSet((gen2 and 1) or 18)
    local ok, image = pcall(function()
      local id = love.image.newImageData(BALL_ART_W, BALL_ART_H)
      local function put(x, y, c)
        if not c then return end
        id:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, 1)
      end
      for half = 0, 1 do
        for row = 0, 1 do
          local grid = row == 0 and src.top or src.bottom
          local seam = row == 0 and seamTop or seamBot
          for y = 0, 7 do
            for x = 0, 7 do
              local i = grid[y * 8 + x + 1]
              local c
              if i == 1 then c = entry.accent
              elseif i == 2 then c = (seam[y * 8 + x + 1] and seamColor)
                                     or entry.body
              elseif i == 3 then c = outlineColor end
              -- half 1 is the X-mirror the OAM set draws with attr 32
              local dx = half == 0 and x or (BALL_ART_W - 1 - x)
              put(dx, row * 8 + y, c)
            end
          end
        end
      end
      return love.graphics.newImage(id)
    end)
    if not (ok and image) then
      artFail("ball preview: bake failed (%s)", tostring(image))
      return nil
    end
    ballArtCache[key] = image
    return image
  end

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

  -- ------------------------------------------------------------------
  -- Taking the ball back, when the player asks for it.
  --
  -- The shader route is closed here by construction: the other mod passes
  -- `colorFn = nil`, so nothing repaints the tiles whatever we return.  So
  -- do not fight for the shader -- bake the colours into the pixels and
  -- hand over an image that needs no palette at all.
  --
  -- Built from the ENGINE's own generated sheet, never from whatever that
  -- mod is serving, so the shape is always the vanilla ball and the result
  -- is deterministic.  Classified by grey value rather than by the
  -- BAND_TILES coordinate table, because here every ball pixel needs a
  -- colour, not just the ones that move index.
  --
  -- What this loses, and it is worth knowing: a baked ball cannot follow
  -- the zone palette and cannot strobe, so the MASTER/ULTRA toss flicker
  -- goes flat.  That is the honest cost of another mod owning the draw,
  -- and it only applies when the player has asked us to override.
  -- ------------------------------------------------------------------
  local bakedCache = {}
  local function bakedSheet(ap, ball)
    local entry = resolveEntry(ball, { ball = ball, surface = "battle",
                                       battle = activeBattle, game = gameRef })
    if not entry then return nil end
    local key = table.concat(entry.body, ",") .. "/"
      .. table.concat(entry.accent, ",") .. "/"
      .. (entry.line and table.concat(entry.line, ",") or "-")
    local hit = bakedCache[key]
    if hit ~= nil then return hit or nil end
    bakedCache[key] = false

    local sheet = ap and ap.data and ap.data.tilesheets
                  and ap.data.tilesheets[0]
    if not (sheet and sheet.path and love and love.image
            and love.image.newImageData and love.graphics
            and love.graphics.newImage) then
      return nil
    end
    local ok, img = pcall(function()
      local id = love.image.newImageData(sheet.path)
      local cols = math.floor(id:getWidth() / 8)
      -- baked art is built from the VANILLA sheet, where index 3 is the
      -- outline ring -- so a `line` ball's band cannot appear here and its
      -- colour lands on the rim instead.  An `outline` ball is exact.
      local slot = { entry.accent, entry.body,
                     entry.line or entry.outline or entry.body }
      for tile in pairs(BAND_TILES) do
        local tx, ty = (tile % cols) * 8, math.floor(tile / cols) * 8
        for y = 0, 7 do
          for x = 0, 7 do
            local r, _, _, a = id:getPixel(tx + x, ty + y)
            if a > 0 then
              -- 170 / 85 / 0 are DMG indices 1 / 2 / 3 (gfx.py GB_SHADES)
              local index = (r > 0.66 and 1) or (r > 0.16 and 2) or 3
              local c = slot[index]
              id:setPixel(tx + x, ty + y,
                          c[1] / 255, c[2] / 255, c[3] / 255, 1)
            end
          end
        end
      end
      return love.graphics.newImage(id)
    end)
    if not (ok and img) then
      bandFail("no ball takeover: could not bake the sheet (%s)",
               tostring(img))
      return nil
    end
    bakedCache[key] = img
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
  -- ------------------------------------------------------------------
  -- The third colour comes in two flavours, because the vanilla art and
  -- the re-indexed art put different REGIONS on DMG index 3:
  --
  --   `outline` -- the perimeter ring, which is what index 3 already is on
  --                the untouched sheet.  No art swap, so it composes with
  --                everything and costs nothing.
  --   `line`    -- the seam band between the two halves.  Those pixels are
  --                index 2 on the vanilla sheet, so this one needs the
  --                re-indexed art (see BAND_TILES) and is the only reason
  --                that sheet exists.
  --
  -- Both land in slot 3; they differ only in which sheet is served.  A ball
  -- may set either.  If it sets both, `line` wins -- the band is the more
  -- specific request, and the outline then keeps the body colour as it did
  -- before either key existed.
  -- ------------------------------------------------------------------
  local function thirdColor(ball)
    if not ball then return nil end
    if PaletteFX.mode ~= "redpp" then return nil end
    if not mod.options:get("enabled") then return nil end
    local c = resolveEntry(ball, { ball = ball, surface = "battle",
                                   battle = activeBattle, game = gameRef })
    if not c then return nil end
    return c.line or c.outline
  end

  -- Does this ball need the RE-INDEXED sheet?  Only a `line` does.
  local function bandColor(ball)
    if not ball then return nil end
    if conflictDetected then return nil end
    -- never serve the re-indexed sheet before our palette is known to land
    -- on it; blitted raw it is grey with a black band
    if not colorPassEverRan then return nil end
    if PaletteFX.mode ~= "redpp" then return nil end
    if not mod.options:get("enabled") then return nil end
    local c = resolveEntry(ball, { ball = ball, surface = "battle",
                                   battle = activeBattle, game = gameRef })
    return c and c.line or nil
  end

  -- The ULTRA BALL looks like it turns upside down during the toss and
  -- settles at the wobbles.  That is not this feature and not a bug: the
  -- Master/Ultra toss flickers on hardware.  BattleState:ballFlicker
  -- returns `false` for a ball without flicker and its caller writes
  -- `item.ball and self:ballFlicker(item.ball) or nil`, which collapses
  -- false to nil, so AnimPlayer falls through to its own hardcoded
  -- `ball == MASTER_BALL or ULTRA_BALL` test (AnimPlayer.lua:447-455).
  -- Those frames arrive tagged "f0x" and the wrap below swaps the pair on
  -- f0x deliberately, to keep the strobe in the ball's own colors; under
  -- ULTRA's near-black accent that reads as inversion, and it stops at the
  -- shake because SHAKE_ANIM never flickers.  Do not "fix" it.

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
  -- 0.1.32: the takeover no longer waits to DETECT anything.  "My ball
  -- colors over other mods" means what it says -- every ball we have a
  -- colour for is painted by us, from the first throw, whether or not
  -- another mod is installed and whichever balls it happens to replace.
  --
  -- 0.1.30 and 0.1.31 both hung the takeover off conflict detection, and
  -- both shipped a hole in it: first every bandless ball (PREMIER), then
  -- the balls that mod ships dedicated art for (POKE, GREAT, ULTRA,
  -- MASTER).  A switch the player has already thrown should not be
  -- conditional on us inferring anything.
  --
  -- Detection still runs, but only for the OFF case, where the question is
  -- "should we stand aside" rather than "may we act".
  AnimPlayer.sheetImage = function(self, ts)
    if ts == 0 and self._pbcMove and BALL_MOVES[self._pbcMove]
       and mod.options:get("enabled") and PaletteFX.mode == "redpp" then
      local ball = ballOf(self)
      if ball then
        if mod.options:get("ball_art_takeover") then
          local img = bakedSheet(self, ball)
          if img then return img end
        elseif not conflictDetected and bandColor(ball) then
          local img = bandSheet(self)
          if img then return img end
        end
      end
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

    local c = ball and resolveEntry(ball, { ball = ball, surface = "battle",
                                            battle = self, game = gameRef })
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
    -- Under takeover the sheet ALREADY carries our colours as real pixels,
    -- so a palette pass would remap them through the shader's red-channel
    -- buckets and wreck them -- a baked red body reads as the transparent
    -- slot.  Returning nil is what tells drawSprites to blit as-is.
    if mod.options:get("ball_art_takeover") then
      bandColorRan = true
      return nil
    end

    local third = thirdColor(ball)
    bandColorRan, colorPassEverRan = true, true
    return { accent, body, third and norm(third) or body }
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
  --
  -- A ball with a RESOLVER has no fixed colour, so the ball id alone is not
  -- enough to redraw it later: "what colour was this caught in" has to be
  -- answered now, while the context that decided it still exists.  A
  -- KECLEON BALL caught against a forest is a forest colour forever, and
  -- the Center is a room with nothing to camouflage against.
  --
  -- So the resolved answer is snapshotted onto the mon beside the ball id,
  -- on both generations:
  --   mon.caughtBallColor   -- Gen 1: the {body,accent,line} entry
  --   mon.caughtBallPalette -- Gold:  the PAL_BATTLE_OB_* name
  -- Only written for balls that actually have a resolver / a Gold palette,
  -- so a normal ball adds no bytes to the save.
  --
  -- The resolver is asked once more here rather than reusing the throw
  -- cache, because the catch may resolve after the chain cleared it.  That
  -- assumes a resolver is stable within one battle -- true for anything
  -- keyed on the opponent or the terrain, which is what "camouflage" means.
  mod.events:on("pokemon.caught", function(p)
    if not (p and p.mon and p.ball) then return end
    if p.mon.caughtBall == nil then p.mon.caughtBall = p.ball end
    -- Pin ONLY for a resolver.  0.1.42 and earlier also pinned when the ball
    -- had a saved player override, which froze that colour onto the mon: the
    -- player then edited POKE BALL in the editor and every mon already caught
    -- in one kept the old colour in the Center, while the starter (never
    -- caught, so never pinned) tracked the edit and looked like the odd one
    -- out.  A static override needs no pin -- resolveEntry consults
    -- savedEntry first, so a live lookup already returns it, and it stays
    -- live when the player edits it again.
    if p.mon.caughtBallColor == nil and RESOLVERS[p.ball] then
      local entry = resolveEntry(p.ball, { ball = p.ball, surface = "catch",
                                           battle = p.battle, mon = p.mon,
                                           game = p.game or gameRef })
      if entry then
        -- a copy, not the resolver's table: it is theirs and may be reused
        p.mon.caughtBallColor = entryCopy(entry)
      end
    end
    -- Same rule on Gold: a saved override resolves live through the wrapped
    -- ballPalette, so pinning it only makes a later edit invisible.
    if p.mon.caughtBallPalette == nil and p.mon.caughtBallPaletteRow == nil
       and goldPinFor and not savedEntry(p.ball) then
      local name, row = goldPinFor(p.ball, p.mon, p.battle)
      -- a SYMBOLIC name (PAL_BATTLE_OB_ENEMY) means "whatever is in front of
      -- you", which is meaningless once the battle is over -- pin the
      -- resolved colours instead.  A plain name pins as a name: smaller, and
      -- it keeps following its mod if that mod retunes the palette later.
      if row then p.mon.caughtBallPaletteRow = row
      elseif name then p.mon.caughtBallPalette = name end
    end
  end)

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

  -- Capability gate, not a version check: on a Gen 2 boot this require
  -- resolves to the adapter facade, where drawWorld has no backing and
  -- reads nil (gen2check MK404).  Installing over it would write a wrapper
  -- nothing calls and stash a nil "original", so skip it entirely and
  -- leave the Center alone there.  Gold's heal machine is a different
  -- screen with its own seam, which the Gold block at the bottom of this
  -- file wraps instead.
  --
  -- gen2check STILL reports MK404 on the two lines inside this `if`, and
  -- the finding is a false positive: the branch genuinely does not run on
  -- Gold.  MEASURED on v0.1.79, so the next audit does not have to re-run
  -- it -- this is not "we think it cannot be fixed", it is tested:
  --
  --   * guard detection is PER-LINE syntax, not block-level
  --     (tools/modkit.py:2652): the member must be immediately followed by
  --     and/or/then/)/~=/== , or immediately preceded by if/and/or/not.
  --   * spelling the READ as `... = OverworldState.drawWorld or nil` DOES
  --     satisfy it and drops that line to a warning.
  --   * the WRITE cannot be satisfied at all.  `X.y = ...` matches neither
  --     shape, and there is no legal spelling of "wrap this function" that
  --     does.  Aliasing does not help either: the scanner follows the
  --     module through locals and bracket indexes.
  --   * so the best reachable result is 1 error instead of 2, still FAIL.
  --     Not worth redundant `or nil` noise inside a block that has already
  --     type-checked the member.
  --
  -- Which leaves it a tooling gap, not a defect here.  Do NOT rewrite this
  -- into a dynamic index to silence it: that turns the finding into an
  -- `unresolved:` note and hides the next REAL one at this site.
  --
  -- There is also no alternative seam.  fxHeal is a local closure inside
  -- drawWorld, and no world/heal hook exists on either generation
  -- (grepped Runtime.call across src/ at 0.1.79), so wrapping drawWorld is
  -- the only Gen 1 route.  Gold has its own seam, wrapped at the bottom of
  -- this file.
  if type(OverworldState.drawWorld) == "function" then
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
        -- A player override is LIVE and outranks the snapshot, so editing a
        -- ball repaints every mon already caught in one -- including mons
        -- carrying a stale pin written by 0.1.42 or earlier.  Below it, the
        -- snapshot: a dynamic ball's colour was decided at catch.
        -- The pin is trusted only for a ball that actually HAS a resolver.
        -- 0.1.42 and earlier also pinned static overrides, so a save can carry
        -- a frozen colour for an ordinary ball; honouring it would make the
        -- old colour reappear the moment the player pressed RESTORE DEFAULT.
        local c = savedEntry(ball)
          or (RESOLVERS[ball] and mon and mon.caughtBallColor)
          or resolveEntry(ball, { ball = ball, surface = "center",
                                  mon = mon, game = gameRef })
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
  end -- drawWorld capability gate

  -- ------------------------------------------------------------------
  -- GOLD: the heal machine (0.1.22)
  --
  -- Gold normally colours a ball THROW itself from the cart's own
  -- ball_colors.asm (src/ui/gen2/BattleState.lua:2672). The editor now
  -- supplies a private palette row only when the player saved an override.
  -- The Pokemon Center remains the other gap: World:drawHealAnim paints
  -- every ball through ONE palette
  -- (src/world/gen2/World.lua:6288-6327), so a party of six lands six
  -- identical lights whatever caught them.
  --
  -- Three things make this cheap, all verified rather than assumed:
  --   * `pokemon.caught` fires on Gold with the SAME name and the same
  --     payload keys, `ball` included -- the engine says so in as many
  --     words at src/ui/gen2/BattleState.lua:2283-2295 ("one subscription
  --     covers both games").  So the mon.caughtBall handler above already
  --     works there, unchanged, with no branch.
  --   * Gen 2 saves through the same generic SaveSerializer
  --     (src/core/gen2/Save.lua:11), so the field persists as it does on
  --     Red.
  --   * The balls are drawn one per party member in party order, through a
  --     stable quad identity -- the same shape the Gen 1 shim above keys
  --     off, so the technique carries over.
  --
  -- The colour comes from the ENGINE, not from the COLORS table above:
  -- ballPalette(id) names a palette and gen2Palettes.battleObjects holds
  -- it.  That is deliberate and it is the whole reason this is cheap --
  -- the Center then matches what the throw actually looked like, for
  -- native balls AND for any mod ball whose own mod registered a palette
  -- (Too Many Balls, mod id kanto_balls, 0.4.2+ -- it owns that wrap,
  -- declares exports.owns.ballPalettesGen2 and exposes
  -- registerBallPalette).  One
  -- source of truth, no second colour table to drift, and no coordination
  -- between the two mods.  A ball nobody registered throws grey and lights
  -- grey, which is correct: the fix is to register it, and that fixes
  -- both at once.
  -- ------------------------------------------------------------------
  local function installGoldCenter(game)
    local okGP, GbcPalette = pcall(require, "src.render.GbcPalette")
    local okW, World = pcall(require, "src.world.gen2.World")
    local okBS, BS2 = pcall(require, "src.ui.gen2.BattleState")
    if not (okGP and okW and okBS
            and type(World) == "table"
            and type(World.drawHealAnim) == "function"
            and type(BS2) == "table"
            and type(BS2.ballPalette) == "function") then
      Runtime.reportError("pokeball_colors",
        "Gold Center: seam missing, balls stay uncoloured")
      return
    end

    -- ballPalette is written as a method but reads nothing off self
    -- (src/ui/gen2/BattleState.lua:2101).  kanto_balls wraps it, and we
    -- WANT its answer, so call through rather than reimplementing the
    -- table -- with a dummy self, and in pcall, because that wrap is
    -- another mod's code and may not share the assumption.
    local okPal, Palettes = pcall(require, "src.world.gen2.Palettes")

    -- `self` matters: Too Many Balls' KECLEON BALL answers
    -- "PAL_BATTLE_OB_ENEMY" when `self.battle.enemy` exists, and its own
    -- green otherwise.  Passing a bare {} asks the question with the
    -- context removed, which is how 0.1.25 pinned every Kecleon catch as
    -- green.  Hand it something shaped like the screen instead.
    local function nameFor(ballId, battle)
      local okName, name = pcall(BS2.ballPalette, { battle = battle }, ballId)
      if okName and type(name) == "string" then return name end
      return nil
    end

    local function rowForName(name)
      local set = game.data and game.data.gen2Palettes
        and game.data.gen2Palettes.battleObjects
      local row = name and set and set[name]
      if type(row) == "table" and #row > 0 then return row end
      return nil
    end

    -- A player override becomes a private battle-object palette row. Returning
    -- its name from the existing ballPalette seam makes native and mod-added
    -- balls use the same saved scheme without changing either ball record.
    local CUSTOM_GOLD_PREFIX = "PBC_CUSTOM_"
    local function customGoldPalette(ballId)
      local entry = savedEntry(ballId)
      -- 0.1.52: with nothing saved, the cart's OWN balls take this mod's
      -- colourway rather than the cart's.  That is the point of the mod and
      -- it is what the option name promises; before this it only ever
      -- decorated the Center and left every Gold throw alone.  Scoped to
      -- BALL_PRESETS -- the thirteen cart balls -- so a ball another mod
      -- added keeps its author's registered palette.  Too Many Balls
      -- declares exports.owns.ballPalettesGen2; overriding it unasked would
      -- cross that line.
      if not entry and assertsGoldDefault(ballId) then
        entry = entryFromPreset(defaultPreset(ballId))
      end
      if not entry then return nil end
      local third = entry.line or entry.outline or entry.body
      local name = CUSTOM_GOLD_PREFIX .. tostring(ballId)
      local set = game.data and game.data.gen2Palettes
        and game.data.gen2Palettes.battleObjects
      if set then
        set[name] = {
          { 255, 255, 255 }, rgbCopy(entry.accent),
          rgbCopy(entry.body), rgbCopy(third),
        }
        return name
      end
      return nil
    end

    BS2._pbcEditorOriginals = BS2._pbcEditorOriginals
      or { ballPalette = BS2.ballPalette }
    local vanillaGoldBallPalette = BS2._pbcEditorOriginals.ballPalette
    -- goldSeed reads ORIGINAL through this, never through the live member
    goldBallPaletteBase = vanillaGoldBallPalette
    BS2.ballPalette = function(self, ballId)
      return customGoldPalette(ballId)
        or vanillaGoldBallPalette(self, ballId)
    end

    -- What to remember about a ball at the moment it catches something.
    --
    -- Two shapes come back from ballPalette.  A plain name indexes
    -- battleObjects and is pinned as-is.  The SYMBOLIC ones the engine
    -- special-cases -- PAL_BATTLE_OB_ENEMY / _PLAYER -- are not in that
    -- table at all; objPalette resolves them against the LIVE battle
    -- (BattleAnimView.lua:95-103).  A Pokemon Center has no battle, so a
    -- pinned symbolic name would draw unpaletted.  Resolve it here, while
    -- the answer still exists -- and the thing it refers to is precisely
    -- the mon being caught, which is why this reads so naturally: a
    -- KECLEON BALL that caught a PIKACHU is Pikachu-coloured forever.
    goldPinFor = function(ballId, mon, battle)
      local name = nameFor(ballId, battle)
      if not name then return nil, nil end
      -- A custom row is mutable while the player edits it. Snapshot the row
      -- onto the caught mon so the heal machine preserves the colour that was
      -- actually thrown, even if this ball is redesigned later.
      if name:sub(1, #CUSTOM_GOLD_PREFIX) == CUSTOM_GOLD_PREFIX then
        local row = rowForName(name)
        if row then
          local copy = {}
          for i = 1, #row do copy[i] = rgbCopy(row[i]) end
          return nil, copy
        end
      end
      if rowForName(name) then return name, nil end          -- plain: pin the name
      if okPal and Palettes and Palettes.monColors and mon and mon.species then
        local row = Palettes.monColors(game.data and game.data.gen2Palettes,
                                       mon.species, mon.shiny)
        if type(row) == "table" and #row > 0 then return nil, row end
      end
      return name, nil
    end

    World._pbcOriginals = World._pbcOriginals or {}
    World._pbcOriginals.drawHealAnim = World._pbcOriginals.drawHealAnim
      or World.drawHealAnim
    local vanillaDrawHeal = World._pbcOriginals.drawHealAnim
    World.drawHealAnim = function(self, ...)
      local ha = self.healAnim
      if not (ha and mod.options:get("enabled")
              and mod.options:get("center_balls")) then
        return vanillaDrawHeal(self, ...)
      end

      -- the machine's own flash: eight rotations of the OBJ palette, which
      -- the engine folds in as an rBGP-style byte.  Rebuilt here from the
      -- same rotation so a recoloured ball flashes with the rest instead
      -- of sitting still through the jingle (World.lua:6309-6312).
      local byte = 0
      for i = 0, 3 do byte = byte + ((i + ha.rotation) % 4) * (4 ^ i) end

      local lg = love.graphics
      local vanillaDraw = lg.draw
      local ballIndex = 0
      lg.draw = function(img, quad, ...)
        local quads = self.healMachineQuads
        if img ~= nil and img == self.healMachineImage
           and quads and quad == quads.ball then
          ballIndex = ballIndex + 1
          local party = game.save and game.save.party
          local mon = party and party[ballIndex]
          -- A player override is LIVE and outranks the pin (same rule as the
          -- Gen 1 Center above), so an edit reaches mons already caught and
          -- heals a stale pin left by 0.1.42 or earlier.  Then the pinned
          -- name, then a live lookup for older catches.
          local ballId = (mon and mon.caughtBall) or "POKE_BALL"
          -- A pinned NAME beginning with the custom prefix is a static
          -- override frozen by 0.1.42 or earlier, not a dynamic ball's
          -- answer; drop it so RESTORE DEFAULT cannot bring it back.  A
          -- pinned ROW is only ever written for a symbolic palette, which
          -- genuinely is "the colour it was caught with".
          local pinnedName = mon and mon.caughtBallPalette
          if pinnedName
             and pinnedName:sub(1, #CUSTOM_GOLD_PREFIX) == CUSTOM_GOLD_PREFIX then
            pinnedName = nil
          end
          local row = (savedEntry(ballId) and rowForName(nameFor(ballId, nil)))
            or (mon and mon.caughtBallPaletteRow)
            or rowForName(pinnedName or nameFor(ballId, nil))
          if row and GbcPalette.available() then
            local prev = lg.getShader()
            GbcPalette.useRaw(
              GbcPalette.remap(GbcPalette.resolve(row), byte))
            vanillaDraw(img, quad, ...)
            lg.setShader(prev)
            return
          end
        end
        return vanillaDraw(img, quad, ...)
      end

      local ok, err = pcall(vanillaDrawHeal, self, ...)
      lg.draw = vanillaDraw
      if not ok then error(err) end
    end

    -- Elm's three starter balls share SPRITE_POKE_BALL. Their stable native
    -- object-event indices distinguish them: 3 Cyndaquil, 4 Totodile, 5
    -- Chikorita. Bake a native OBJ palette without mutating map data.
    local elmBallPalette = {
      [3] = "PAL_OW_RED",
      [4] = "PAL_OW_BLUE",
      [5] = "PAL_OW_GREEN",
    }
    if okPal and Palettes
       and type(World.applySpritePalette) == "function" then
      World._pbcOriginals.applySpritePalette =
        World._pbcOriginals.applySpritePalette or World.applySpritePalette
      local vanillaApplySpritePalette = World._pbcOriginals.applySpritePalette
      World.applySpritePalette = function(self, entity)
        local map = self.map
        local def = entity and entity.def
        local paletteName = map and map.id == "ELMS_LAB"
          and def and def.sprite == "SPRITE_POKE_BALL"
          and elmBallPalette[def.index]
        if mod.options:get("enabled") and paletteName
           and self.palettes and entity.sprite then
          local daytime = self.daytime or "DAY"
          local set = Palettes.objectSet(self.palettes, daytime)
          local slot = Palettes.OW_PALETTE_ID[paletteName]
          local colors = set and slot and set[slot]
          if colors then
            entity.sprite:setObjPalette(colors,
              ("pbc:elm:%s:%s"):format(daytime, paletteName))
            return
          end
        end
        return vanillaApplySpritePalette(self, entity)
      end
    else
      Runtime.reportError("pokeball_colors",
        "Gold starters: overworld palette seam missing")
    end

    -- Vanilla `_CGB_Pokepic` deliberately uses the map's grey ramp. Give
    -- every Gold pokepic its species' native palette instead. This keeps
    -- mod-authored starter selectors (Trainer Journey is the first) from
    -- needing a hard-coded species list or a dependency on this mod.
    if okPal and Palettes and type(Palettes.monColors) == "function"
       and type(World.showPokePic) == "function" then
      World._pbcOriginals.showPokePic = World._pbcOriginals.showPokePic
        or World.showPokePic
      local vanillaShowPokePic = World._pbcOriginals.showPokePic
      World.showPokePic = function(self, speciesIndex)
        vanillaShowPokePic(self, speciesIndex)
        local id = self.pokePicName
        if mod.options:get("enabled") and id then
          self.pokePicColors = Palettes.monColors(self.palettes, id, false)
            or self.pokePicColors
        end
      end
    else
      Runtime.reportError("pokeball_colors",
        "Gold starters: preview palette seam missing")
    end

    mod.log:info("pokeball_colors: Gold colouring installed")
  end

  -- Capability, not a version name: gen2Palettes existing IS the Gen 2
  -- boot, and it is the very table the colours are read out of.  game.ready
  -- is the first point game.data is populated.
  mod.events:on("game.ready", function(p)
    local game = p and p.game
    if game and game.data and game.data.gen2Palettes then
      installGoldCenter(game)
    end
  end)

  mod.log:info("pokeball_colors %s loaded", VERSION)
end
