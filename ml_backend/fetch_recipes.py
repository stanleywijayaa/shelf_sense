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

import urllib.request
import json
import time

API_BASE = "https://www.themealdb.com/api/json/v1/1"
TARGET_COUNT = 200
OUTPUT_PATH = "recipe_database.dart"

# ── Map TheMealDB categories -> ShelfSense categories ────────────────────
# TheMealDB categorizes by type/cuisine; we translate to the app's scheme.
# Anything unmapped falls back to keyword-based tagging (see tag_categories).
MEALDB_CATEGORY_MAP = {
    "Beef": "Meat",
    "Chicken": "Meat",
    "Pork": "Meat",
    "Lamb": "Meat",
    "Goat": "Meat",
    "Seafood": "Seafood",
    "Vegetarian": "Produce",
    "Vegan": "Produce",
    "Breakfast": "Ready_to_Eat",
    "Side": "Ready_to_Eat",
    "Starter": "Ready_to_Eat",
    "Miscellaneous": "Ready_to_Eat",
    "Pasta": "Ready_to_Eat",
    "Dessert": "Bakery",
}

# Keyword -> ShelfSense category, for enriching tags from ingredients.
KEYWORD_CATEGORY = {
    "milk": "Dairy", "cheese": "Dairy", "cream": "Dairy", "butter": "Dairy",
    "yogurt": "Dairy", "yoghurt": "Dairy",
    "chicken": "Meat", "beef": "Meat", "pork": "Meat", "lamb": "Meat",
    "bacon": "Meat", "sausage": "Meat", "ham": "Deli",
    "fish": "Seafood", "salmon": "Seafood", "prawn": "Seafood",
    "shrimp": "Seafood", "tuna": "Seafood", "cod": "Seafood",
    "bread": "Bakery", "flour": "Bakery", "dough": "Bakery",
    "juice": "Beverages", "wine": "Beverages",
}

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
            if token in kw:
                cats.add(cat)
    # Fallback so every recipe has at least one category
    if not cats:
        cats.add("Ready_to_Eat")
    return sorted(cats)


def split_steps(instructions):
    """Break the instruction blob into individual steps."""
    if not instructions:
        return []
    raw = instructions.replace("\r\n", "\n")
    # Split on newlines or numbered markers; keep non-empty trimmed lines.
    parts = [p.strip() for p in raw.split("\n") if p.strip()]
    # Some entries are one long paragraph — fall back to sentence-ish split.
    if len(parts) <= 1:
        parts = [s.strip() + "." for s in raw.split(". ") if s.strip()]
    return parts


def dart_escape(text):
    return text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ").strip()


def main():
    seen = set()
    recipes = []

    for category in FETCH_CATEGORIES:
        if len(recipes) >= TARGET_COUNT:
            break
        try:
            ids = list_meals_in_category(category)
        except Exception as e:
            print(f"  (skipping {category}: {e})")
            continue

        for meal_id in ids:
            if len(recipes) >= TARGET_COUNT:
                break
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
            print(f"  [{len(recipes):2d}] {meal['strMeal']}  -> {cats}")

    print(f"\nCollected {len(recipes)} recipes. Writing {OUTPUT_PATH} ...")
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