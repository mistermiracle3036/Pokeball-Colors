# Pokeball Colors — for mod authors

Everything a mod needs to colour its own balls through this one. Moved out of
the README so the player-facing page stays short; the text is unchanged.

## Colouring your balls

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

**This is the Red/Blue/Yellow route.** Gold, Silver and Crystal colour
thrown balls from the cart's own palettes, so a mod-added ball takes its
colour there from whatever palette that mod registered — not from
`registerColors`. The heal machine reads the same source, so a ball that
colours correctly on the Gen 2 throw is already correct on the machine
with no call to this mod at all.

Register in both places. They are independent: neither knows about the
other, there is no order to get right, and a ball with only one of them
still works on that generation. If your ball exists on both generations,
`registerColors` here covers Gen 1 and your Gen 2 palette registration
covers the rest.

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

### Recolouring a ball this mod already owns

`registerColors` sets a ball's **default**, and it never overwrites one that
already exists — so if your mod recolours the five native balls, every entry
comes back skipped. That is deliberate for defaults, and no use if you have
your own palette for a ball we also carry.

Contribute a **named preset** instead. It appears in the PC's BALL COLORS
menu beside ours and the player picks:

```lua
local pbc = mod.find("pokeball_colors")
if pbc and pbc.exports and pbc.exports.registerPreset then
  pbc.exports.registerPreset("POKE_BALL", "MY MOD",
    { body = {224,72,56}, accent = {248,216,208}, outline = {24,24,24} })
end
```

Nothing is overwritten and nothing has to yield, so two mods with an opinion
about the Poké Ball stop being a conflict. Registering the same name twice on
one ball is a no-op rather than a redefinition. Call it at `game.ready`.

**If you are porting from a wrap of `animSpriteColors`**, mind the naming: it
returns `{ index1, index2, index3 }` positionally, where index 1 is the lower
crescent (our `accent`), index 2 the upper mass (our `body`) and index 3 the
rim (our `outline`). The order is the same; only the names differ, and
crossing them produces a plausible-looking but inverted ball.

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
