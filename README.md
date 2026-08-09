# Pokeball Colors

Every ball you throw in **gen1recomp** gets its own color. Under the
**ADVANCED** color mode, the toss, the wobbles and the resting ball all
render in that ball's colors instead of the flat palette the background
happens to be using — a Great Ball throws blue, an Ultra Ball throws
gold, a Dusk Ball throws near-black with a gold glint.

Covers the five native balls, all nine balls from the **Custom
Pokeballs** mod, and the **Snag Ball** from **Snag Quest** — which also
gets a Master-Ball-tier throw as a bonus.

> **Development Preview:** Pokeball Colors is in active development. Bug
> reports and ideas are welcome in [GitHub Issues](../../issues) —
> please include the version number from your load log and which other
> mods were enabled.

At the Pokemon Center, the heal machine's balls light up in the colors
of the ball each party member was caught in — a party of Great Ball
catches heals blue. (Balls caught before this feature installed show as
Poke Ball red.)

Purely cosmetic. No catch rates, items, marts or battle logic are
changed by this mod.

## Requirements

- **COLORS must be set to ADVANCED.** This mod does nothing in the
  mono/classic color modes — those deliberately have no per-sprite
  color to give, and the mod passes them straight through.
- gen1recomp **0.1.38 or newer**. No hard mod dependencies.

## What gets colored

| Ball | Look |
| ---- | ---- |
| Poké Ball | Red with a pale highlight |
| Great Ball | Blue with a pale highlight |
| Ultra Ball | Gold with a black band |
| Master Ball | Purple with a pale highlight |
| Safari Ball | Olive green |
| Quick Ball *(Custom Poké Balls)* | Yellow with deep blue |
| Timer Ball *(Custom Poké Balls)* | White with red |
| Net Ball *(Custom Poké Balls)* | Teal |
| Dusk Ball *(Custom Poké Balls)* | Near-black with gold |
| Heavy Ball *(Custom Poké Balls)* | Gunmetal grey |
| Repeat Ball *(Custom Poké Balls)* | Orange with pale yellow |
| Dream Ball *(Custom Poké Balls)* | Pink |
| Level Ball *(Custom Poké Balls)* | Gold with black |
| Dive Ball *(Custom Poké Balls)* | Sea blue |
| Snag Ball *(Snag Quest)* | Colored by Snag Quest itself (0.11.x+) — Team Rocket black and red, strobing through its Ultra-style throw |

Balls from mods this one doesn't know about keep their vanilla colors.

The Master and Ultra Balls keep their signature palette strobe, now in
their own colors. Poof clouds and every other battle animation are left
exactly as vanilla.

## Options

Open **MODS → POKEBALL COLORS → OPTIONS** (F10 mod manager):

| Option | Default | Effect |
| ------ | ------- | ------ |
| COLORED BALLS (ADVANCED MODE) | ON | Master switch for all ball coloring |
| ROCKET-COLORED SNAG BALL | ON | Snag Ball throws in black/red instead of its normal colors |

Both toggles are live — they take effect on your next throw, no restart
needed.

## Installation

**First install**

1. Download the mod zip from the [latest release](../../releases/latest).
2. Open the launcher's **MODS** browser and tap **Import mod .zip**
   (on iOS, delete any previously downloaded copy of the zip from Files
   first so you don't import a stale one).
3. Set COLORS to ADVANCED, and fully quit and relaunch.

**Updates**

After the first install, no re-download needed: the mod browser checks
this repo's releases automatically. When a new version is out, the mod's
entry shows *"vX.Y.Z available"* — tap it, then **Update**. Fully quit
and relaunch afterward so the new code is actually live.

## Compatibility

- **Custom Poké Balls** by magalvao
  ([repo](https://github.com/magalvao/custom-pokeballs), mod id
  `custom_pokeballs`) — optional. Its nine balls color automatically when
  it's installed; the entries sit harmless when it isn't.
- **Snag Quest** ([repo](https://github.com/mistermiracle3036/Pokemon-Snag))
  — optional, **0.11.x or newer** recommended. Snag Quest owns its Snag
  Ball completely, including its color, which it registers with this mod
  at load. This mod renders it; it doesn't define it. On Snag Quest
  0.10.x the Snag Ball simply throws in vanilla colors.
- **Dramatic Shape (voxel mode)** — tested and working in voxel mode.
- Works in Red, Blue and Yellow — nothing here touches map or text data.

## For mod authors

Color your own balls in one call:

```lua
mod.events:on("game.ready", function()
  local pbc = mod.find("pokeball_colors")
  if pbc and pbc.exports.registerColors then
    pbc.exports.registerColors({
      MY_BALL = {
        body   = { 200, 60, 40 },    -- the ball's main color
        accent = { 240, 224, 200 },  -- the smaller highlight
      },
    })
  end
end)
```

`registerColors` never overwrites a color that's already set, so a user
override or another mod that got there first always wins. It validates
entries and logs anything malformed. Returns `added, skipped`.

Colors apply everywhere this mod renders — the battle toss, the shakes,
the resting caught ball, and the Pokemon Center heal machine — with no
extra work per surface.

If a ball is thrown with no color registered, this mod logs one warning
naming that ball id, so a missing registration says so instead of
silently rendering vanilla.

`body` fills the larger region of the ball sprite and `accent` the
smaller one. If the ball's record has `flicker = true`, the two swap
back and forth during the throw.

### Reading which ball caught a Pokemon

This mod records `mon.caughtBall` (the ball's item id) at catch time and
it persists through saves. Other mods are welcome to **read** it — a
ribbon for Pokemon caught in a particular ball, say:

```lua
if mon.caughtBall == "GS_BALL" then ... end
```

It's declared in `exports.owns.caughtBallField`. This mod owns writing
it; don't write it from elsewhere. It's `nil` on Pokemon caught before
v0.1.12 or while this mod wasn't installed, so always nil-check.

Register on `game.ready` and **only when your key is absent**, so a user's
own override always wins:

```lua
mod.events:on("game.ready", function()
  local pbc = mod.find("pokeball_colors")
  if pbc and pbc.exports.colors and not pbc.exports.colors["MY_BALL"] then
    pbc.exports.colors["MY_BALL"] = { body = {...}, accent = {...} }
  end
end)
```

This mod publishes `exports.owns = { colors = true }` — it owns color and
nothing else, and never patches another mod's ball record. If you own a
ball, own it completely and declare it the same way.

## Credits

By **Mister Miracle** ([@mistermiracle3036](https://github.com/mistermiracle3036)).
Built for [gen1recomp](https://github.com/bryanthaboi/gen1recomp).
Colors for the nine balls from
[Custom Poké Balls](https://github.com/magalvao/custom-pokeballs) by
magalvao were matched by eye to that mod's own sprite art; no assets are
used or redistributed.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
