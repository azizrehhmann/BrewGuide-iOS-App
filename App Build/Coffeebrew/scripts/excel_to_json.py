#!/usr/bin/env python3
"""
excel_to_json.py — Converts the coffee brewing Excel database into 4 JSON files
for the BrewGuide iOS app.

Usage:
    python3 scripts/excel_to_json.py path/to/coffee_brewing_database.xlsx

Output:
    Coffeebrew/Resources/Data/methods.json
    Coffeebrew/Resources/Data/techniques.json
    Coffeebrew/Resources/Data/steps.json
    Coffeebrew/Resources/Data/beans.json
"""

import json
import os
import re
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("ERROR: openpyxl is required. Install with: pip3 install openpyxl")
    sys.exit(1)


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug for use as an ID."""
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


def parse_time_to_seconds(time_str: str) -> int:
    """Parse time strings like '3:30', '2:30 - 3:30', '12-24 hours' into seconds."""
    if not time_str:
        return 0
    time_str = str(time_str).strip()

    # Handle range — take the first value
    if " - " in time_str or " to " in time_str.lower():
        time_str = re.split(r"\s*[-–]\s*|\s+to\s+", time_str, maxsplit=1)[0].strip()

    # Handle "X hours"
    hour_match = re.search(r"(\d+)\s*hour", time_str, re.IGNORECASE)
    if hour_match:
        return int(hour_match.group(1)) * 3600

    # Handle "X:XX" format
    time_match = re.match(r"(\d+):(\d+)(?::(\d+))?", time_str)
    if time_match:
        parts = time_match.groups()
        minutes = int(parts[0])
        seconds = int(parts[1])
        if parts[2]:
            # H:MM:SS
            return minutes * 3600 + seconds * 60 + int(parts[2])
        return minutes * 60 + seconds

    # Handle "X min"
    min_match = re.search(r"(\d+)\s*min", time_str, re.IGNORECASE)
    if min_match:
        return int(min_match.group(1)) * 60

    return 0


def parse_temp(temp_str: str) -> int:
    """Extract first numeric temperature in Celsius."""
    if not temp_str:
        return 93
    temp_str = str(temp_str)
    match = re.search(r"(\d+)", temp_str)
    return int(match.group(1)) if match else 93


def parse_ratio(ratio_str: str) -> float:
    """Parse ratio like '1:16.7' or '1:15' into the water multiplier."""
    if not ratio_str:
        return 16.0
    ratio_str = str(ratio_str)
    match = re.search(r"1:(\d+\.?\d*)", ratio_str)
    return float(match.group(1)) if match else 16.0


def parse_difficulty(diff_str) -> int:
    """Parse difficulty from various formats."""
    if not diff_str:
        return 2
    diff_str = str(diff_str)
    match = re.search(r"(\d)", diff_str)
    return min(5, max(1, int(match.group(1)))) if match else 2


# Map method categories to SF Symbol icon names
CATEGORY_ICONS = {
    "pour over": "drop.fill",
    "immersion": "cup.and.saucer.fill",
    "pressure": "gauge.with.dots.needle.bottom.50percent",
    "pressure/hybrid": "gauge.with.dots.needle.bottom.50percent",
    "immersion/hybrid": "cup.and.saucer.fill",
    "boiled/unfiltered": "flame.fill",
    "boiled/immersion": "flame.fill",
    "vacuum/siphon": "bubbles.and.sparkles.fill",
    "drip/gravity": "drop.degreesign.fill",
    "percolation": "arrow.up.arrow.down.circle.fill",
    "pressure/automated": "gearshape.fill",
    "cold brew": "snowflake",
    "cold drip": "snowflake",
}

# Method name to device category mapping
DEVICE_CATEGORIES = {
    "v60": "v60-pour-over",
    "french press": "french-press",
    "aeropress": "aeropress",
    "chemex": "chemex",
    "kalita": "kalita-wave",
    "moka pot": "moka-pot",
    "espresso": "espresso",
    "turkish": "turkish-coffee",
    "cold brew": "cold-brew",
    "clever": "clever-dripper",
    "siphon": "siphon",
    "nel drip": "nel-drip",
    "vietnamese": "vietnamese-phin",
    "japanese iced": "japanese-iced",
    "drip coffee": "drip-machine",
    "percolator": "percolator",
    "cupping": "cupping",
    "south indian": "south-indian-filter",
    "kyoto": "kyoto-cold-drip",
    "cowboy": "cowboy-coffee",
    "kopi tubruk": "kopi-tubruk",
    "hario switch": "hario-switch",
    "neapolitan": "neapolitan-flip",
    "single serve": "single-serve-pod",
    "nitro": "nitro-cold-brew",
    "scott rao": "v60-pour-over",
    "melitta": "melitta-pour-over",
    "osmotic": "v60-pour-over",
}


def get_method_id(method_name: str) -> str:
    """Map a technique name to its parent method ID."""
    name_lower = method_name.lower()
    for key, method_id in DEVICE_CATEGORIES.items():
        if key in name_lower:
            return method_id
    return slugify(method_name)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 excel_to_json.py <path_to_excel_file>")
        sys.exit(1)

    excel_path = sys.argv[1]
    if not os.path.exists(excel_path):
        print(f"ERROR: File not found: {excel_path}")
        sys.exit(1)

    # Output directory
    script_dir = Path(__file__).parent.parent
    output_dir = script_dir / "Coffeebrew" / "Resources" / "Data"
    output_dir.mkdir(parents=True, exist_ok=True)

    wb = openpyxl.load_workbook(excel_path)

    # ── 1. Parse Methods Master sheet ──
    ws_methods = wb["Brewing Methods Master"]
    raw_techniques = []

    for row in ws_methods.iter_rows(min_row=4, max_row=ws_methods.max_row, values_only=True):
        name = row[0]
        if not name or not isinstance(name, str):
            continue

        category = str(row[1] or "")
        device = str(row[4] or "")
        grind = str(row[5] or "")
        coffee_dose = str(row[6] or "")
        water_amount = str(row[7] or "")
        ratio = str(row[8] or "")
        temp = str(row[9] or "")
        total_time = str(row[11] or "")
        difficulty = row[14]

        method_id = get_method_id(name)
        technique_id = slugify(name)

        raw_techniques.append({
            "name": name,
            "category": category,
            "device": device,
            "grind": grind,
            "coffee_dose": coffee_dose,
            "water_amount": water_amount,
            "ratio_str": ratio,
            "temp_str": temp,
            "total_time_str": total_time,
            "difficulty": difficulty,
            "method_id": method_id,
            "technique_id": technique_id,
        })

    # ── 2. Build unique Methods ──
    methods_dict = {}
    for t in raw_techniques:
        mid = t["method_id"]
        if mid not in methods_dict:
            cat = t["category"].lower()
            icon = CATEGORY_ICONS.get(cat, "cup.and.saucer.fill")
            # Derive a clean method name from the ID
            method_name = mid.replace("-", " ").title()
            methods_dict[mid] = {
                "method_id": mid,
                "name": method_name,
                "description": f"Explore {method_name} brewing techniques.",
                "difficulty": parse_difficulty(t["difficulty"]),
                "icon_name": icon,
                "image_name": None,
            }

    methods = sorted(methods_dict.values(), key=lambda m: m["method_id"])

    # ── 3. Build Techniques ──
    techniques = []
    technique_order = {}  # method_id -> count
    for t in raw_techniques:
        mid = t["method_id"]
        technique_order[mid] = technique_order.get(mid, 0) + 1

        techniques.append({
            "technique_id": t["technique_id"],
            "method_id": mid,
            "name": t["name"],
            "description": f"{t['device']}. Grind: {t['grind']}.",
            "total_time_seconds": parse_time_to_seconds(t["total_time_str"]),
            "water_temp_c": parse_temp(t["temp_str"]),
            "ratio_water_coffee": parse_ratio(t["ratio_str"]),
            "grind_size_label": t["grind"],
            "grind_size_ref": None,
            "step_count": 0,  # Will be updated after parsing steps
            "sort_order": technique_order[mid],
        })

    technique_ids = {t["technique_id"] for t in techniques}

    def match_technique_id(header_name: str) -> str:
        """Fuzzy-match a step sheet header to a known technique_id."""
        slug = slugify(header_name)
        if slug in technique_ids:
            return slug
        # Try removing common suffixes like "technique", "method"
        for suffix in ["-technique", "-method", "-recipe"]:
            candidate = slug.rstrip(suffix) if slug.endswith(suffix) else slug
            if candidate in technique_ids:
                return candidate
        # Try prefix matching
        best = None
        best_len = 0
        for tid in technique_ids:
            # Check if one contains the other
            if tid in slug or slug in tid:
                if len(tid) > best_len:
                    best = tid
                    best_len = len(tid)
        if best:
            return best
        # Fallback: find best overlap
        slug_words = set(slug.split("-"))
        best_score = 0
        for tid in technique_ids:
            tid_words = set(tid.split("-"))
            overlap = len(slug_words & tid_words)
            if overlap > best_score:
                best_score = overlap
                best = tid
        return best or slug

    # ── 4. Parse Steps ──
    ws_steps = wb["Step-by-Step Recipes"]
    all_steps = []
    current_technique_name = None
    current_technique_id = None
    step_counter = 0

    for row in ws_steps.iter_rows(min_row=1, max_row=ws_steps.max_row, values_only=True):
        col0 = row[0]
        col1 = row[1] if len(row) > 1 else None
        col2 = row[2] if len(row) > 2 else None

        if col0 is None and col1 is None and col2 is None:
            continue

        # Detect technique header rows (non-numeric col0, has summary in col2)
        if (isinstance(col0, str) and col0 not in ("Step", "#", "💡")
                and col2 and "/" in str(col2) and ("coffee" in str(col2).lower() or "g" in str(col2).lower())):
            current_technique_name = col0.strip()
            current_technique_id = match_technique_id(current_technique_name)
            step_counter = 0
            continue

        # Skip header rows
        if col0 in ("Step", "#"):
            continue

        # Skip note rows
        if col0 == "💡":
            continue

        # Parse actual step rows (numeric step number or "Prep"/"Step X"/"Done" labels)
        if current_technique_id and col2:
            is_numeric = isinstance(col0, int) or (isinstance(col0, str) and col0.isdigit())
            is_label = isinstance(col0, str) and col0 in ("Prep", "Done")
            is_step_label = isinstance(col0, str) and col0.startswith("Step")

            if is_numeric or is_label or is_step_label:
                step_counter += 1
                if is_numeric:
                    step_num = int(col0) if isinstance(col0, int) else int(col0)
                else:
                    step_num = step_counter

                time_label = str(col1 or "")
                instruction = str(col2)

                # Parse duration from time label
                duration = 0
                time_match = re.match(r"(\d+):(\d+)", time_label)
                if time_match:
                    duration = int(time_match.group(1)) * 60 + int(time_match.group(2))

                step_id = f"{current_technique_id}-step-{step_num}"
                all_steps.append({
                    "step_id": step_id,
                    "technique_id": current_technique_id,
                    "step_number": step_num,
                    "title": time_label if time_label else f"Step {step_num}",
                    "instruction": instruction,
                    "duration_seconds": duration,
                    "water_volume_ml_base": 0.0,
                    "image_name": None,
                })

    # Update step counts on techniques
    step_counts = {}
    for s in all_steps:
        tid = s["technique_id"]
        step_counts[tid] = step_counts.get(tid, 0) + 1

    for t in techniques:
        t["step_count"] = step_counts.get(t["technique_id"], 0)

    # ── 5. Generate Beans (synthetic from technique data) ──
    beans = []
    bean_templates = [
        {"origin": "Ethiopia Yirgacheffe", "process": "Washed", "roast_level": "Light",
         "flavour_notes": "Floral, Bergamot, Stone Fruit"},
        {"origin": "Colombia Huila", "process": "Washed", "roast_level": "Medium",
         "flavour_notes": "Caramel, Red Apple, Milk Chocolate"},
        {"origin": "Kenya AA Nyeri", "process": "Washed", "roast_level": "Light-Medium",
         "flavour_notes": "Blackcurrant, Grapefruit, Brown Sugar"},
        {"origin": "Guatemala Antigua", "process": "Washed", "roast_level": "Medium",
         "flavour_notes": "Chocolate, Hazelnut, Orange Zest"},
        {"origin": "Brazil Cerrado", "process": "Natural", "roast_level": "Medium-Dark",
         "flavour_notes": "Nutty, Chocolate, Low Acidity"},
        {"origin": "Sumatra Mandheling", "process": "Wet-Hulled", "roast_level": "Dark",
         "flavour_notes": "Earthy, Spicy, Full Body, Cedar"},
        {"origin": "Costa Rica Tarrazu", "process": "Honey", "roast_level": "Medium",
         "flavour_notes": "Honey, Peach, Bright Acidity"},
        {"origin": "Rwanda Nyamasheke", "process": "Washed", "roast_level": "Light",
         "flavour_notes": "Tea-like, Red Berry, Citrus"},
    ]

    bean_idx = 0
    for t in techniques:
        tid = t["technique_id"]
        for i in range(2):  # 2 beans per technique
            template = bean_templates[(bean_idx + i) % len(bean_templates)]
            bean_id = f"{tid}-bean-{i + 1}"
            beans.append({
                "bean_id": bean_id,
                "technique_id": tid,
                "name": f"{template['origin']} ({template['roast_level']})",
                "origin": template["origin"],
                "process": template["process"],
                "roast_level": template["roast_level"],
                "flavour_notes": [n.strip() for n in template["flavour_notes"].split(",")],
                "match_score": 90 - (i * 10),
                "notes": None,
            })
        bean_idx += 2

    # ── 6. Write JSON files ──
    def write_json(filename, data):
        path = output_dir / filename
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  Wrote {len(data)} records to {path}")

    print(f"\nExporting to {output_dir}/\n")
    write_json("methods.json", methods)
    write_json("techniques.json", techniques)
    write_json("steps.json", all_steps)
    write_json("beans.json", beans)

    print(f"\nDone! {len(methods)} methods, {len(techniques)} techniques, "
          f"{len(all_steps)} steps, {len(beans)} beans.")


if __name__ == "__main__":
    main()
