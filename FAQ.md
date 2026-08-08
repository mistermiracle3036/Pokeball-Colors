# Pokeball Colors — FAQ

Every answer is collapsed. Tap only what you want revealed.

## Getting it working

<details>
<summary>I installed it and my balls are still grey. Why?</summary>

Almost always the color mode. This mod only works when **COLORS is set
to ADVANCED** — the other modes are deliberately flat-palette, and the
mod passes them through untouched by design.

If you're already on ADVANCED, check the load log for the
`pokeball_colors <version> loaded` line, and check that COLORED BALLS is
ON in the F10 mod manager.
</details>

<details>
<summary>Which balls does it know about?</summary>

The five native balls, the nine from Custom Pokeballs, and Snag Quest's
Snag Ball. A ball from some other mod keeps its vanilla colors — nothing
breaks, it just isn't in the table yet. Open an issue and it can be
added.
</details>

<details>
<summary>Do I need Custom Pokeballs or Snag Quest installed?</summary>

No. Both are optional. The color entries for balls you don't have simply
never come up.
</details>

## The Snag Ball

<details>
<summary>What exactly does this change about the Snag Ball? (spoiler-lite)</summary>

Nothing, as of 0.1.8. Snag Quest owns its ball completely — the black
and red colors, the Ultra-style throw arc and the strobe all come from
Snag Quest itself. This mod just renders the colors it's handed.

Nothing about snagging changes — catch odds, which battles it works in,
the marking on snagged Pokémon, fence payouts: all untouched.
</details>

<details>
<summary>Does this modify Snag Quest?</summary>

No. The two mods own different halves on purpose: Snag Quest owns the
Snag Ball's throw animation and flicker, this mod owns its color. Each
works alone, and neither writes to the other's half — that's what keeps
them from silently overriding each other.
</details>

<details>
<summary>My Snag Ball throws in plain vanilla colors.</summary>

You're on Snag Quest 0.10.x. From 0.11.x on, Snag Quest supplies its own
ball color, throw arc and strobe — update it.
</details>

## Details

<details>
<summary>Does this affect catch rates or anything gameplay-related?</summary>

No. It only changes which colors get handed to the renderer for ball
sprites, plus (optionally) which throw animation the Snag Ball uses.
</details>

<details>
<summary>What about the Master Ball flicker?</summary>

Preserved. Balls that strobe during the throw still strobe — now between
their own two colors instead of the palette's. Poof clouds and all other
battle animations are left vanilla on purpose.
</details>

<details>
<summary>Does it work in voxel mode?</summary>

Yes — tested there.
</details>

## Troubleshooting

<details>
<summary>The ball is colored, but the light and dark parts look swapped.</summary>

That's a real bug class — it happened in 0.1.0 and was fixed in 0.1.1.
If you see it again on a specific ball, open an issue naming the ball
and, if you can, attach a screenshot paused on the throw.
</details>

<details>
<summary>I talked to an NPC and they just turned to face me — nothing
happened.</summary>

That's the signature of a swallowed script error, and it isn't this mod
(Pokeball Colors registers no NPC dialogue at all). Check which other
mods you have enabled and report it against that mod, with your game
version and steps.
</details>

<details>
<summary>I updated the mod but it's acting like the old version.</summary>

Fully quit and relaunch the game. Hot-reload can keep stale code in
memory. The load log prints the version — confirm it matches the release
you installed.
</details>
