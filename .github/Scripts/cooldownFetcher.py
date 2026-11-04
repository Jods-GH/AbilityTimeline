from __future__ import annotations
import csv
import io
import os
import sys
import logging
import requests
from collections import defaultdict
from typing import Dict, List, Optional, Set, Tuple

# Writes Data/Cooldowns/<game type>.lua for the game types the addon supports (the flavors of autoToc.yml): the spells
# with a cooldown each class (and spec, where the game type has specs) has, from the game's own tables on wago.tools of
# the latest build of the game type's live product. The toc loads each file only on its game type with
# AllowLoadGameType and ExcludeLoadGameType. The tables don't tell offensive from defensive or raid cooldowns, so the
# list is not sorted by that.

WAGO_LATEST_BUILDS_URL = "https://wago.tools/api/builds/latest"
WAGO_CSV_URL = "https://wago.tools/db2/{table}/csv"
OUTPUT_DIR = os.path.join("Data", "Cooldowns")
# file name -> live wago.tools product, PTR and beta clients load the file of their game type with the live data
GAME_TYPES = {
    "Retail": "wow",
    "Forever": "wowf",
    "Mists": "wow_classic",
    "Wrath": "wow_classic_titan",
    "TBC": "wow_anniversary",
    "Vanilla": "wow_classic_era",
}
# cooldowns shorter than this are rotation spells; the old versions have cooldowns of up to an hour (Shield Wall)
MIN_COOLDOWN = 30000
MAX_COOLDOWN = 3600000
PASSIVE_ATTRIBUTE = 0x40
CLASS_SKILL_CATEGORY = "7"
SPEC_SET_CONDITION = "1"
TALENT_RANKS = 9
SPEC_PRIORITY, SKILL_LINE_PRIORITY = 2, 1

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("cooldown-fetcher")


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
    """a table of the build, empty where the version doesn't have it"""
    r = requests.get(WAGO_CSV_URL.format(table=table), params={"build": build}, timeout=180)
    if r.status_code == 400:
        return []
    r.raise_for_status()
    return list(csv.DictReader(io.StringIO(r.text)))


def class_spells(t: Dict[str, List[Dict[str, str]]]) -> Tuple[Dict[int, Dict], bool]:
    """spell id -> class file name, the spec ids that have it and how sure it is a spell of them; whether the version
    has specs"""
    classes = {row["ID"]: row for row in t["ChrClasses"]}
    class_by_bit = {1 << (number(class_id) - 1): class_id for class_id in classes if number(class_id) > 0}
    specs_of_class: Dict[str, Set[int]] = defaultdict(set)
    spec_class: Dict[str, str] = {}
    for row in t["ChrSpecialization"]:
        # the "Initial" spec of characters below level 10 is no spec players plan for
        if row["ClassID"] in classes and row["ClassID"] != "0" and row["Name_lang"] != "Initial":
            specs_of_class[row["ClassID"]].add(int(row["ID"]))
            spec_class[row["ID"]] = row["ClassID"]
    has_specs = bool(spec_class)
    spells: Dict[int, Dict] = {}

    def add(spell_id: int, class_id: str, specs: Set[int], priority: int):
        if not spell_id or class_id not in classes:
            return
        entry = spells.setdefault(spell_id, {"class": classes[class_id]["Filename"], "specs": set(), "priority": 0})
        entry["specs"] |= specs
        entry["priority"] = max(entry["priority"], priority)

    # baseline spells of a spec
    for row in t["SpecializationSpells"]:
        if row["SpecID"] in spec_class:
            add(number(row["SpellID"]), spec_class[row["SpecID"]], {int(row["SpecID"])}, SPEC_PRIORITY)
    # baseline spells of a class from its skill lines: one line per class, before Mists one per talent tree (two
    # classes have a "Restoration"), so the class comes from the ability's class mask, the line's class
    # (SkillRaceClassInfo) and else the line's name
    class_by_name = {row["Name_lang"]: row["ID"] for row in t["ChrClasses"]}
    class_lines = {row["ID"]: row for row in t["SkillLine"] if row["CategoryID"] == CLASS_SKILL_CATEGORY}
    line_class: Dict[str, str] = {}
    for row in t["SkillRaceClassInfo"]:
        class_id = class_by_bit.get(number(row["ClassMask"]))
        if row["SkillID"] in class_lines and class_id:
            line_class[row["SkillID"]] = class_id
    for row in t["SkillLineAbility"]:
        line = class_lines.get(row["SkillLine"])
        if not line:
            continue
        class_id = (class_by_bit.get(number(row["ClassMask"])) or line_class.get(row["SkillLine"])
                    or class_by_name.get(line["DisplayName_lang"]))
        if class_id:
            add(number(row["Spell"]), class_id, specs_of_class[class_id], SKILL_LINE_PRIORITY)
    # talents before Dragonflight: the Talent table, its spell or the spell of each rank
    tab_class = {row["ID"]: class_by_bit.get(number(row["ClassMask"])) for row in t["TalentTab"]}
    for row in t["Talent"]:
        class_id = row["ClassID"] if row["ClassID"] in classes and row["ClassID"] != "0" else tab_class.get(row["TabID"])
        if not class_id:
            continue
        specs = {int(row["SpecID"])} if row["SpecID"] in spec_class else specs_of_class[class_id]
        for spell_id in [number(row["SpellID"])] + [number(row.get(f"SpellRank_{i}")) for i in range(TALENT_RANKS)]:
            add(spell_id, class_id, specs, SPEC_PRIORITY)
    # talents since Dragonflight: the specs of the tree's loadouts, nodes limited to a spec set only for those specs
    tree_specs: Dict[str, Set[int]] = defaultdict(set)
    for row in t["TraitTreeLoadout"]:
        if row["ChrSpecializationID"] in spec_class:
            tree_specs[row["TraitTreeID"]].add(int(row["ChrSpecializationID"]))
    spec_sets: Dict[str, Set[int]] = defaultdict(set)
    for row in t["SpecSetMember"]:
        spec_sets[row["SpecSet"]].add(int(row["ChrSpecializationID"]))
    cond_specs = {row["ID"]: spec_sets[row["SpecSetID"]] for row in t["TraitCond"]
                  if row["CondType"] == SPEC_SET_CONDITION and row["SpecSetID"] in spec_sets}
    group_specs: Dict[str, Set[int]] = defaultdict(set)
    for row in t["TraitNodeGroupXTraitCond"]:
        if row["TraitCondID"] in cond_specs:
            group_specs[row["TraitNodeGroupID"]] |= cond_specs[row["TraitCondID"]]
    node_specs: Dict[str, Set[int]] = defaultdict(set)
    for row in t["TraitNodeGroupXTraitNode"]:
        if row["TraitNodeGroupID"] in group_specs:
            node_specs[row["TraitNodeID"]] |= group_specs[row["TraitNodeGroupID"]]
    nodes = {row["ID"]: row for row in t["TraitNode"]}
    entry_nodes: Dict[str, List[str]] = defaultdict(list)
    for row in t["TraitNodeXTraitNodeEntry"]:
        entry_nodes[row["TraitNodeEntryID"]].append(row["TraitNodeID"])
    definition_spells = {row["ID"]: number(row["SpellID"]) for row in t["TraitDefinition"]}
    for row in t["TraitNodeEntry"]:
        spell_id = definition_spells.get(row["TraitDefinitionID"])
        for node_id in entry_nodes.get(row["ID"], []):
            node = nodes.get(node_id)
            if not node or not spell_id:
                continue
            specs = tree_specs.get(node["TraitTreeID"], set())
            if node_specs.get(node_id):
                specs = specs & node_specs[node_id]
            if specs:
                add(spell_id, spec_class[str(next(iter(specs)))], specs, SPEC_PRIORITY)
    return spells, has_specs


def cooldowns(t: Dict[str, List[Dict[str, str]]]) -> Dict[int, int]:
    """spell id -> cooldown in milliseconds, the recharge time for spells with charges"""
    result: Dict[int, int] = {}
    for row in t["SpellCooldowns"]:
        if row.get("DifficultyID", "0") == "0":
            spell_id = number(row["SpellID"])
            result[spell_id] = max(result.get(spell_id, 0), number(row["RecoveryTime"]),
                                   number(row["CategoryRecoveryTime"]))
    charge_times = {row["ID"]: number(row["ChargeRecoveryTime"]) for row in t["SpellCategory"]}
    for row in t["SpellCategories"]:
        if row.get("DifficultyID", "0") == "0" and row.get("ChargeCategory") in charge_times:
            spell_id = number(row["SpellID"])
            result[spell_id] = max(result.get(spell_id, 0), charge_times[row["ChargeCategory"]])
    return result


TABLES = ["ChrClasses", "ChrSpecialization", "SpecializationSpells", "SkillLine", "SkillLineAbility",
          "SkillRaceClassInfo", "Talent",
          "TalentTab", "TraitTreeLoadout", "SpecSetMember", "TraitCond", "TraitNodeGroupXTraitCond",
          "TraitNodeGroupXTraitNode", "TraitNode", "TraitNodeXTraitNodeEntry", "TraitNodeEntry", "TraitDefinition",
          "SpellCooldowns", "SpellCategories", "SpellCategory", "SpellMisc", "SpellName"]


def build_file(name: str, build: str) -> int:
    t = {name: load(name, build) for name in TABLES}
    spells, has_specs = class_spells(t)
    cooldown_of = cooldowns(t)
    passive = {number(row["SpellID"]) for row in t["SpellMisc"]
               if row.get("DifficultyID", "0") == "0" and number(row["Attributes_0"]) & PASSIVE_ATTRIBUTE}
    spell_names = {number(row["ID"]): row["Name_lang"] for row in t["SpellName"]}
    # one spell per class, name and specs: the skill lines hold variants of a spell (Hex as frog, compy...) and the
    # versions before Cataclysm one spell per rank. A talent or spec spell wins, then the lowest id; spec spells of one
    # name for different specs (Ascendance) all stay
    best: Dict[tuple, tuple] = {}
    for spell_id, entry in spells.items():
        cooldown = cooldown_of.get(spell_id, 0)
        if spell_id in passive or not MIN_COOLDOWN <= cooldown <= MAX_COOLDOWN or spell_id not in spell_names:
            continue
        if has_specs and not entry["specs"]:
            continue
        key = (entry["class"], spell_names[spell_id], tuple(sorted(entry["specs"])))
        rank = (-entry["priority"], spell_id)
        if key not in best or rank < best[key][0]:
            best[key] = (rank, (entry["class"], spell_id, cooldown // 1000, entry["specs"]))
    rows = sorted(row for _, row in best.values())
    lines = [
        "-- Auto-generated by .github/Scripts/cooldownFetcher.py from the game data on wago.tools. Do not edit manually.",
        f"-- {name}, build {build}; the toc loads it only on this game type",
        "local addonName, private = ...",
        "-- cooldown in seconds, specs that have the spell (none before Mists of Pandaria)",
        "private.Cooldowns = {",
    ]
    for class_file, spell_id, cooldown, specs in rows:
        spec_list = ", ".join(str(s) for s in sorted(specs))
        lines.append(f'    [{spell_id}] = {{ class = "{class_file}", cooldown = {cooldown}, '
                     f"specs = {{ {spec_list} }} }}, -- {spell_names[spell_id]}")
    lines.append("}")
    with open(os.path.join(OUTPUT_DIR, f"{name}.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return len(rows)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    builds = latest_builds()
    for name, product in GAME_TYPES.items():
        build = builds.get(product)
        if not build:
            log.error("No build of %s on wago.tools for %s", product, name)
            sys.exit(1)
        count = build_file(name, build)
        log.info("%s (%s %s): %d cooldowns", name, product, build, count)
        if count < 30:
            log.error("Only %d cooldowns for %s, the tables may have changed", count, name)
            sys.exit(1)
    # files of game types no longer listed go, the toc lists the files of GAME_TYPES
    for file_name in os.listdir(OUTPUT_DIR):
        if file_name[:-4] not in GAME_TYPES:
            os.remove(os.path.join(OUTPUT_DIR, file_name))


if __name__ == "__main__":
    main()
