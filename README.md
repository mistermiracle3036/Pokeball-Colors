# Pokeball Colors

Every ball you throw in **gen1recomp** gets its own color. Under the
**ADVANCED** color mode, the toss, the wobbles and the resting ball all
render in that ball's colors instead of the flat palette the background
happens to be using — a Great Ball throws blue, an Ultra Ball throws
gold, a Dusk Ball throws near-black with a gold glint.

Covers the five native balls, all nine balls from the **Custom
Pokeballs** mod, the balls from **Too Many Balls**, and the **Snag Ball**
from **Snag Quest** — which also gets a Master-Ball-tier throw as a
bonus.

**Some balls don't have a fixed colour at all.** On **Gold**, Too Many
Balls' **KECLEON BALL** takes its colour from whatever you throw it at —
yellow at a Pikachu, pink at a Slowpoke, shiny colours at a shiny — and the
Pokémon Center then shows it in the colour it was caught with. On Red, Blue
and Yellow that ball is a fixed green-and-red for now; whether it goes
dynamic there is its own mod's call. The support for it is in place on both
(see [For mod authors](#for-mod-authors)).

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

- **Red, Blue and Yellow:** COLORS must be set to **ADVANCED**. The mod
  does nothing in the mono/classic color modes — those deliberately have
  no per-sprite color to give, and it passes them straight through.
- **Gold:** nothing to set. Gold colors thrown balls by itself, so on
  Gold this mod only does the Pokémon Center heal machine.
- gen1recomp **0.1.38 or newer** (Gold support needs **0.1.78+**, and is
  simply inactive on older builds). No hard mod dependencies.

## What gets colored

| Ball | Look |
| ---- | ---- |
| Poké Ball | Red with a pale highlight, black band |
| Great Ball | Blue with a pale highlight, black band |
| Ultra Ball | Gold with a black lower half |
| Master Ball | Purple with a pale highlight, black band |
| Safari Ball | Olive green with a black band |
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
| Kecleon Ball *(Too Many Balls)* | On Gold, no fixed colour — takes the colour of whatever you throw it at. Green-and-red on Red/Blue/Yellow |

Balls from mods this one doesn't know about keep their vanilla colors.

The black band is new in 0.1.15 and applies to the four native balls whose
art has one. Balls from other mods don't get one until their own mod asks
for it — see [For mod authors](#for-mod-authors). Turn the band off in the
options if you prefer the older two-tone look.

The Master and Ultra Balls keep their signature palette strobe, now in
their own colors. Poof clouds and every other battle animation are left
exactly as vanilla.

## Options

Open **MODS → POKEBALL COLORS → OPTIONS** (F10 mod manager):

| Option | Default | Effect |
| ------ | ------- | ------ |
| COLORED BALLS (ADVANCED MODE) | ON | Master switch for all ball coloring |
| ROCKET-COLORED SNAG BALL | ON | Snag Ball throws in black/red instead of its normal colors |
| COLORED BALLS AT POKeMON CENTER | ON | The heal machine's balls use each mon's caught ball (both games) |
| BLACK BAND ON THROWN BALLS | ON | The black band along a thrown ball's seam |
| MY BALL COLORS OVER OTHER MODS | OFF | Win the ball art when another mod supplies its own |
| DEV: EVERY BALL SOLD IN MARTS | OFF | Every mart stocks every ball in the game |

Every toggle is live — they take effect on your next throw, no restart
needed.

**DEV: EVERY BALL SOLD IN MARTS** is a testing aid, not a feature: it
exists so you can buy a Master Ball and see what it looks like thrown
without hunting one down. It stocks every ball the game knows about,
including balls from other mods. Turning it back off restores the normal
shelves completely — nothing is written to your save, and balls you
already bought stay in your bag like any other purchase. (The Master
Ball's price in the ROM is 0, so it rings up free. That's vanilla data.)

### Running alongside a mod that replaces ball artwork

Some sprite packs — **Gold & Silver Sprites**, for one — bring their own
Poké Ball art and draw it without this mod's colours. When that happens
this mod notices and **steps aside**, so you get their balls and keep every
other sprite they replace. Nothing to configure.

If you'd rather have *these* colours on the ball, turn on **MY BALL COLORS
OVER OTHER MODS**. You keep all of that mod's other sprites; only the ball
changes hands. The trade is that an overridden ball is painted directly, so
it can't follow the background palette or do the Master/Ultra strobe.

Either way, one throw may look grey before it settles — the mod only knows
another mod owns the ball once it has seen a throw go by.

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
- Works in Red, Blue, Yellow **and Gold** — nothing here touches map or
  text data.
- **Too Many Balls** (formerly *Kanto Balls*; mod id `kanto_balls`,
  [repo](https://github.com/mistermiracle3036/Too-Many-Balls)) — optional,
  and **confirmed working alongside this mod on both Red and Gold**. Its
  balls colour automatically through `registerColors` on Red/Blue/Yellow.
- **On Gold, other ball mods need no setup here.** The heal machine reads
  the colour the game itself uses for a thrown ball, so a ball picks up
  whatever palette its own mod registered — **Too Many Balls 0.4.2+** owns
  that side (`exports.owns.ballPalettesGen2`) and exposes
  `registerBallPalette` for other ball mods to use. A ball nobody has
  registered throws grey and lights grey, which is consistent rather than
  broken.

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
        line   = { 0, 0, 0 },        -- optional: the band (0.1.15+)
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

**This is the Red/Blue/Yellow route.** Gold colours thrown balls itself,
so `registerColors` does nothing there; on Gold the heal machine reads the
game's own ball palette instead, which means a ball registered through
**Too Many Balls 0.4.2+**'s `registerBallPalette` is coloured on the
machine with no call to this mod at all. Registering in both places is the
right thing to do, and neither knows or cares about the other.

If a ball is thrown with no color registered, this mod logs one warning
naming that ball id, so a missing registration says so instead of
silently rendering vanilla.

`body` fills the larger region of the ball sprite and `accent` the
smaller one. If the ball's record has `flicker = true`, the two swap
back and forth during the throw.

`line` is optional and paints the band along the seam between the two
halves, in battle only. Leave it out and your ball renders exactly as it
did before 0.1.15 — and it degrades on its own besides, so supplying it
is always safe: the band disappears if the player turns the "Black band
on thrown balls" option off, and an older copy of this mod that has never
heard of the key ignores it rather than rejecting your registration.
Never a hard dependency, and never a reason to bump a version floor.

A band needs somewhere to read: if your ball's `accent` is already dark,
a black `line` will merge into it and show nothing. That is why the
native ULTRA BALL has no band.

### Balls whose colour is not fixed

If a ball's colour depends on something — the target, the terrain, a roll
at throw time — register a resolver instead of a static entry:

```lua
pbc.exports.registerColorResolver("MY_BALL", function(ctx)
  -- ctx.ball, ctx.surface ("battle" | "catch"), and whatever the caller
  -- has: ctx.battle, ctx.mon, ctx.game
  return { body = {r,g,b}, accent = {r,g,b}, line = {r,g,b} }
end)
```

Return `nil` to fall back to the ball's static colour, so a resolver that
has nothing to say in a given situation costs nothing.

**It is called once per throw**, not once per frame, and the answer is held
for the whole toss, wobble and rest. That keeps the ball a stable colour
and keeps a very hot draw path cheap — so a resolver may do real work, but
it should not assume it runs every frame.

At the Pokemon Center the ball shows **the colour it was caught with**: the
resolved answer is snapshotted onto the Pokemon at catch time
(`mon.caughtBallColor`, and `mon.caughtBallPalette` on Gold), because a
Center has no battle to resolve against. This mod owns both fields.

A resolver that errors is disabled for the session and reported on the
[ERRS] screen, rather than being retried inside the draw loop.

`exports.resolveColor(id, ctx)` is the read side, for any mod that needs a
ball's current colour without caring whether it is static or dynamic.

### Reading which ball caught a Pokemon

This mod records `mon.caughtBall` (the ball's item id) at catch time and
it persists through saves. Other mods are welcome to **read** it — a
ribbon for Pokemon caught in a particular ball, say:

```lua
if mon.caughtBall == "GS_BALL" then ... end
```

It's declared in `exports.owns.caughtBallField`. Read it freely; don't
write it **while this mod is installed**. If you need the field to exist
without this mod, write it only when `exports.owns.caughtBallField` is
absent, and never overwrite a value that is already set — that way the
two of you can never disagree about which ball caught a Pokemon. It's
`nil` on Pokemon caught before v0.1.12 or while this mod wasn't
installed, so always nil-check.

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
used or redistributed. The mart-stocking approach behind the DEV option
follows the shelf mechanism magalvao's mod established and Snag Quest
refined — no code was copied from either.

The black band rearranges the colour indices of the ball sprite. That
artwork is ROM-derived, so this mod ships none of it: the rearranged sheet
is rebuilt in memory each session from the one your own game extracted
from your own cartridge.

Licensed **MIT** — see [LICENSE](LICENSE). That covers this mod's own
code, and makes no claim over ROM-derived material or Nintendo
trademarks.

Pokémon and all related names are trademarks of Nintendo / Creatures Inc.
/ GAME FREAK inc. This is an unofficial fan project, not affiliated with
or endorsed by any of them, and it requires your own copy of the game.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
