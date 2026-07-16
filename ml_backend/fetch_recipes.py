"""
TheMealDB Recipe Extractor for ShelfSense
─────────────────────────────────────────────────────────────────────────
One-time script: fetches recipes from TheMealDB's free API, transforms them
into the app's Recipe format, maps their categories to ShelfSense's nine
categories, and writes a ready-to-use lib/data/recipe_database.dart.

Run on YOUR machine (needs open internet):
    python fetch_recipes.py

Recipe data provided by TheMealDB (https://www.themealdb.com) — free test
key '1' for educational/development use. Remember to attribute in your app
and report.

No external packages needed — uses only the Python standard library.
"""

import re
import urllib.request
import json
import time

API_BASE = "https://www.themealdb.com/api/json/v1/1"
TARGET_COUNT = 250
OUTPUT_PATH = "recipe_database.dart"

# ── Map TheMealDB categories -> ShelfSense categories ────────────────────
# TheMealDB categorizes by type/cuisine; we translate to the app's scheme.
#
# DELIBERATE EXCLUSIONS: recipes are never tagged Frozen_Meals, Beverages,
# or Ready_to_Eat. Those item types are consumed directly rather than cooked
# into recipes, so a category-level match against them would be meaningless
# (e.g. suggesting a pasta bake "uses up" your soft drink). Items in those
# categories can still match recipes by NAME, which stays precise.
MEALDB_CATEGORY_MAP = {
    "Beef": "Meat",
    "Chicken": "Meat",
    "Pork": "Meat",
    "Lamb": "Meat",
    "Goat": "Meat",
    "Seafood": "Seafood",
    "Vegetarian": "Produce",
    "Vegan": "Produce",
    "Dessert": "Bakery",
}

# Keyword -> ShelfSense category, for enriching tags from ingredients.
# (Beverage keywords removed — see exclusion note above.)
KEYWORD_CATEGORY = {
    "milk": "Dairy", "cheese": "Dairy", "cream": "Dairy", "butter": "Dairy",
    "yogurt": "Dairy", "yoghurt": "Dairy",
    "chicken": "Meat", "beef": "Meat", "pork": "Meat", "lamb": "Meat",
    "bacon": "Meat", "sausage": "Meat", "ham": "Deli",
    "fish": "Seafood", "salmon": "Seafood", "prawn": "Seafood",
    "shrimp": "Seafood", "tuna": "Seafood", "cod": "Seafood",
    "bread": "Bakery", "flour": "Bakery", "dough": "Bakery",
}

# Plant-based "milks" and creams are NOT dairy — without this exclusion,
# "coconut milk" substring-matches the "milk" keyword and falsely tags
# a curry as a Dairy recipe.
_NON_DAIRY_PREFIXES = (
    "coconut", "almond", "soy", "soya", "oat", "rice", "cashew", "peanut",
)

# Stocks/broths are derived flavourings — "chicken stock" doesn't use up a
# chicken breast, so it shouldn't tag the recipe as Meat/Seafood/Deli.
_DERIVED_SUFFIXES = ("stock", "broth", "bouillon")

# Which TheMealDB categories to pull from, to get a good spread.
FETCH_CATEGORIES = [
    "Chicken", "Beef", "Seafood", "Vegetarian",
    "Pasta", "Breakfast", "Dessert", "Pork", "Lamb", "Side",
]


def safe_str(value):
    """Convert any value (including None) to a stripped string.
    TheMealDB sometimes returns null for fields like strArea/strCategory,
    which would crash a direct .strip() call."""
    if value is None:
        return ""
    return str(value).strip()


def http_get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "ShelfSense-FYP/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def list_all_categories():
    """Fetch every category name from TheMealDB so we can pull the widest
    possible set of meals (needed to approach a large target count)."""
    try:
        data = http_get_json(f"{API_BASE}/list.php?c=list")
        return [safe_str(c.get("strCategory")) for c in (data.get("meals") or [])]
    except Exception as e:
        print(f"  (couldn't list categories: {e}) — falling back to defaults")
        return list(FETCH_CATEGORIES)


def list_meals_in_category(category):
    """Return meal IDs for a given TheMealDB category."""
    data = http_get_json(f"{API_BASE}/filter.php?c={category}")
    meals = data.get("meals") or []
    return [m["idMeal"] for m in meals]


def lookup_meal(meal_id):
    data = http_get_json(f"{API_BASE}/lookup.php?i={meal_id}")
    meals = data.get("meals") or []
    return meals[0] if meals else None


def extract_ingredients(meal):
    """Pull the up-to-20 ingredient/measure pairs into clean lists."""
    ingredients = []
    keywords = []
    for i in range(1, 21):
        name = safe_str(meal.get(f"strIngredient{i}"))
        measure = safe_str(meal.get(f"strMeasure{i}"))
        if name:
            full = f"{measure} {name}".strip()
            ingredients.append(full)
            keywords.append(name.lower())
    return ingredients, keywords


def tag_categories(mealdb_category, keywords):
    """Determine ShelfSense categories from TheMealDB category + keywords."""
    cats = set()
    if mealdb_category in MEALDB_CATEGORY_MAP:
        cats.add(MEALDB_CATEGORY_MAP[mealdb_category])
    for kw in keywords:
        for token, cat in KEYWORD_CATEGORY.items():
            if token not in kw:
                continue
            # Plant-based milks/creams are not dairy (e.g. "coconut milk").
            if cat == "Dairy" and any(p in kw for p in _NON_DAIRY_PREFIXES):
                continue
            # Stocks/broths don't use up the animal itself.
            if cat in ("Meat", "Seafood", "Deli") and any(
                    s in kw for s in _DERIVED_SUFFIXES):
                continue
            cats.add(cat)
    # No fallback tag: a recipe with no mapped categories simply matches
    # by ingredient NAME only, which is precise. (Previously fell back to
    # Ready_to_Eat, which is now a deliberately untagged category.)
    return sorted(cats)


# Lines that are ONLY a step header, e.g. "STEP 1", "Step 2:", "3." — these
# duplicate the app's own step numbering and must be dropped.
_STEP_HEADER = re.compile(r"^\s*(step\s*\d+|\d+)\s*[:.)\-]?\s*$", re.IGNORECASE)
# Leading numbering stuck to a real step, e.g. "1. Preheat oven" / "Step 2: Mix".
_LEADING_NUM = re.compile(r"^\s*(step\s*\d+\s*[:.)\-]?\s*|\d+\s*[.)\-]\s+)", re.IGNORECASE)
# Section labels that sometimes appear as their own lines in the blob.
_SECTION_LABEL = re.compile(
    r"^\s*(directions?|instructions?|method|preparation|ingredients|notes?|tips?)\s*:?\s*$",
    re.IGNORECASE,
)
# Serving-size lines, e.g. "2 Servings" / "Serves 4".
_SERVINGS = re.compile(r"^\s*(\d+\s*servings?|serves\s+\d+)\s*:?\s*$", re.IGNORECASE)
# Equipment header — everything after it is a gear list, not steps, until an
# instructions-type label appears.
_EQUIPMENT = re.compile(r"^\s*equipment\s*:?\s*$", re.IGNORECASE)


def split_steps(instructions):
    """Break the instruction blob into individual steps.

    Also cleans TheMealDB quirks: standalone "STEP n" header lines are
    removed, and leading "1." / "Step 2:" numbering is stripped from steps,
    since the app renders its own step numbers."""
    if not instructions:
        return []
    raw = instructions.replace("\r\n", "\n")
    parts = [p.strip() for p in raw.split("\n") if p.strip()]
    # Some entries are one long paragraph — fall back to sentence-ish split.
    if len(parts) <= 1:
        parts = [s.strip() + "." for s in raw.split(". ") if s.strip()]
    cleaned = []
    in_equipment_block = False
    for p in parts:
        # Equipment section: skip its gear list until an instructions-type
        # label ends the block (e.g. "Equipment / Dutch Oven / Instructions").
        if _EQUIPMENT.match(p):
            in_equipment_block = True
            continue
        if in_equipment_block:
            if _SECTION_LABEL.match(p):
                in_equipment_block = False  # label itself is also dropped
            continue

        if _STEP_HEADER.match(p):
            continue  # drop lines that are only "STEP 1" / "1" etc.
        if _SECTION_LABEL.match(p):
            continue  # drop "DIRECTIONS:" / "Instructions" labels
        if _SERVINGS.match(p):
            continue  # drop "2 Servings" / "Serves 4" lines
        # Drop section-title headers like "STEP 1 - MARINATING THE CHICKEN":
        # starts with "STEP n" and the whole line is uppercase, so it's a
        # heading rather than an actual instruction.
        if re.match(r"^\s*step\s*\d+\b", p, re.IGNORECASE) and p.upper() == p:
            continue
        p = _LEADING_NUM.sub("", p).strip()
        if p:
            cleaned.append(p)
    return cleaned


def dart_escape(text):
    return text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ").strip()


def main():
    seen = set()
    recipes = []

    # Pull from EVERY category, ROUND-ROBIN rather than alphabetically.
    # Filling category-by-category would exhaust the target on the first
    # few (Beef, Breakfast, Chicken, Dessert...) and leave Seafood,
    # Vegetarian, etc. with ZERO recipes — breaking suggestions for those
    # food types. Round-robin guarantees every category is represented.
    all_categories = list_all_categories()
    print(f"Found {len(all_categories)} categories on TheMealDB.")
    print(f"Targeting up to {TARGET_COUNT} recipes — this may take a few minutes.\n")

    # Build per-category ID queues first.
    queues = {}
    for category in all_categories:
        try:
            queues[category] = list_meals_in_category(category)
            print(f"── {category}: {len(queues[category])} meals available")
        except Exception as e:
            print(f"  (skipping {category}: {e})")
    print()

    # Rotate through categories, taking one meal at a time from each.
    while len(recipes) < TARGET_COUNT and any(queues.values()):
        for category in list(queues.keys()):
            if len(recipes) >= TARGET_COUNT:
                break
            if not queues[category]:
                continue

            meal_id = queues[category].pop(0)
            if meal_id in seen:
                continue
            seen.add(meal_id)

            try:
                meal = lookup_meal(meal_id)
                time.sleep(0.15)  # be polite to the free API
            except Exception as e:
                print(f"  (lookup failed {meal_id}: {e})")
                continue
            if not meal:
                continue

            ingredients, keywords = extract_ingredients(meal)
            if not ingredients:
                continue

            cats = tag_categories(safe_str(meal.get("strCategory")), keywords)
            steps = split_steps(safe_str(meal.get("strInstructions")))
            if not steps:
                continue

            recipes.append({
                "id": f"m{meal['idMeal']}",
                "name": safe_str(meal.get("strMeal")),
                "description": f"{safe_str(meal.get('strArea'))} {safe_str(meal.get('strCategory'))} dish.".strip(),
                "ingredientKeywords": keywords,
                "categories": cats,
                "ingredients": ingredients,
                "steps": steps,
                "prepMinutes": 30,  # TheMealDB doesn't provide time; default
            })
            if len(recipes) % 10 == 0:
                print(f"     ... {len(recipes)} recipes collected so far")

    print(f"\nCollected {len(recipes)} recipes total.")

    # Report the spread across ShelfSense categories so you can confirm
    # every food type the app offers has recipes to match against.
    spread = {}
    for r in recipes:
        for c in r["categories"]:
            spread[c] = spread.get(c, 0) + 1
    print("\nShelfSense category coverage:")
    for c in sorted(spread, key=lambda k: -spread[k]):
        print(f"  {c:15s} {spread[c]}")

    if len(recipes) < TARGET_COUNT:
        print(f"\n(TheMealDB's free tier didn't have {TARGET_COUNT} unique meals — "
              f"{len(recipes)} is the full available set.)")
    print(f"\nWriting {OUTPUT_PATH} ...")
    write_dart(recipes)
    print("Done. Move recipe_database.dart into lib/data/ (replacing the old one).")


def write_dart(recipes):
    lines = []
    lines.append("import '../models/recipe.dart';")
    lines.append("")
    lines.append("/// Recipes sourced from TheMealDB (https://www.themealdb.com) and")
    lines.append("/// transformed into the app's Recipe format for offline use.")
    lines.append("/// Data provided by TheMealDB — free tier, educational use.")
    lines.append("class RecipeDatabase {")
    lines.append("  static const List<Recipe> recipes = [")

    for r in recipes:
        lines.append("    Recipe(")
        lines.append(f"      id: '{r['id']}',")
        lines.append(f"      name: '{dart_escape(r['name'])}',")
        lines.append(f"      description: '{dart_escape(r['description'])}',")
        kw = ", ".join(f"'{dart_escape(k)}'" for k in r["ingredientKeywords"])
        lines.append(f"      ingredientKeywords: [{kw}],")
        cats = ", ".join(f"'{c}'" for c in r["categories"])
        lines.append(f"      categories: [{cats}],")
        lines.append("      ingredients: [")
        for ing in r["ingredients"]:
            lines.append(f"        '{dart_escape(ing)}',")
        lines.append("      ],")
        lines.append("      steps: [")
        for st in r["steps"]:
            lines.append(f"        '{dart_escape(st)}',")
        lines.append("      ],")
        lines.append(f"      prepMinutes: {r['prepMinutes']},")
        lines.append("    ),")

    lines.append("  ];")
    lines.append("}")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()