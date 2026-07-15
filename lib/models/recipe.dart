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

  /// Converts this recipe into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ingredientKeywords': ingredientKeywords,
      'categories': categories,
      'ingredients': ingredients,
      'steps': steps,
      'prepMinutes': prepMinutes,
    };
  }

  /// Builds a Recipe from a Firestore document.
  factory Recipe.fromMap(String id, Map<String, dynamic> map) {
    return Recipe(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ingredientKeywords: List<String>.from(map['ingredientKeywords'] ?? []),
      categories: List<String>.from(map['categories'] ?? []),
      ingredients: List<String>.from(map['ingredients'] ?? []),
      steps: List<String>.from(map['steps'] ?? []),
      prepMinutes: map['prepMinutes'] ?? 30,
    );
  }
}