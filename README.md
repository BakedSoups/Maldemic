![pandemic_demo](https://github.com/user-attachments/assets/6c20270a-594d-4097-8fc3-12f1a959f74d)
# Maldemic
create a vius youself and watch it spread, See the live SIRD data between cities and learn how certain virus's spread more over others 

## Realtime Simulation
![image](https://github.com/user-attachments/assets/2891b62f-88c7-41a1-b7b8-8c77eab60f6b)

Using a Stochastic Markove Chain Algorithm written in numpy and sci pi, we use distance between cities to determine how likely it is for the virus to spread
we then mix up the matric and update the SIR acoordingly

Once the python program complies this infromation we then visuzalize this simulation in godot.


## Dashboard and Virus Lab

Run `ui.tscn` (the main scene) in Godot 4.7. The overview includes a city selector,
SIRD history, world totals, flight visualization, and bounded day playback.
Open **Virus Lab** to change your strain and rotate its procedural 3D preview.
Six fictional starter cards load distinct trait combinations into the editor without
changing the current simulation. The indigo interface, lilac panels, and cyan/pink
accents follow the supplied visual reference.
The trait labels explain each visual mapping; the model is a stylized visualization,
not a biological reconstruction.

**Save design** persists traits to Godot's `user://virus_design.json` without
changing the current simulation. **Start new simulation** runs the Python engine
in the background and replaces the current run at day 1 only after it succeeds.
Transmission, incubation, and severity are retained as strain attributes; the
existing SIRD equations use infection, recovery, and lethality rates, with mutation
handled by the existing engine. Opening the lab pauses automatic day playback.

For a fresh checkout, prepare the Python dependencies:

```sh
python3 -m venv Python_Brain/.venv
Python_Brain/.venv/bin/python -m pip install -r Python_Brain/requirements.txt
```

On Windows use `Python_Brain/.venv/Scripts/python.exe`. The launcher detects these
local environments, the legacy `venv` directory, then the system Python. The
bundled simulation can be viewed without Python installed.

Validation (use your Godot executable):

```sh
godot --headless --path . res://tests/ui_smoke.tscn
godot --headless --path . res://tests/ui_smoke.tscn -- --simulation
```

The second check runs the actual Python engine and checks that edited traits reach
the resulting strain. It saves a test design; set `XDG_DATA_HOME` to a temporary
folder on Linux to isolate it from your saved design. Running the first check with
a display also writes overview/lab screenshots to `/tmp` on Linux.
