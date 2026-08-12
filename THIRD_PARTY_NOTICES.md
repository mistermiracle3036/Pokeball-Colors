# Third-party notices

- **gen1recomp** — this mod targets the
  [gen1recomp](https://github.com/bryanthaboi/gen1recomp) engine (mod
  API 2) and reaches engine internals under the `engine_internals`
  permission.
- **Custom Poké Balls** by magalvao
  (https://github.com/magalvao/custom-pokeballs) — optional integration. This mod adds no code
  from it and ships none of its assets; the nine ball colors here were
  sampled by eye from its sprite art and re-entered as plain RGB values.
- **Too Many Balls** (formerly *Kanto Balls*; mod id `kanto_balls`,
  https://github.com/mistermiracle3036/Too-Many-Balls) — optional
  integration, by the same author. It owns its own balls and, on Gold,
  owns the ball-palette wrap this mod's heal machine reads through. No
  code or assets are shared in either direction.
- **Snag Quest** — optional integration. Its Snag Ball record is patched
  from outside via the public balls registry. Snag Quest itself is
  unmodified.
- Pokémon and all related names are trademarks of Nintendo / Creatures
  Inc. / GAME FREAK inc. This mod contains no ROM data or copyrighted
  assets; it is a fan-made script mod and requires the user's own game
  copy via gen1recomp.
- **Licence scope.** The MIT licence in `LICENSE` covers this mod's own
  code. It makes no claim over ROM-derived material or Nintendo
  trademarks, and grants no rights in either.
- **Ball tile artwork is never redistributed.** The black band (0.1.15+)
  needs the ball sprite's colour indices rearranged. Rather than ship an
  edited copy of that artwork — which is ROM-derived — the mod rebuilds it
  in memory each session from the sheet your own game extracted from your
  own cartridge dump. What this repo contains is a table of which pixels
  play which role, not the pixels themselves.
