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

## Ball color editor

Open a PC and choose **BALL COLORS**. The wardrobe-style menu lets you choose
any ball, apply a preset, or edit its body, accent, and third visible colour
with full 0-255 RGB control. Press A in the RGB editor to change the adjustment
step between 1, 8, and 32.

The third colour can be assigned to a seam band or an outer outline. A Game
Boy object sprite has one transparent palette slot and three visible slots,
so the band and outline share the third slot and cannot display as two
independent colours at once. Gold, Silver and Crystal keep their native ball
pixel layout while using all three selected colours. **RESTORE**
removes the saved choice.

Balls added by other mods appear automatically when **SHOW MOD BALLS IN COLOR
EDITOR** is enabled. Customizing a Kecleon Ball overrides its target-matching
colour; restoring its default makes it dynamic again.

## Requirements

- **Red, Blue and Yellow:** COLORS must be set to **ADVANCED**. The mod
  does nothing in the mono/classic color modes — those deliberately have
  no per-sprite color to give, and it passes them straight through.
- **Gold, Silver and Crystal:** nothing to set. Saved editor colours apply
  directly to thrown balls and the Pokemon Center heal machine.
- gen1recomp **0.1.38 or newer** (Gen 2 support needs **0.1.78+**, and is
  simply inactive on older builds). No hard mod dependencies.

## What gets colored

On Gold, Elm's starter balls are red for Cyndaquil, blue for Totodile, and
green for Chikorita. Pokemon preview pictures also use each species' native
colours instead of grey, including starter choices added by **Trainer
Journey**.

| Ball | Look |
| ---- | ---- |
| Poké Ball | Red with a pale highlight, black band |
| Great Ball | Blue with a pale highlight, black band |
| Ultra Ball | Two shades of gold with a black outline |
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
| COLORED BALLS | ON | Master switch for all ball coloring |
| COLORED BALLS AT POKeMON CENTER | ON | The heal machine's balls use each mon's caught ball (both games) |
| MY BALL COLORS OVER OTHER MODS | OFF | Win the ball art when another mod supplies its own |
| RECOLOR BALLS IN GEN 2 GAMES | ON | Gold/Silver/Crystal's own balls use this mod's colors by default |
| DEV: EVERY BALL SOLD IN MARTS | OFF | Every mart stocks every ball in the game |

Three options were removed in 0.1.55, all superseded by the PC editor:
ROCKET-COLORED SNAG BALL and BLACK BAND/OUTLINE ON BALLS are now per-ball
choices there (the STYLE row picks band or rim), and SHOW MOD BALLS IN
COLOR EDITOR is gone because the editor always lists every ball.

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
OVER OTHER MODS**. Every ball this mod has a colour for is then painted by
it, from the first throw — you keep all of that mod's other sprites, and
only the ball changes hands. The trade is that an overridden ball is
painted directly, so it can't follow the background palette or do the
Master/Ultra strobe.

With the option **off**, the first throw after loading may still show this
mod's ball before it settles on the other mod's — it only learns another
mod owns the ball once it has seen a throw go by.

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
- Works in Red, Blue, Yellow, Gold, Silver **and Crystal** - nothing here touches map or
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
is always safe: the player can switch any ball between the band and the
rim from the PC editor's STYLE row, and an older copy of this mod that has
never heard of the key ignores it rather than rejecting your registration.
Never a hard dependency, and never a reason to bump a version floor.

A band needs somewhere to read: if your ball's `accent` is already dark,
a black `line` will merge into it and show nothing.

`outline` is the same third colour on a different region — the ball's rim
rather than its seam:

```lua
MY_BALL = { body = {...}, accent = {...}, outline = { 0, 0, 0 } }
```

Use `line` for a Poké-Ball-style band across the middle, `outline` for a
dark rim around the edge. Set one or the other; if you set both, `line`
wins. The native ULTRA BALL uses `outline` — two shades of gold with a
black rim — which is why its throw shimmers rather than blinking.

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
