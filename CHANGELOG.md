# Changelog

All notable changes to Pokeball Colors are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com); the top heading
always matches the version in `manifest.json`.

## 0.1.15
- **Thrown balls can have a black band.** The four native balls whose art
  has one -- POKe, GREAT, MASTER and SAFARI -- now throw with a black band
  along the seam between the two halves, through the toss, the wobbles and
  the resting caught ball. New toggle "Black band on thrown balls"
  (default ON) turns it off again.
- ULTRA BALL is left two-tone on purpose: its dark half is already nearly
  black, so a band there would read as nothing.
- Mod authors: a color entry takes an optional third key,
  `line = {r,g,b}`, alongside `body` and `accent`. Leave it out and the
  ball renders exactly as it does today. Balls from Custom Poke Balls,
  Kanto Balls and Snag Quest are unchanged in this version -- their own
  mods decide whether to opt in.
- The band does not flash during the MASTER/ULTRA toss flicker. That
  matches the hardware, whose flicker only ever swapped the other two
  shades.
- The POKeMON CENTER machine is untouched in this version; whether its
  balls should pick up the band is a separate question that needs a
  screenshot first.

## 0.1.14
- `registerColors` now states in code that a color entry is **opaque past
  the keys it validates**: unknown keys are stored untouched instead of
  rejected, so a mod written against a newer version of this mod still
  registers cleanly against an older copy.
- An RGB list is validated as **at least** three numbers rather than
  exactly three. Only the first three are ever read; a longer list is the
  caller's business. No behavior change for any existing registration.

## 0.1.13
- New `exports.registerColors(colors)` for other ball mods: pass a table
  of `id -> { body, accent }` and this mod owns the only-if-absent rule,
  validation, and logging. Replaces the hand-rolled game.ready loop each
  mod was writing (and could get subtly wrong).
- `mon.caughtBall` is now a documented public field, declared in
  `exports.owns.caughtBallField`. Other mods may READ it (e.g. a ribbon
  for a ball type); this mod owns writing it. Nil on mons caught before
  0.1.12 or without this mod installed -- always nil-check.
- A ball that renders with no registered color now logs one warning
  naming the ball id, instead of silently falling back to vanilla.

## 0.1.12
- Pokemon Center: the heal machine's balls now render in the colors of
  the ball each party member was actually caught in (ADVANCED mode; new
  toggle "Colored balls at POKeMON CENTER", default ON). The machine's
  jingle flash is preserved in each ball's own colors.
- Caught-ball memory: the mod now records the ball on the mon at catch
  time (persists through saves). Mons caught before 0.1.12 default to
  Poke Ball red at the machine.

## 0.1.11
- Docs only, no code change: the mod's canonical name is **Custom Poké
  Balls** (by magalvao, github.com/magalvao/custom-pokeballs) -- 0.1.10
  renamed it to "New Pokeballs" from the `name` field of an older v1.0.1
  build. Corrected and linked throughout.

## 0.1.10
- Docs only, no code change: the nine extra balls come from a mod whose
  display name is **New Pokeballs** (its mod id is `custom_pokeballs`,
  which is what these docs had been calling it). Corrected throughout.

## 0.1.9
- Manifest `github` field corrected to `mistermiracle3036/Pokeball-Colors`
  so it matches the repository's actual URL slug exactly. No code change.

## 0.1.8
- Snag Quest owns its ball outright. Removed the hardcoded SNAG_BALL
  color entry: snag_quest 0.11.x+ registers its own color into
  `exports.colors` on game.ready when the key is absent, so the ball is
  colored by its owner and the two mods no longer duplicate a value that
  could silently drift apart.
- Publishes `exports.owns = { colors = true }`, and logs snag_quest's
  version and ownership declaration on load.
- Requires snag_quest 0.11.x or newer for a colored SNAG BALL. On 0.10.x
  the ball throws in vanilla colors (nothing breaks).

## 0.1.7
- In-launcher updates: manifest now declares
  `"github": "mistermiracle3036/pokeball-colors"`, so once installed the
  mod browser detects new GitHub releases and offers Update in place.
  No code change.

## 0.1.6
- Docs only, no code change: mod.card now names the author, covers the
  SNAG BALL, uses the current body/accent wording, credits the Custom
  Pokeballs color reference accurately (no assets are used), and states
  the snag_quest ownership split.

## 0.1.5
- Ownership split with Snag Quest: the SNAG BALL's throw arc and flicker
  are now owned by snag_quest's own ball record (0.10.2+), so 0.1.4's
  `balls:patch` and its "SNAG BALL special toss" toggle are REMOVED. Two
  mods folding ops onto one record is a silent last-writer-wins
  conflict; this mod supplies color only.
- No visual change when running snag_quest 0.10.2+: the strobe still
  renders in the ball's black/red, because the flicker branch reacts to
  the flag rather than to which mod set it. On snag_quest 0.10.1 the
  Snag Ball keeps its color but reverts to the plain toss.

## 0.1.4
- SNAG BALL special toss, applied from here instead of from snag_quest:
  when snag_quest is installed, patches its ball record with
  tossAnim = ULTRATOSS_ANIM and flicker = true. snag_quest itself stays
  unmodified, so it looks and behaves stock without this mod. New F10
  toggle "SNAG BALL special toss" (default ON); requires a restart to
  change, since registries freeze after load.

## 0.1.3
- SNAG_BALL visibility: body lightened to dark gunmetal (60,56,66) and
  accent heated to (240,40,32) -- the near-black body disappeared on
  dark/night backgrounds in testing. With snag_quest 0.10.2's new toss
  flicker, the two colors strobe in flight under ADVANCED.

## 0.1.2
- Snag Quest integration: SNAG_BALL colors in Team Rocket black with a
  red accent (harmless entry when snag_quest is absent). New F10
  toggle "Rocket-colored SNAG BALL", default ON, separate from the
  main toggle.

## 0.1.1
- FIX: slot mapping was inverted. The ball sprite's body region is DMG
  colors 2/3, not color 1 (confirmed from a 0.1.0 capture), so 0.1.0 put
  each ball's color on the small accent and the dark shade on the body.
  Colors are now declared as `body` / `accent` and land correctly.
- Retuned all 14 palettes for the corrected mapping.


## 0.1.0
- Initial release: per-ball colors for toss / shake / resting caught
  ball under COLORS = ADVANCED. 5 native balls + 9 Custom Pokeballs
  balls. Flicker preserved in ball colors. F10 toggle, default ON.
  Publishes `exports.colors` for other mods' balls.
