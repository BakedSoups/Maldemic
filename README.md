![pandemic_demo](https://github.com/user-attachments/assets/6c20270a-594d-4097-8fc3-12f1a959f74d)
# Maldemic
create a vius youself and watch it spread, See the live SIRD data between cities and learn how certain virus's spread more over others 

## Realtime Simulation
![image](https://github.com/user-attachments/assets/2891b62f-88c7-41a1-b7b8-8c77eab60f6b)

Using a Stochastic Markove Chain Algorithm written in numpy and sci pi, we use distance between cities to determine how likely it is for the virus to spread
we then mix up the matric and update the SIR acoordingly

Once the python program complies this infromation we then visuzalize this simulation in godot.


## Strategy mode

Open `ui.tscn` (the main scene) in Godot 4.7. Strategy runs entirely in GDScript;
Python is not required. Choose a starting city, loadout, difficulty and seed.
Establish at least 100 infected in all seven regions and reach 25% global active
infection before cure reaches 100%. Standard seeded test runs take approximately
11–13 minutes at normal speed; these are initial tuning values.

- Spend evolution points in **Virus Lab** on twelve upgrades across three branches.
  Purchases change future ticks. Hover for before/after modifiers; each card lists
  tradeoffs, cost and prerequisites. Two last-purchase reversals return 50% of cost.
- Pause, use **1× / 2× / 4×**, or step a day. Opening the lab pauses play.
- Inspect regional exposure, climate, healthcare, policies, warnings and events.
  The chart shows susceptible, infected, recovered and dead; exposed is shown in
  region details and remains part of the conserved population.
- The specimen gains fins, color and armor; drag to rotate, scroll to zoom, reset
  its view, or enable reduced motion. These are fictional visual motifs.
- **Save / Resume** uses an atomic, versioned `user://strategy_run.save`. Resume
  restores exact populations, RNG, economy, events, policies and flight schedule,
  and starts paused. Saving again replaces the previous save.
- **New game** restarts with chosen settings. Results include a timeline, build,
  score and same-seed/new-seed retry. Save before leaving for Sandbox if you want
  to return to your current run.

The fixed daily simulation and flight clock are independent of rendering. Visual
flights represent route cohorts, stay airborne across midnight, and never transfer
passengers themselves. Travel uses frozen source populations with simultaneous
arrivals; deceased populations cannot travel.

Balance data lives in `data/scenarios/persistent_signal.json` and
`data/upgrades/strategy.json`. Simulation, economy, response, events, saving,
visual scheduling and Strategy UI are separate modules. Initial balance is a
playtest hypothesis: the automated batch checks three builds over six seeds,
not that every possible purchase sequence wins or that no build dominates.

## Sandbox and legacy viewer

Choose **Sandbox / Viewer**, or open `viewer.tscn`, for the original prerecorded
outbreak viewer and unrestricted trait sliders. **Strategy** returns to the new
mode; use Resume for a saved run. Starter cards and sliders only edit sandbox
designs, never an active Strategy build.

**Save design** writes `user://virus_design.json`. The legacy **Start new
simulation** button optionally invokes the Python engine in the background.
Only that button requires Python dependencies:

```sh
python3 -m venv Python_Brain/.venv
Python_Brain/.venv/bin/python -m pip install -r Python_Brain/requirements.txt
```

On Windows the launcher also detects `Python_Brain/.venv/Scripts/python.exe`.
The bundled viewer data can be opened without Python.

## Validation and exports

Use your Godot executable; on Linux set `XDG_DATA_HOME` to a temporary directory
to isolate test saves. UI assertions must print their success marker; Godot script
assertions alone do not always set a nonzero process exit status.

```sh
godot --headless --path . --script res://tests/strategy_simulation.gd
godot --headless --path . res://tests/strategy_smoke.tscn
godot --headless --path . res://tests/ui_smoke.tscn
```

The simulation suite checks conservation, nonnegative populations, prerequisites,
reward uniqueness, event expiry, cure/clearance endings, save equivalence, invalid
saves, midnight flights and eighteen seeded runs. The Strategy scene test checks
layout bounds at 1152×720, purchases, specimen view preservation, pause, all speeds,
actual save files, flight reconstruction and restart. With a display it also writes
world/lab screenshots to `/tmp`. The legacy smoke test supports `-- --simulation`
for the optional Python integration check.

`export_presets.cfg` provides **Strategy Linux**. JSON balance files are explicitly
included and unused legacy scenes with broken dependencies are excluded.

```sh
godot --headless --path . --export-pack "Strategy Linux" /tmp/maldemic.pck
godot --headless --main-pack /tmp/maldemic.pck --quit-after 20
# With matching Linux export templates installed:
godot --headless --path . --export-release "Strategy Linux" build/maldemic.x86_64
```

The exported resource pack completed a full Strategy run from `/tmp` with an
empty `PATH`, exercising gameplay without Python or source files.
`tests/strategy_pack.gd` is the external harness for this check (`--main-pack`
with `--script` pointing to its absolute path). Headless suites also pass. A standalone
executable export needs the matching Godot export templates, which were unavailable
in the implementation environment. Manual rendered playtests, performance profiling
and broader difficulty/balance testing remain release gates. Variants, lineage,
unlocks and additional scenarios remain the later milestone described in `plan.md`.
