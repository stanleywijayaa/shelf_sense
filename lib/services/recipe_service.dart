import '../models/food_item.dart';
import '../models/recipe.dart';

/// Matches recipes to the user's at-risk food items.
///
/// Matching strategy (two-tier):
///   1. NAME match (precise) — if a recipe's ingredient keywords appear in
///      the item's free-text name (e.g. item "Chicken Breast" -> keyword
///      "chicken"), it's a strong match.
///   2. CATEGORY match (reliable fallback) — otherwise, if the recipe uses
///      the item's category (e.g. "Meat"), it still matches.
///
/// This gives precise suggestions when the item name is clean, while always
/// returning something sensible even when names are messy or unusual.
class RecipeService {
  /// Given the current inventory, return recipes that help use up the
  /// items most at risk (High, then Medium). Recipes are ranked by how
  /// many at-risk items they help use.
  static List<Recipe> suggestRecipes(
      List<FoodItem> items, List<Recipe> allRecipes) {
    // Focus on items that actually need using up.
    final atRisk = items
        .where((i) => i.riskLevel == 'High' || i.riskLevel == 'Medium')
        .toList();

    if (atRisk.isEmpty) return [];

    // Score each recipe by how many at-risk items it can use.
    final Map<String, int> scores = {};

    for (final recipe in allRecipes) {
      int score = 0;
      for (final item in atRisk) {
        if (_recipeMatchesItem(recipe, item)) {
          // High-risk items weigh more than medium.
          score += item.riskLevel == 'High' ? 2 : 1;
        }
      }
      if (score > 0) {
        scores[recipe.id] = score;
      }
    }

    // Return matched recipes, highest score first.
    final matched = allRecipes
        .where((r) => scores.containsKey(r.id))
        .toList()
      ..sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));

    return matched;
  }

  /// True if the recipe matches the item by name (preferred) or category.
  static bool _recipeMatchesItem(Recipe recipe, FoodItem item) {
    final itemName = item.name.toLowerCase();

    // ── Tier 1: name match ──────────────────────────────────────────────
    for (final keyword in recipe.ingredientKeywords) {
      if (itemName.contains(keyword)) {
        return true;
      }
    }

    // ── Tier 2: category fallback ───────────────────────────────────────
    if (recipe.categories.contains(item.category)) {
      return true;
    }

    return false;
  }

  /// Returns the at-risk item names a given recipe helps use up — so the UI
  /// can show "Uses: Chicken Breast, Milk".
  static List<String> matchedItemNames(Recipe recipe, List<FoodItem> items) {
    final atRisk = items
        .where((i) => i.riskLevel == 'High' || i.riskLevel == 'Medium')
        .toList();
    return atRisk
        .where((item) => _recipeMatchesItem(recipe, item))
        .map((item) => item.name)
        .toList();
  }
}