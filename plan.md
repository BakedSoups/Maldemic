# Maldemic — game-first expansion plan

## Direction

Turn the current outbreak viewer and Virus Lab into a replayable global strategy
game inspired by Plague Inc. The player creates a fictional pathogen, chooses a
starting region, earns evolution points, and adapts as the world responds.

Prioritize interesting decisions, clear feedback, and a satisfying 3D creature.
Use biology as visual inspiration and vocabulary. Simulation rules and trait
effects should be understandable, tunable game mechanics. The existing globe,
air traffic, indigo interface, and live specimen are the foundation.

**Target first run:** 10–20 minutes, with a meaningful decision in the first minute.
Use original names, artwork, progression, and scenarios.

## Core loop

1. Pick a fictional archetype and starting city.
2. Watch infections spread through local contact and connected travel routes.
3. Earn evolution points from new regions, infection milestones, and objectives.
4. Buy adaptations in the Virus Lab; see the specimen transform immediately.
5. React to detection, travel restrictions, research, and regional conditions.
6. Finish the scenario and review the timeline, build, and score.

The central tension is **expansion versus attention**. Stronger upgrades help the
player but consume scarce points, reveal the outbreak, or introduce weaknesses.
No single upgrade path should solve every map.

## First playable scope

Keep the existing seven cities as strategic regions. Each gets a population,
climate tag, healthcare rating, travel connections, awareness, and policy state.
Add more regions after this small map produces interesting games.

- One playable archetype, with three starting loadouts.
- Twelve purchasable upgrades across three branches.
- Evolution points, prerequisites, and escalating costs.
- Local spread and travel that react to player upgrades during the run.
- Regional detection and a global cure race.
- Three world events.
- A tutorial objective chain and explicit win/loss screens.
- Pause, three speeds, restart, and save/resume.

**Initial scenario:** establish a persistent outbreak in every region and reach a
configurable global infection milestone before the cure is deployed. Later
scenarios can introduce collapse, survival, or score-attack objectives. Do not
make global extinction the only supported ending.

## Evolution and the Virus Lab

Replace unrestricted mid-run sliders with purchases. Keep sliders in a separate
Sandbox mode for experimenting with designs and balancing.

| Branch | Purpose | Fictional upgrade examples | Tradeoff |
| --- | --- | --- | --- |
| Spread | Reach new hosts and regions | Dispersal, carrier persistence, travel affinity | Increased visibility or weaker local performance |
| Impact | Increase pressure on regions | Symptom escalation, systemic burden, crisis response | Faster detection and stronger countermeasures |
| Adaptation | Survive changing conditions | Cold tolerance, heat tolerance, research disruption | High cost or reduced growth elsewhere |

Start with four upgrades per branch. Represent every upgrade as data containing
an ID, cost, prerequisites, exclusions, effect modifiers, visual changes, and
player-facing explanation.

Before purchase, show the cost and a concise before/after preview: “Spread +10%,
visibility +5.” These are game statistics, not biological measurements.

Purchases affect future simulation ticks. They never rewrite previous days.
Allow limited refunds or a clearly priced reversal mechanic so a mistake does
not automatically ruin a run.

### A specimen that visibly evolves

Make the virus a recognizable character for each build:

- Choose a base silhouette: round shell, faceted capsule, or elongated body.
- Give upgrade branches distinct visual motifs: surface protrusions, shell
  plating, colored nodes, internal filaments, or a changing membrane pattern.
- Animate purchases as a short assembly sequence rather than replacing the
  entire mesh in one frame.
- Preserve the current rotation and zoom when a trait changes.
- Offer drag-to-rotate, reset view, and reduced-motion options.
- Keep colors and exaggerated geometry explicitly stylized; “longer spikes”
  should communicate an upgrade, not claim a universal link to lethality.

Use a separate `VisualProfile` so art direction can change without changing game
balance. Derive the profile from the archetype and purchased upgrades, using a
stable seed to keep a saved specimen looking the same after loading.

## World simulation

### Recommended architecture

Move the live gameplay loop into a small, deterministic GDScript simulation.
Seven regions and a few population compartments do not require a per-person
simulation. Keep Python as an optional balancing/research tool rather than a
runtime requirement for the shipped game.

The current Python launcher precomputes a run. That cannot support responsive
mid-run evolution without restarting or regenerating the future. Replace that
path for Strategy mode while retaining the existing viewer during migration.

Use a fixed simulation tick, independent of rendering and flight animations.
Each displayed day should represent the same amount of simulation time at every
playback speed. Pause must stop population changes, policies, and event timers.

### Region state

Track susceptible, exposed, infected, recovered, and dead populations. An exposed
stage gives delayed spread a useful gameplay role. Show totals and short trends;
avoid making players read equations to understand a decision.

For each tick:

1. Apply queued player purchases and scheduled events.
2. Calculate local disease transitions from the tick's starting state.
3. Allocate travel from available living populations.
4. Apply all arrivals together, preventing a traveler from departing twice in
   the same tick.
5. Update awareness, policies, and cure research.
6. Award milestone points and evaluate scenario objectives.
7. Publish one snapshot for charts, city materials, and flight visuals.

Enforce nonnegative populations and population conservation. Deaths cannot
travel. Do not force an infected passenger onto every route or inflate infection
counts to make plane colors more dramatic. Flight animation should illustrate
simulation events without controlling when the next tick can happen.

### Continuous air traffic

Planes should take off throughout the day instead of appearing in one batch when
the day advances. A new day must not delete flights that are still in the air.

- Turn each day's route totals into a bounded queue of representative flights.
  Give each flight a departure time within that day and an arrival time.
- Distribute departures across the day with seeded jitter. Busier routes get
  more departures, rather than several planes launching on the same frame.
- Drive the queue and flight progress from the simulation clock, including its
  fractional day. Day labels update at midnight; traffic continues smoothly.
- Carry active flights across midnight and remove them only when they arrive.
  Replace the current per-day terminal cleanup and batch-launch behavior.
- Pause freezes both departures and planes. Playback speed advances their shared
  clock consistently. Manual day stepping reconciles the queue to the new time;
  it must not flash every skipped departure onto the screen.
- Keep representative flights separate from passenger accounting: each visual
  stands for a route cohort, and rendering or hiding it never transfers people
  twice. The region simulation remains the authority for population changes.
- Cap simultaneous visible planes and aggregate low-volume traffic when needed.
  Never delay the simulation because an animation has not finished.
- Save the scheduler state or reconstruct it deterministically on load. Avoid
  duplicate departures after resuming a run.

**Acceptance check:** observe three consecutive days at normal speed. Departures
are spread through each day, some flights cross midnight, and the sky never clears
solely because the day counter advances. Pause/resume, speed changes, and manual
stepping preserve correct traffic state and population totals.

Use a seeded random generator. A saved seed plus the same player actions should
produce the same outcome, making bugs and balance problems reproducible.

### Starting balance model

Use a small set of explicit game modifiers: spread, latent duration, clearance,
impact, visibility, climate tolerance, and resistance to world responses.
Apply bounded multipliers with diminishing returns. Keep population arithmetic
separate from the economy and presentation.

Tune the model for readable pacing. Small outbreaks may fail naturally, but the
tutorial should use a forgiving seed and starting conditions. Do not disguise
forced survival as random simulation behavior.

## World response and cure pressure

Use a simple escalation ladder per region:

| Stage | Trigger | Player-visible consequence |
| --- | --- | --- |
| Unaware | Low visible impact | Normal travel and weak response |
| Investigating | Awareness threshold crossed | News alert and research begins |
| Containing | Sustained regional pressure | Lower contact and restricted travel |
| Emergency | High burden or global escalation | Strong restrictions and research funding |

Global cure progress combines contributions from participating regions. Policies
need a delay, a duration, and a visible explanation. Give players advance warning
of major restrictions and an opportunity to respond.

Research-disruption upgrades should buy time with diminishing returns. They
should not permanently disable the cure race. Difficulty adjusts response speed,
costs, and starting resources using explicit presets.

## Evolution-point economy

- Award points once for each milestone and newly established region.
- Use optional short objectives to encourage varied play.
- Give higher-tier upgrades increasing costs and meaningful prerequisites.
- Avoid rewarding deaths as the only efficient source of currency.
- Track claimed rewards in the save file to prevent duplicate awards.
- Allow different winning builds; verify that early purchases do not create an
  unavoidable snowball.

Starting costs, thresholds, and reward amounts belong in balance data. Treat all
initial numbers as tuning hypotheses until playtested.

## Events and replayability

First events:

1. **Travel surge:** selected routes temporarily carry more people.
2. **Research grant:** one region temporarily contributes more cure progress.
3. **Weather shift:** a region's climate modifier temporarily changes.

Each event has eligibility rules, a seeded probability, an expiry tick, and a
visible effect summary. Avoid unexplained instant losses.

Later scenarios can change the rules: an isolated map, a connected hub network,
a rapidly responding world, or survival through alternating climate conditions.
Unlock archetypes and cosmetic specimen styles through scenario achievements.

## Variants — after the core loop works

For the first playable, purchased evolution updates one lineage prospectively.
Do not attempt to model molecular mutation.

In a later milestone, add two or three coexisting fictional variants. Track their
regional shares and let them compete for susceptible hosts. Introduce simplified
cross-immunity only once ordinary spread and the cure race are balanced.

Show a lineage tree and distinguish variants with consistent colors and subtle
specimen differences. A new variant starts in a region; it does not instantly
replace every infection worldwide. Cap variant count for readability and cost.
Random mutation events should offer a comprehensible choice or tradeoff rather
than repeatedly producing free, universally beneficial upgrades.

## Screens and feedback

**New game:** archetype, difficulty, scenario, starting region, seed, and optional
tutorial. Explain the objective before play begins.

**World overview:** globe, regional selection, outbreak totals, evolution points,
cure progress, speed controls, and a compact event feed. Region selection opens
its population trends, connections, awareness, and active modifiers.

**Virus Lab:** large evolving specimen, upgrade branches, costs, prerequisites,
and effect previews. Keep the fictional starter cards for new games and Sandbox;
do not let them silently replace a paid build during an active run.

**Results:** victory/defeat reason, timeline, regions reached, build, research
progress, and a retry button using the same seed. Include a new-seed option.

Keep the indigo/lilac visual direction. Use cyan for information, pink for world
response, and distinct state colors with text labels. Make alerts readable
without sound or color alone. Prefer fewer useful charts to decorative numbers.

## Code organization

Suggested modules, introduced incrementally:

```text
scripts/simulation/simulation.gd       Fixed ticks and population transitions
scripts/simulation/run_state.gd       Regions, history, seed, objectives
scripts/simulation/travel.gd          Route allocation and arrival events
scripts/visuals/flight_scheduler.gd   Staggered departures and continuous flights
scripts/game/evolution.gd             Costs, prerequisites, modifiers, rewards
scripts/game/world_response.gd        Awareness, policies, cure progress
scripts/game/events.gd                Scheduled and seeded world events
scripts/game/save_game.gd             Versioned run serialization
scripts/ui/                          Overview, lab, region panel, results
data/upgrades/                       Upgrade definitions
data/scenarios/                      Maps, objectives, difficulty presets
```

Split the growing `scripts/dashboard.gd` as features are added. Reuse
`scripts/virus_preview.gd` behind a visual-profile interface. Replace the playback
and flight scheduling responsibilities of `scripts/main_controller.gd` gradually.
Keep scene rendering out of the simulation and make UI updates signal-driven.

Save population state, tick, RNG state, purchases, claimed rewards, active events,
policy timers, research, objectives, and visual seed. Include a schema version and
an atomic write so an interrupted save does not destroy the previous one.

## Build roadmap and acceptance criteria

### Milestone 1 — a run the player can influence

Implement fixed ticks, the seven-region map, evolution points, three upgrades,
one objective, and a basic world response. Connect the existing UI and introduce
continuous, staggered flights rather than daily plane batches.

**Done when:** a player can start, pause, purchase an upgrade, observe its effect
without restarting, and reach a clear ending. Totals stay valid at every speed.

### Milestone 2 — the strategy vertical slice

Expand to twelve upgrades, prerequisites, regional awareness, cure progress,
three events, and a tutorial. Add start and results screens.

**Done when:** multiple builds can finish the scenario, players can explain why
they won or lost, and at least three materially different choices occur per run.

### Milestone 3 — the specimen and interface

Introduce visual profiles, purchase animations, region detail panels, effect
previews, readable notifications, and reduced-motion support.

**Done when:** different builds look different, purchases have immediate feedback,
and important controls remain visible at the supported minimum window size.

### Milestone 4 — reliability and release preparation

Add save/resume, difficulty presets, balance telemetry, export validation, and
performance checks. Remove Python from the required gameplay startup path.

**Done when:** saved runs resume reproducibly, the exported build works without
Python installed, and a complete run passes without errors or invalid counts.

### Milestone 5 — variants and additional scenarios

Add limited variant coexistence, a lineage view, more archetypes, scenario rules,
and unlocks. Expand the world only if more regions improve decisions.

**Done when:** variant changes have understandable regional consequences and new
scenarios require different strategies rather than just longer play sessions.

## Verification and tuning

- Unit-check population conservation, nonnegative counts, bounded travel,
  purchase prerequisites, reward uniqueness, and event expiration.
- Verify identical results across playback speeds with the same seed/actions.
- Verify save/load equivalence against an uninterrupted run.
- Run seeded scenario batches to catch unwinnable setups and dominant builds.
- Record time to first purchase, time to detection, run duration, upgrade picks,
  ending reason, and points left unspent.
- Playtest the first minute separately: players should know their objective,
  available action, and why their first purchase matters.

Do not start with molecular dynamics, real pathogen calibration, a huge map,
multiplayer, or an unrestricted mutation tree. Deliver the small strategy loop
first, then expand the parts players find fun.


## Implementation status

The first playable Strategy mode is implemented in `ui.tscn`; the original viewer
and slider Sandbox remain in `viewer.tscn`. It includes the seven-region fixed-tick
simulation, twelve data-driven purchases, three loadouts and difficulties, regional
responses and cure, three event types, tutorial rewards, continuous flights,
visual profiles and assembly feedback, results, and exact versioned save/resume.
See `README.md` for controls, module locations and verification commands.

Automated checks cover population invariants, reward uniqueness, prerequisites,
event expiry, deterministic save/load, flight scheduling, pause/speeds, UI bounds,
endings, and eighteen seeded runs with three builds. The exported resource pack
completes a run independently of the project directory with an empty `PATH`. Milestones 1–4 have their playable
implementation, but manual three-day traffic observation, rendered UX playtests,
performance profiling, broader balance exploration, and standalone executable
validation remain release checks. Milestone 5 remains deferred until the core loop
has been playtested, as specified above.
