# Changelog

All notable changes to Pokeball Colors are documented here. Format
follows [Keep a Changelog](https://keepachangelog.com); the top heading
always matches the version in `manifest.json`.

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
