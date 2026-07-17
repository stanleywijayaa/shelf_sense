import 'dart:math';

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

    // Return matched recipes, highest score first, with WEEKLY ROTATION
    // among equally-relevant recipes (see _weeklyTieBreak).
    final matched =
        allRecipes.where((r) => scores.containsKey(r.id)).toList();

    final tieBreak = _weeklyTieBreak(matched);
    matched.sort((a, b) {
      final byScore = scores[b.id]!.compareTo(scores[a.id]!);
      if (byScore != 0) return byScore;
      // Same relevance -> order decided by this week's seed.
      return tieBreak[a.id]!.compareTo(tieBreak[b.id]!);
    });

    return matched;
  }

  /// Categories where the category FALLBACK is disabled, because items
  /// within them are not substitutable for one another: a recipe using
  /// butter should not be suggested as "using up" your milk. Items in
  /// these categories only match on their actual name.
  static const Set<String> _nameMatchOnlyCategories = {'Dairy'};


  /// Assigns each recipe a random-but-STABLE ordering value for the current
  /// week, used only to break ties between equally-relevant recipes.
  ///
  /// WHY ROTATE RATHER THAN FETCH MORE:
  /// The recipe source (TheMealDB) contains a few hundred recipes in total,
  /// most of which are already bundled — so periodically fetching "new"
  /// recipes would exhaust the source almost immediately. Boredom is better
  /// addressed by varying WHICH of the equally-suitable recipes surface.
  ///
  /// The seed is the ISO week number, so:
  ///   * the order is identical for every call within a week (no reshuffling
  ///     while the user scrolls, and no need to persist anything), and
  ///   * it changes automatically when the week rolls over.
  /// Relevance ranking is never violated: a recipe that matches more at-risk
  /// items always outranks one that matches fewer, regardless of the seed.
  static Map<String, int> _weeklyTieBreak(List<Recipe> recipes) {
    final weekSeed =
        DateTime.now().difference(DateTime(2020, 1, 1)).inDays ~/ 7;
    final rng = Random(weekSeed);
    // Sort by id first so the input order can't affect the result — the
    // seed alone determines the rotation.
    final ids = recipes.map((r) => r.id).toList()..sort();
    return {for (final id in ids) id: rng.nextInt(1 << 30)};
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
    // Skipped for non-substitutable categories (see above).
    if (_nameMatchOnlyCategories.contains(item.category)) {
      return false;
    }
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