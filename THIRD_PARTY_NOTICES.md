# Third-party notices

Astrix contains code derived from the projects below. Their licences are
reproduced in full, as those licences require.

---

## Konsole

Astrix forks **Konsole** (<https://github.com/KYRORBLX/Konsole>) as its engine
foundation: the command registry and definition model, the replication of
schema-only definitions to clients, per-entity cooldown bucketing, the numeric
rank system, `pcall`-wrapped execution, and the visual language of the console
itself.

Copyright (c) KYRORBLX — driftingAurora, dullflowerr, alias, kioukaii.

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### What was and was not carried over

**Carried over (in spirit, rewritten):** command definitions that replicate
schema-only to clients so a server command's *shape* is known client-side;
per-command, per-entity cooldowns; `pcall`-wrapped execution so a thrown Luau
error becomes a normal failure result; the collapsed-pill console that expands
upward, its glass surface, and its motion timings.

**Deliberately not carried over:** Konsole's hand-rolled spring/tween maths
(`motion/math/shape.luau` and friends, roughly 500 lines) — Astrix renders
through **Lume**, which owns motion; and Konsole's hardcoded two-channel
main-console-plus-detached-chat system, generalised here into an
arbitrary-count `Window` model managed by `Container`.

---

## Lume

Astrix renders through **Lume** (<https://github.com/VALENCERBLX/Lume>), MIT,
which is itself distilled from the Konsole console UI credited above.

**Vendored** under `src/_Packages/Lume`, so Astrix installs as one tree with no
separate dependency to keep in step.

---

## Switch, Substance

Both MIT, by mkl48. **Vendored** under `src/_Packages/Switch` and
`src/_Packages/Substance`.

Switch is the intended home for every console keybind — a pushed
`"AstrixConsole"` context so bindings go quiet when the console closes — and
Substance the intended transport for `_Main/Network.lua`. Both are present and
neither is wired yet; see the README.
