from simulation import *
import pprint
import copy
import json
import sys
import os

print("Script arguments:", sys.argv)

class SIR_Simulation_Parameters:
    def __init__(self):
        self.state = {
            "vector": [[808987, 1, 0, 0], [8258000, 0, 0, 0], [455924, 0, 0, 0],
                      [2664000, 0, 0, 0], [2103000, 0, 0, 0], [8866000, 0, 0, 0],
                      [3971000, 0, 0, 0], [6747000, 0, 0, 0], [1744000, 0, 0, 0],
                      [5601000, 0, 0, 0], [12678000, 0, 0, 0]],
            "infection_rate": 0.9,
            "recovery_rate": 0.4,
            "matrix": None
        }
        self.cities = [
            {"name": "SF", "population": 808988, "latitude": 37.7749, "longitude": -122.4194},  # San Francisco
            {"name": "CHI", "population": 2664000, "latitude": 41.8781, "longitude": -87.6298},  # Chicago
            {"name": "LON", "population": 8866000, "latitude": 51.5074, "longitude": -0.1278},   # London
            {"name": "MA", "population": 3971000, "latitude": 42.3601, "longitude": -71.0589},   # Massachusetts
            {"name": "WA", "population": 455924, "latitude": 38.9072, "longitude": -77.0369},    # Washington DC
            {"name": "PA", "population": 2103000, "latitude": 48.8566, "longitude": 2.3522},     # Paris
            {"name": "NYC", "population": 8258000, "latitude": 40.7128, "longitude": -74.0060},  # New York
        ]
       
        self.virus = {
            "current_strain": "original",
            "strains": {
                "original": {
                    "parent": None,
                    "emergence_day": 0,
                    "infection_rate": 0.9,
                    "recovery_rate": 0.4,
                    "lethality": 0.015,  # 1.5% lethality
                    "attributes": {
                        "transmission_mode": "droplet",
                        "incubation_period": 5,
                        "symptom_severity": 6  # 1-10 scale
                    }
                }
            },
            "infection_rate": 0.9,
            "recovery_rate": 0.4,
            "lethality": 0.015,
            "mutation_rate": 0.002,  #chance of mutation per day per infected population
            "attributes": {
                "transmission_mode": "droplet",
                "incubation_period": 5,
                "symptom_severity": 6
            }
        }

books = SIR_Simulation_Parameters()
state_dictionary = books.state
city_array = books.cities
virus_config = books.virus

if len(sys.argv) > 1 and sys.argv[1] == "CustomVirus":
    try:
        strain_name = sys.argv[2]
        
        json_file_path = sys.argv[3]
        if json_file_path.startswith("res://"):
            json_file_path = json_file_path.replace("res://", os.path.dirname(os.path.abspath(__file__)) + "/../")
        
        print(f"Reading virus data from file: {json_file_path}")
        
        with open(json_file_path, 'r') as f:
            virus_data = json.load(f)
        
        custom_virus = copy.deepcopy(virus_config)
        custom_virus["current_strain"] = strain_name
        custom_virus["infection_rate"] = virus_data["infection_rate"]
        custom_virus["recovery_rate"] = virus_data["recovery_rate"]
        custom_virus["lethality"] = virus_data["lethality"]
        
        custom_virus["strains"] = {
            strain_name: {
                "parent": None,
                "emergence_day": 0,
                "infection_rate": virus_data["infection_rate"],
                "recovery_rate": virus_data["recovery_rate"],
                "lethality": virus_data["lethality"],
                "attributes": {
                    "transmission_mode": virus_data.get("transmission_mode", "droplet"),
                    "incubation_period": int(virus_data.get("incubation_period", 5)),
                    "symptom_severity": int(virus_data.get("symptom_severity", 6))
                }
            }
        }
        
        custom_virus["attributes"] = copy.deepcopy(custom_virus["strains"][strain_name]["attributes"])
        custom_virus["mutation_rate"] = virus_data.get("mutation_rate", 0.002)
        virus_config = custom_virus
        seed = virus_data["seed_city"]
        
        print(f"\nStarting pandemic simulation with custom virus...")
        print(f"Strain Name: {strain_name}")
        print(f"Infection Rate: {virus_data['infection_rate']}")
        print(f"Recovery Rate: {virus_data['recovery_rate']}")
        print(f"Lethality: {virus_data['lethality']}")
        print(f"Seed City: {seed}")
    except Exception as e:
        print(f"Error setting up custom virus: {str(e)}")
        import traceback
        traceback.print_exc()
        seed = "SF"
        print("\nUsing default virus configuration due to error.")
else:
    seed = "SF"
    print("\nStarting pandemic simulation with default virus...")

state_dictionary, city_dictionary = start_pandemic(seed, state_dictionary, city_array, virus_config)

if len(sys.argv) > 1 and sys.argv[1] == "CustomVirus":
    strain_name = sys.argv[2]  # Get the custom name
    
    if "virus" in state_dictionary:
        original_strain_data = state_dictionary["virus"]["strains"].pop("original", None)
        if original_strain_data:
            state_dictionary["virus"]["strains"][strain_name] = original_strain_data
            state_dictionary["virus"]["current_strain"] = strain_name
    
    if "virus_history" in city_dictionary:
        for day_key in city_dictionary["virus_history"]:
            if day_key in city_dictionary["virus_history"] and "strains" in city_dictionary["virus_history"][day_key] and "original" in city_dictionary["virus_history"][day_key]["strains"]:
                original_strain_data = city_dictionary["virus_history"][day_key]["strains"].pop("original", None)
                if original_strain_data:
                    city_dictionary["virus_history"][day_key]["strains"][strain_name] = original_strain_data
                    city_dictionary["virus_history"][day_key]["current_strain"] = strain_name

if "virus_history" not in city_dictionary:
    print("Initializing virus_history in city_dictionary...")
    city_dictionary["virus_history"] = {
        "day_0": {
            "current_strain": virus_config["current_strain"],
            "strains": copy.deepcopy(virus_config["strains"]),
            "mutation_rate": virus_config["mutation_rate"]
        }
    }

preloaded = {}
preloaded["day_0"] = copy.deepcopy(city_dictionary)
pandemic_status = city_dictionary

active_strains = {virus_config["current_strain"]}
mutation_days = {}

for i in range(1,50):
    pandemic_status = add_day(state_dictionary, pandemic_status, city_array)
    preloaded[f"day_{i}"] = copy.deepcopy(pandemic_status)
   
    current_day = i
   
    day_key = f"day_{i}"
    if "virus" in state_dictionary:
        if "virus_history" not in pandemic_status:
            pandemic_status["virus_history"] = {}
           
        pandemic_status["virus_history"][day_key] = {
            "current_strain": state_dictionary["virus"]["current_strain"],
            "strains": copy.deepcopy(state_dictionary["virus"]["strains"]),
            "mutation_rate": state_dictionary["virus"]["mutation_rate"]
        }
       
        current_strain = state_dictionary["virus"]["current_strain"]
        if current_strain not in active_strains:
            active_strains.add(current_strain)
            mutation_days[current_strain] = i
           
            strain_data = state_dictionary["virus"]["strains"][current_strain]
            parent = strain_data["parent"]
            if parent and parent in state_dictionary["virus"]["strains"]:
                parent_data = state_dictionary["virus"]["strains"][parent]
                inf_change = (strain_data["infection_rate"] / parent_data["infection_rate"] - 1) * 100
                leth_change = (strain_data["lethality"] / parent_data["lethality"] - 1) * 100
               
                print(f"\n=== NEW MUTATION on Day {i} ===")
                print(f"Strain: {current_strain} (evolved from {parent})")
                print(f"Infection rate: {strain_data['infection_rate']:.3f} ({inf_change:+.1f}%)")
                print(f"Lethality: {strain_data['lethality']:.4f} ({leth_change:+.1f}%)")
               
                if strain_data["attributes"]["transmission_mode"] != parent_data["attributes"]["transmission_mode"]:
                    print(f"Transmission changed: {parent_data['attributes']['transmission_mode']} → {strain_data['attributes']['transmission_mode']}")
   
    print(f"Simulated day {i}/50")
print("\nVirus information structure check:")
sample_day_key = "day_1"
if sample_day_key in preloaded:
    sample_day = preloaded[sample_day_key]
    
    print(f"Keys in day 1 data: {sample_day.keys()}")
    
    if "virus_history" in sample_day:
        virus_history = sample_day["virus_history"]
        print(f"Keys in virus_history: {virus_history.keys()}")
        
        if sample_day_key in virus_history:
            virus_data = virus_history[sample_day_key]
            print(f"Virus on day 1: {virus_data['current_strain']}")
            print(f"Infection rate: {virus_data['strains'][virus_data['current_strain']]['infection_rate']}")
        else:
            print(f"Day key {sample_day_key} not found in virus_history")
    else:
        print("No virus_history found in day data")

output_path = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "pandemic_simulation.json")
print(f"Writing output to: {output_path}")
with open(output_path, "w") as f:
    json.dump(preloaded, f)

print("Simulation completed and data saved.")