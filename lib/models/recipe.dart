/// A simple recipe used for suggesting ways to use up at-risk food items.
///
/// Each recipe is tagged with both the specific ingredient NAMES it uses
/// and the CATEGORIES those ingredients fall under. This supports the
/// two-tier matching in RecipeService: match by ingredient name first
/// (precise), then fall back to category (reliable).
class Recipe {
  final String id;
  final String name;
  final String description;
 
  /// Ingredient names this recipe uses, lowercased for easy matching
  /// (e.g. ["chicken", "garlic", "rice"]).
  final List<String> ingredientKeywords;
 
  /// Categories this recipe draws from (must match the app's category
  /// values, e.g. "Meat", "Dairy", "Produce").
  final List<String> categories;
 
  /// Full ingredient list shown on the detail screen.
  final List<String> ingredients;
 
  /// Ordered preparation steps shown on the detail screen.
  final List<String> steps;
 
  final int prepMinutes;
 
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredientKeywords,
    required this.categories,
    required this.ingredients,
    required this.steps,
    required this.prepMinutes,
  });
}