from __future__ import annotations
import os
import sys
import time
import csv
import io
import logging
import requests
from typing import Dict, List, Optional, Iterable
from pathlib import Path
import xml.etree.ElementTree as ET
from datetime import datetime, timezone


# --- Configuration ---
BLIZZARD_CLIENT_ID = os.getenv("BLIZZARD_CLIENT_ID")
BLIZZARD_CLIENT_SECRET = os.getenv("BLIZZARD_CLIENT_SECRET")
BLIZZARD_OAUTH_URL = "https://oauth.battle.net/token"
BLIZZARD_API_BASE = "https://us.api.blizzard.com"
BLIZZARD_NAMESPACE = "dynamic-us"

RAIDERIO_DUNGEON_API_URL = "https://raider.io/api/v1/mythic-plus/static-data?expansion_id=" # Midnight needs adjustment when new expac releases
RAIDERIO_RAID_API_URL = "https://raider.io/api/v1/raiding/static-data?expansion_id="
WAGO_CSV_URL = "https://wago.tools/db2/JournalEncounter/csv"

DATA_DIR = os.path.join("Data")
OUTPUT_DIR = os.path.join(DATA_DIR, "Dungeons")

# Logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("generate-lua")


# --- Helpers ---
class BlizzardAuthError(Exception):
    pass

def fetch_raidbots_metadata():
    """Fetch metadata from raidbots to derive expansion ID from WoW build version.
    
    Returns (expansion_id, wow_build) tuple. Example: wow_build "11.1.7.61559" -> expansion_id 10
    """
    print("\nFetching raidbots metadata...")
    url = "https://www.raidbots.com/static/data/live/metadata.json"
    
    metadata = fetch_json(url)
    
    wow_build = metadata.get("wowBuild", "")  # e.g. "11.1.7.61559"
    if wow_build:
        major = int(wow_build.split(".", 1)[0])  # e.g. 11
        expansion_id = major - 1  # 11 -> expansion 10 (TWW)
        print(f"[OK] WoW build: {wow_build} -> expansion_id: {expansion_id}")
        return expansion_id, wow_build
    
    raise Exception(f"WoW build not found in raidbots metadata. {metadata}")


def get_blizzard_token(client_id: str, client_secret: str, oauth_url: str, retries: int = 3, backoff: float = 1.0) -> str:
    if not client_id or not client_secret:
        raise BlizzardAuthError("Missing BLIZZARD_CLIENT_ID or BLIZZARD_CLIENT_SECRET environment variables.")
    for attempt in range(1, retries + 1):
        try:
            r = requests.post(oauth_url, auth=(client_id, client_secret), data={"grant_type": "client_credentials"}, timeout=30)
            r.raise_for_status()
            j = r.json()
            token = j.get("access_token")
            if not token:
                raise BlizzardAuthError(f"OAuth response missing access_token: {j}")
            return token
        except Exception as e:
            log.warning("Blizzard token attempt %d failed: %s", attempt, e)
            if attempt == retries:
                raise BlizzardAuthError("Failed to obtain Blizzard OAuth token.") from e
            time.sleep(backoff * attempt)
    raise BlizzardAuthError("Unreachable")


def fetch_json(url: str, params: Optional[Dict] = None, headers: Optional[Dict] = None, timeout: int = 30) -> Dict:
    r = requests.get(url, params=params or {}, headers=headers or {}, timeout=timeout)
    r.raise_for_status()
    return r.json()


def fetch_text(url: str, params: Optional[Dict] = None, headers: Optional[Dict] = None, timeout: int = 30) -> str:
    r = requests.get(url, params=params or {}, headers=headers or {}, timeout=timeout)
    r.raise_for_status()
    return r.text


def parse_wago_csv(csv_text: str) -> List[Dict[str, str]]:
    f = io.StringIO(csv_text)
    reader = csv.DictReader(f)
    rows = [row for row in reader]
    return rows


def ensure_dir(path) -> None:
    Path(path).mkdir(parents=True, exist_ok=True)

def iso_to_unix(s: Optional[str]) -> Optional[int]:
    if not s:
        return None
    try:
        if s.endswith("Z"):
            dt = datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            return int(dt.timestamp())
        # accept offsets like +00:00
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return int(dt.timestamp())
    except Exception:
        try:
            dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
            return int(dt.timestamp())
        except Exception:
            log.warning("Failed to parse ISO timestamp: %s", s)
            return None


def int_or_none(x: Optional[str]) -> Optional[int]:
    if x is None:
        return None
    x = x.strip()
    if x == "":
        return None
    try:
        return int(x)
    except Exception:
        return None


def is_current_main_season(season: Dict, now: Optional[int] = None) -> bool:
    """Return True only for a main season that is live right now.

    Raider.IO's static data also returns expired seasons and non-main event
    seasons (e.g. "Break the Meta"). We only want the main season(s) that are
    currently running so old dungeons stop showing up in the settings. A season
    counts as running if, in at least one region, its start is in the past and
    its end is still in the future.
    """
    if not season.get("is_main_season"):
        return False
    if now is None:
        now = int(time.time())

    starts = season.get("starts", {}) or {}
    ends = season.get("ends", {}) or {}
    for region, start_iso in starts.items():
        start_ts = iso_to_unix(start_iso)
        if start_ts is None or start_ts > now:
            continue
        end_ts = iso_to_unix(ends.get(region))
        if end_ts is None or end_ts > now:
            return True
    return False


def build_lua_content(journal_instance_id: int, journal_instance_name: str, encounter_ids: List[int]) -> str:
    enc_list = ", ".join(str(i) for i in encounter_ids)
    content = (
        f"-- Auto-generated. Do not edit manually.\n"
        f"local addonName, private = ...\n"
        f"private.Instances = private.Instances or {{}}\n"
        f"-- {journal_instance_name.get("en_US", "")}\n"
        f"private.Instances[{journal_instance_id}] = private.Instances[{journal_instance_id}] or {{}}\n"
        f"private.Instances[{journal_instance_id}].encounters = {{ {enc_list} }}\n"
    )
    return content

def register_xml_namespaces():
    ns = "http://www.blizzard.com/wow/ui/"
    xsi = "http://www.w3.org/2001/XMLSchema-instance"
    ET.register_namespace("", ns)
    ET.register_namespace("xsi", xsi)
    return ns, xsi

def pretty_write_tree(tree: ET.ElementTree, xml_path: str) -> None:
    ET.indent(tree, space="  ")
    tree.write(xml_path, encoding="utf-8", xml_declaration=True)


def update_dungeons_xml(xml_path: str, script_paths: Iterable[str]) -> None:
    """Rewrite dungeons.xml so it references exactly the given script paths.

    The XML is rebuilt from scratch rather than merged with any existing content,
    so entries for dungeons from expired seasons are dropped instead of
    accumulating over time.
    """
    ns, xsi = register_xml_namespaces()
    script_tag = f"{{{ns}}}Script"
    root_tag = f"{{{ns}}}Ui"

    xml_dir = os.path.dirname(xml_path) or "."
    ensure_dir(xml_dir)

    root = ET.Element(root_tag)
    schema_loc_key = f"{{{xsi}}}schemaLocation"
    root.attrib[schema_loc_key] = "http://www.blizzard.com/wow/ui/ ..\\FrameXML\\UI.xsd"
    tree = ET.ElementTree(root)

    for file_attr in sorted(set(script_paths or [])):
        ET.SubElement(root, script_tag, {"file": file_attr})

    pretty_write_tree(tree, xml_path)


def prune_stale_dungeon_files(output_dir: str, keep_instance_ids: set[int]) -> None:
    """Delete Dungeons/<id>.lua files whose instance id is no longer part of any
    current season, so expired-season dungeons stop being registered/displayed."""
    if not os.path.isdir(output_dir):
        return
    for entry in os.listdir(output_dir):
        if not entry.endswith(".lua"):
            continue
        stem = entry[:-len(".lua")]
        instance_id = int_or_none(stem)
        if instance_id is None:
            log.warning("Skipping unexpected file in %s: %s", output_dir, entry)
            continue
        if instance_id not in keep_instance_ids:
            stale_path = os.path.join(output_dir, entry)
            try:
                os.remove(stale_path)
                log.info("Removed stale dungeon file %s", stale_path)
            except OSError as e:
                log.warning("Failed to remove stale dungeon file %s: %s", stale_path, e)



# --- Main flow ---
def main():
    # validate required env
    if not BLIZZARD_CLIENT_ID or not BLIZZARD_CLIENT_SECRET:
        log.error("BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET must be set in environment.")
        sys.exit(2)
    expansion_id, wow_build = fetch_raidbots_metadata()
    log.info("Fetching Raider.IO static data from %s%s", RAIDERIO_DUNGEON_API_URL, expansion_id)
    try:
        ri_data = fetch_json(f"{RAIDERIO_DUNGEON_API_URL}{expansion_id}")
    except Exception as e:
        log.error("Failed to fetch Raider.IO data: %s", e)
        sys.exit(3)

    # load Wago CSV once
    log.info("Fetching Wago CSV from %s", WAGO_CSV_URL)
    try:
        csv_text = fetch_text(WAGO_CSV_URL)
    except Exception as e:
        log.error("Failed to fetch Wago CSV: %s", e)
        sys.exit(4)

    wago_rows = parse_wago_csv(csv_text)
    # build map from JournalInstanceID -> list of DungeonEncounterID
    jmap: Dict[int, List[int]] = {}
    for row in wago_rows:
        ji_raw = row.get("JournalInstanceID", "").strip()
        de_raw = row.get("DungeonEncounterID", "").strip()
        ji = int_or_none(ji_raw)
        de = int_or_none(de_raw)
        if ji is None or de is None:
            continue
        jmap.setdefault(ji, []).append(de)

    # Get blizzard token
    try:
        token = get_blizzard_token(BLIZZARD_CLIENT_ID, BLIZZARD_CLIENT_SECRET, BLIZZARD_OAUTH_URL)
    except BlizzardAuthError as e:
        log.error("Blizzard authentication failed: %s", e)
        sys.exit(5)

    headers = {"Authorization": f"Bearer {token}"}

    # iterate seasons
    seasons = ri_data.get("seasons", [])
    if not seasons:
        log.warning("No seasons found in Raider.IO data.")
    created_script_paths: set[str] = set()
    current_instance_ids: set[int] = set()
    seasons_collection: Dict[str, Dict] = {}
    for season in seasons:
        # choose directory name: prefer slug, fallback to name
        season_slug = season.get("slug") or (season.get("short_name") or season.get("name") or "season")

        # Only keep the main season(s) that are currently running. This drops
        # expired seasons and non-main event seasons that Raider.IO still returns.
        if not is_current_main_season(season):
            log.info("Skipping season %s (not a currently running main season).", season_slug)
            continue

        season_dungeon_ids: List[int] = []

        dungeons = season.get("dungeons", [])
        if not dungeons:
            log.info("Season %s contains no dungeons, skipping.", season_slug)
            continue

        for dungeon in dungeons:
            challenge_mode_id = dungeon.get("challenge_mode_id")
            if challenge_mode_id is None:
                log.warning("Dungeon missing challenge_mode_id: %s", dungeon)
                continue

            # fetch from Blizzard
            bliz_url = f"{BLIZZARD_API_BASE}/data/wow/mythic-keystone/dungeon/{challenge_mode_id}"
            params = {"namespace": BLIZZARD_NAMESPACE}
            log.info("Requesting Blizzard keystone info for challenge_mode_id=%s", challenge_mode_id)
            try:
                djson = fetch_json(bliz_url, params=params, headers=headers)
            except Exception as e:
                log.error("Failed to fetch Blizzard data for challenge_mode_id %s: %s", challenge_mode_id, e)
                continue

            # extract journal instance id (djson['dungeon']['id'])
            dungeon_obj = djson.get("dungeon")
            if not dungeon_obj:
                log.warning("Blizzard response missing 'dungeon' field for challenge_mode_id %s", challenge_mode_id)
                continue
            journal_instance_id = dungeon_obj.get("id")
            if journal_instance_id is None:
                log.warning("Blizzard dungeon object missing 'id' for challenge_mode_id %s", challenge_mode_id)
                continue
            journal_instance_name = dungeon_obj.get("name", "unknown")
            try:
                journal_instance_id = int(journal_instance_id)
            except Exception:
                log.warning("Journal instance id not integer: %s", journal_instance_id)
                continue

            # lookup Wago CSV for encounters
            encounter_ids = sorted(set(jmap.get(journal_instance_id, [])))
            if not encounter_ids:
                # Still create file with empty encounters to signal no matches
                log.info("No encounters found in Wago CSV for JournalInstanceID=%s (dungeon: %s). Creating file with empty list.",
                         journal_instance_id, dungeon.get("name"))
            else:
                log.info("Found %d encounters for JournalInstanceID=%s", len(encounter_ids), journal_instance_id)

            lua_content = build_lua_content(journal_instance_id, journal_instance_name, encounter_ids)
            out_path = os.path.join(OUTPUT_DIR, f"{journal_instance_id}.lua")
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(lua_content)
            log.info("Wrote %s", out_path)
            created_script_paths.add(out_path.replace(os.sep, "/"))
            current_instance_ids.add(journal_instance_id)
            if journal_instance_id not in season_dungeon_ids:
                season_dungeon_ids.append(journal_instance_id)

        seasons_collection[season_slug] = {
            "name": season.get("name", ""),
            "short_name": season.get("short_name", ""),
            "starts": season.get("starts", {}) or {},
            "ends": season.get("ends", {}) or {},
            "dungeons": sorted(set(season_dungeon_ids)),
        }
    # Remove dungeon files belonging to seasons that are no longer returned by
    # Raider.IO, so they stop being registered and shown in the settings.
    prune_stale_dungeon_files(OUTPUT_DIR, current_instance_ids)

    dungeons_xml_path = os.path.join("Data", "dungeons.xml")
    update_dungeons_xml(dungeons_xml_path, created_script_paths)
    log.info("Updated dungeons XML: %s", dungeons_xml_path)

    seasons_lines: List[str] = [
        "-- Auto-generated. Do not edit manually.",
        "local addonName, private = ...",
        "private.Seasons = private.Seasons or {}",
        "",
    ]
    for slug, s in seasons_collection.items():
        # escape quotes in strings
        name = s["name"].replace('"', '\\"')
        short = s["short_name"].replace('"', '\\"')
        starts_pairs = []
        for k, v in s["starts"].items():
            ts = iso_to_unix(v)
            if ts is not None:
                starts_pairs.append(f'{k} = {ts}')
        starts_items = ", ".join(starts_pairs)

        ends_pairs = []
        for k, v in s["ends"].items():
            ts = iso_to_unix(v)
            if ts is not None:
                ends_pairs.append(f'{k} = {ts}')
        ends_items = ", ".join(ends_pairs)
        dungeons_list = ", ".join(str(i) for i in s["dungeons"])

        seasons_lines.append(f'private.Seasons["{slug}"] = {{ \n  name = "{name}", \n  short_name = "{short}", \n  starts = {{ {starts_items} }}, \n  ends = {{ {ends_items} }}, \n  dungeons = {{ {dungeons_list} }} \n}}')
        seasons_lines.append("")

    seasons_content = "\n".join(seasons_lines) + "\n"
    seasons_path = os.path.join(DATA_DIR, "seasons.lua")
    with open(seasons_path, "w", encoding="utf-8") as fh:
        fh.write(seasons_content)
    log.info("Wrote seasons summary %s", seasons_path)

    log.info("All done.")


if __name__ == "__main__":
    main()
