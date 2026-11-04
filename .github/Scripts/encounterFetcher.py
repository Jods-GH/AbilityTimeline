from __future__ import annotations
import csv
import io
import os
import sys
import logging
import requests
from typing import Dict, List, Optional

# Writes Data/Encounters/<game type>.lua for the game types the addon supports (the flavors of autoToc.yml): every
# dungeon and raid encounter with its instance, and the instances of the current content, from the game's own tables on
# wago.tools of the latest build of the game type's live product. The toc loads each file only on its game type with
# AllowLoadGameType and ExcludeLoadGameType. The current content is the Adventure Guide's current season where the
# game has one (retail), else the raids of the newest expansion.

WAGO_LATEST_BUILDS_URL = "https://wago.tools/api/builds/latest"
WAGO_CSV_URL = "https://wago.tools/db2/{table}/csv"
OUTPUT_DIR = os.path.join("Data", "Encounters")
# file name -> live wago.tools product, PTR and beta clients load the file of their game type with the live data
GAME_TYPES = {
    "Retail": "wow",
    "Forever": "wowf",
    "Mists": "wow_classic",
    "Wrath": "wow_classic_titan",
    "TBC": "wow_anniversary",
    "Vanilla": "wow_classic_era",
}
DUNGEON, RAID = "1", "2"
# the expansion of the Adventure Guide's "Current Season" tier
CURRENT_SEASON_EXPANSION = "9000"
MIN_ENCOUNTERS = 50

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("encounter-fetcher")


def number(value: Optional[str]) -> int:
    try:
        return int(float(value or 0))
    except ValueError:
        return 0


def latest_builds() -> Dict[str, str]:
    """product -> version of its latest build"""
    r = requests.get(WAGO_LATEST_BUILDS_URL, timeout=60)
    r.raise_for_status()
    return {product: build["version"] for product, build in r.json().items() if isinstance(build, dict)}


def load(table: str, build: str) -> List[Dict[str, str]]:
    """a table of the build, empty where the version doesn't have it (only retail and Mists have the Adventure Guide)"""
    r = requests.get(WAGO_CSV_URL.format(table=table), params={"build": build}, timeout=180)
    if r.status_code == 400:
        return []
    r.raise_for_status()
    return list(csv.DictReader(io.StringIO(r.text)))


def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


TABLES = ["DungeonEncounter", "Map", "JournalTier", "JournalTierXInstance", "JournalInstance", "JournalEncounter"]


def build_file(name: str, build: str):
    t = {table: load(table, build) for table in TABLES}
    maps = {row["ID"]: row for row in t["Map"]}
    journal_instances = {row["ID"]: row for row in t["JournalInstance"]}
    # the journal holds a dungeon encounter in the instance it shows it in: world bosses are on the open world map
    journal_of = {}
    for row in t["JournalEncounter"]:
        if number(row["DungeonEncounterID"]) and row["JournalInstanceID"] in journal_instances:
            journal_of.setdefault(number(row["DungeonEncounterID"]), row)

    instances: Dict[int, Dict] = {}
    encounters: Dict[int, Dict] = {}
    for row in t["DungeonEncounter"]:
        encounter_id = number(row["ID"])
        journal = journal_of.get(encounter_id)
        if journal:
            journal_instance = journal_instances[journal["JournalInstanceID"]]
            map_id = number(journal_instance["MapID"])
            instance = instances.setdefault(map_id, {"name": journal_instance["Name_lang"]})
            instance.setdefault("journalInstanceID", number(journal_instance["ID"]))
        else:
            map_row = maps.get(row["MapID"])
            if not map_row or map_row["InstanceType"] not in (DUNGEON, RAID):
                continue
            map_id = number(row["MapID"])
            instances.setdefault(map_id, {"name": map_row["MapName_lang"]})
        encounters[encounter_id] = {
            "name": row["Name_lang"],
            "map": map_id,
            "order": number(journal["OrderIndex"]) if journal else number(row["OrderIndex"]),
            "difficulty": number(row["DifficultyID"]),
            "journalEncounterID": number(journal["ID"]) if journal else None,
        }
    # an instance without a journal entry of its own takes the one of the map, the name stays the journal's
    for journal_instance in journal_instances.values():
        instance = instances.get(number(journal_instance["MapID"]))
        if instance and "journalInstanceID" not in instance:
            instance["journalInstanceID"] = number(journal_instance["ID"])
            instance["name"] = journal_instance["Name_lang"]

    current_maps: List[int] = []
    season = [tier for tier in t["JournalTier"] if tier.get("Expansion") == CURRENT_SEASON_EXPANSION]
    if season:
        rows = sorted((row for row in t["JournalTierXInstance"] if row["JournalTierID"] == season[0]["ID"]),
                      key=lambda row: (number(row["OrderIndex"]), number(row["ID"])))
        for row in rows:
            journal_instance = journal_instances.get(row["JournalInstanceID"])
            map_id = journal_instance and number(journal_instance["MapID"])
            # the season's pages about keystones and affixes are an instance of a map of no expansion
            if number(maps.get(str(map_id), {}).get("ExpansionID")) == 0:
                continue
            if map_id and map_id not in current_maps:
                current_maps.append(map_id)
    else:
        raids = {encounter["map"] for encounter in encounters.values()
                 if maps.get(str(encounter["map"]), {}).get("InstanceType") == RAID}
        newest = max((number(maps[str(m)]["ExpansionID"]) for m in raids), default=0)
        current_maps = sorted(m for m in raids if number(maps[str(m)]["ExpansionID"]) == newest)

    # the encounters of a current instance once per name: difficulties of old content have encounters of their own,
    # the one of all difficulties wins, then the lowest id
    current = []
    for map_id in current_maps:
        best: Dict[str, int] = {}
        for encounter_id, encounter in encounters.items():
            if encounter["map"] != map_id:
                continue
            other = best.get(encounter["name"])
            rank = (encounter["difficulty"] != 0, encounter_id)
            if other is None or rank < (encounters[other]["difficulty"] != 0, other):
                best[encounter["name"]] = encounter_id
        ids = sorted(best.values(), key=lambda i: (encounters[i]["order"], i))
        if ids:
            current.append((map_id, ids))

    lines = [
        "-- Auto-generated by .github/Scripts/encounterFetcher.py from the game data on wago.tools. Do not edit manually.",
        f"-- {name}, build {build}; the toc loads it only on this game type",
        "local addonName, private = ...",
        "-- instances by map id, the journal instance where the Adventure Guide has one",
        "private.EncounterInstances = {",
    ]
    for map_id in sorted(instances):
        instance = instances[map_id]
        journal = f", journalInstanceID = {instance['journalInstanceID']}" if instance.get("journalInstanceID") else ""
        lines.append(f"    [{map_id}] = {{ name = {lua_string(instance['name'])}{journal} }},")
    lines += [
        "}",
        "-- dungeon encounter id -> its name, the map of its instance, its place in it, the journal encounter where the",
        "-- Adventure Guide has one",
        "private.Encounters = {",
    ]
    for encounter_id in sorted(encounters):
        encounter = encounters[encounter_id]
        journal = f", journalEncounterID = {encounter['journalEncounterID']}" if encounter["journalEncounterID"] else ""
        lines.append(f"    [{encounter_id}] = {{ name = {lua_string(encounter['name'])}, map = {encounter['map']}, "
                     f"order = {encounter['order']}{journal} }},")
    lines += [
        "}",
        "-- the instances of the current content and their encounters, in order",
        "private.CurrentInstances = {",
    ]
    for map_id, ids in current:
        lines.append(f"    {{ map = {map_id}, encounters = {{ {', '.join(str(i) for i in ids)} }} }}, "
                     f"-- {instances[map_id]['name']}")
    lines.append("}")
    with open(os.path.join(OUTPUT_DIR, f"{name}.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return len(encounters), [instances[m]["name"] for m, _ in current]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    builds = latest_builds()
    for name, product in GAME_TYPES.items():
        build = builds.get(product)
        if not build:
            log.error("No build of %s on wago.tools for %s", product, name)
            sys.exit(1)
        count, current = build_file(name, build)
        log.info("%s (%s %s): %d encounters, current: %s", name, product, build, count, ", ".join(current))
        if count < MIN_ENCOUNTERS or not current:
            log.error("Only %d encounters and %d current instances for %s, the tables may have changed", count,
                      len(current), name)
            sys.exit(1)
    # files of game types no longer listed go, the toc lists the files of GAME_TYPES
    for file_name in os.listdir(OUTPUT_DIR):
        if file_name[:-4] not in GAME_TYPES:
            os.remove(os.path.join(OUTPUT_DIR, file_name))


if __name__ == "__main__":
    main()
