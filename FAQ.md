# Pokeball Colors — FAQ

Every answer is collapsed. Tap only what you want revealed.

## Getting it working

<details>
<summary>Where is the ball color editor?</summary>

Open an in-game PC and choose **BALL COLORS**. Pick a whole-ball preset or
edit BODY, ACCENT and THIRD one RGB channel at a time. Press A on the RGB
screen to cycle the adjustment step through 1, 8 and 32.

On Red, Blue and Yellow, the saved colours appear only with COLORS set to
ADVANCED. Gold, Silver and Crystal need no colour-mode setting.
</details>

<details>
<summary>Why can't the band and outline have separate colours?</summary>

The ball sprite has three visible palette slots: body, accent, and one third
region. Choose BAND or OUTLINE for that third region. Both can be designed,
but they cannot appear as two independent colours on the same throw. Gold,
Silver and Crystal use their native third-colour pixel region.
</details>

<details>
<summary>I installed it on Red, Blue or Yellow and my balls are still
grey.</summary>

Almost always the color mode. On Red, Blue and Yellow this mod only works
when **COLORS is set to ADVANCED** — the other modes are deliberately
flat-palette, and the mod passes them through untouched by design.

If you're already on ADVANCED, check the load log for the
`pokeball_colors <version> loaded` line, and check that COLORED BALLS is
ON in the F10 mod manager.
</details>

<details>
<summary>I'm on Gold and a ball throws grey.</summary>

**Different cause, and the answer above won't help.** Gold has no ADVANCED
setting. Its native palette colours thrown balls, and a saved BALL COLORS
customization overrides that palette directly.

A ball throws grey on Gold when **its own mod hasn't registered a palette
for it**. The five native balls are fine. Mod balls need their author to
register one — Too Many Balls owns that side on Gold and exposes
`registerBallPalette` for other ball mods. A ball nobody registered throws
grey and lights grey on the heal machine, which is consistent rather than
broken.

So this is a report for *that ball's* mod, not for this one.
</details>

<details>
<summary>Which balls does it know about?</summary>

The five native balls, the nine from **Custom Poké Balls** (mod id
`custom_pokeballs`), the balls from **Too Many Balls**, and **Snag
Quest**'s Snag Ball.

On Red, Blue and Yellow, a ball from a mod this one doesn't know keeps its
vanilla colours — nothing breaks, it just isn't in the table yet. Open an
issue and it can be added, or its own author can register colours directly
(see the README's *For mod authors*).

On Gold the arrangement is different: this mod only does the heal machine
there, and it reads whatever palette the ball's own mod registered.
</details>

<details>
<summary>Do I need Custom Poké Balls or Snag Quest installed?</summary>

No. Both are optional. The color entries for balls you don't have simply
never come up.
</details>

## Balls that change colour

<details>
<summary>My KECLEON BALL keeps coming out a different colour. Is it
broken?</summary>

No — that's the point of it. Some balls take their colour from what you
throw them at rather than having one fixed colour, and Too Many Balls'
**KECLEON BALL** is the first: it turns the colour of its target. Throw it
at a Pikachu and it's yellow; at a Slowpoke, pink. Throw it at a shiny and
you get the shiny's colours.

**This is a Gold thing today.** On Red, Blue and Yellow the same ball is a
fixed green-and-red — that's its own mod's choice, not a fault here. This
mod supports dynamic colours on both; whether a given ball uses them is up
to whoever made it.
</details>

<details>
<summary>What colour does a Kecleon Ball show at the Pokémon Center?</summary>

**The colour it was caught with.** On Gold, a Pikachu caught in one lights
yellow on the heal machine, a Slowpoke pink — matching what the ball looked
like at the moment of the throw, shiny colours included.

It works this way because a Pokémon Center has no battle to take a colour
from, so the answer is remembered on the Pokémon at catch time instead.

On Red, Blue and Yellow the ball has one fixed colour anyway, so the
machine simply shows that.
</details>

<details>
<summary>What happens if I customize the Kecleon Ball?</summary>

Your saved design wins, so it stops matching the Pokémon it is thrown at.
Choose **RESTORE DEFAULT** for the Kecleon Ball to remove the override and
make it dynamic again. The mod-balls option only controls whether it appears
in the editor; it does not erase an existing saved design.
</details>

<details>
<summary>A Pokémon I caught in a Kecleon Ball shows the wrong colour on
the heal machine.</summary>

First, which game? On **Red, Blue or Yellow** the Kecleon Ball has one
fixed colour — green-and-red — so a green ball there is correct, not a
fault.

On **Gold**, if it lights **green** it was caught during an unreleased test
build (0.1.25) before that bug was fixed. No public release ever had it.
Catch the Pokémon again and the colour corrects itself.

Any other wrong colour is worth an issue — say which species, which ball,
and which game.
</details>

## The heal machine

<details>
<summary>What are the coloured balls at the Pokémon Center?</summary>

The heal machine lights one ball per party member, in the colours of the
ball that Pokémon was actually caught in — a party of Great Ball catches
heals blue.

This works on **Red, Blue, Yellow and Gold**. On Gold it's the only thing
this mod does, since Gold already colours thrown balls itself.

Pokémon caught before you installed the mod show as Poké Ball red; there's
nothing in an older save that records which ball was used.
</details>

<details>
<summary>Can I turn the heal machine colours off?</summary>

Yes — **COLORED BALLS AT POKeMON CENTER** in the mod's options. It takes
effect immediately, on both games.
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
