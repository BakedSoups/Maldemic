extends RefCounted

# Deliberately independent of balance: motifs describe a fictional character.
static func derive(state: Dictionary, evolution: RefCounted) -> Dictionary:
	var counts := {"Spread": 0, "Impact": 0, "Adaptation": 0}
	for id in state.purchases:
		counts[evolution.definition(id).branch] += 1
	return {"infection_rate": 0.15 + counts.Spread * 0.18, "lethality": 0.05 + counts.Impact * 0.1, "mutation_rate": counts.Adaptation * 0.02, "recovery_rate": 0.2, "incubation_period": 5.0 + counts.Adaptation, "symptom_severity": 2.0 + counts.Impact * 1.8, "transmission_mode": {"Drifter": "airborne", "Quiet shell": "droplet", "Prism": "contact"}[state.loadout], "visual_seed": state.visual_seed, "plates": counts.Adaptation, "nodes": counts.Impact}
