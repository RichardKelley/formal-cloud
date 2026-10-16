# Lean examples

This standalone project uses Lean's standard library, with no Mathlib dependency.

Open this folder in VS Code (File → Open Folder → `lean-examples`) and install
the recommended **Lean 4** extension (`leanprover.lean4`). Open `OddEven.lean`.
If the proof panel is hidden, run **Lean 4: Toggle Infoview** from the Command
Palette.

Move the cursor through the proof to inspect the hypotheses and goal in
Infoview. In particular, inspect the state after each `cases`, after `refine`,
and after `omega`. The `refine` step supplies the evenness witness and leaves
its equation as a separate goal; `omega` proves that equation. After the last
step, there are no goals remaining.

The second theorem shows the same argument using `obtain` to name the witnesses
and `grind` to finish the arithmetic. Both examples use only the standard library.

To check the example from a terminal in this folder:

```sh
lake build
```
