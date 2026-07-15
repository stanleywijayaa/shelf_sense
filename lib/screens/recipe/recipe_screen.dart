import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import '../../services/firestore_service.dart';
import '../../services/recipe_service.dart';
import 'recipe_detail_screen.dart';
import '../../core/theme/app_shadows.dart';

class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<List<FoodItem>>(
        stream: FirestoreService().getFoodItems(),
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting;
          final items = snapshot.data ?? [];
          final recipes = RecipeService.suggestRecipes(items);

          return Column(
            children: [
              _RecipeHeader(suggestionCount: recipes.length),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3A7D44)),
                      )
                    : _buildBody(context, items, recipes),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<FoodItem> items, List<Recipe> recipes) {

          // ── No at-risk items / no matches ────────────────────────────
          if (recipes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu_outlined, size: 56, color: Color(0xFFCED4DA)),
                    const SizedBox(height: 16),
                    const Text(
                      'No recipe suggestions yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF495057),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'When you have items at medium or high\nspoilage risk, recipes to use them up\nwill appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF868E96), height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Matched recipes ──────────────────────────────────────────
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4, left: 2),
                child: Text(
                  'Suggested for your at-risk items',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF868E96),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...recipes.map((recipe) {
                final uses = RecipeService.matchedItemNames(recipe, items);
                return _RecipeCard(
                  recipe: recipe,
                  usesItems: uses,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: recipe,
                        usesItems: uses,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
  }
}

// ─── Curved recipes header ────────────────────────────────────────────────
class _RecipeHeader extends StatelessWidget {
  final int suggestionCount;
  const _RecipeHeader({required this.suggestionCount});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 16, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF3A7D44),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recipes',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  suggestionCount == 0
                      ? 'Nothing at risk right now'
                      : '$suggestionCount suggestion${suggestionCount == 1 ? '' : 's'} for your at-risk items',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFCDE3D2),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0x29FFFFFF), // white at ~16% opacity
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_menu,
              size: 17,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final List<String> usesItems;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.usesItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF868E96)),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.prepMinutes}m',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF868E96)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                recipe.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF868E96), height: 1.35),
              ),
              if (usesItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: usesItems.map((name) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3A7D44),
                          ),
                        ),
                      )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}