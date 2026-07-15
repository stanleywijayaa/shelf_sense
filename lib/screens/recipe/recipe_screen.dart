import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import '../../services/firestore_service.dart';
import '../../services/recipe_service.dart';
import '../../services/recipe_repository.dart';
import '../../core/theme/app_shadows.dart';
import 'recipe_detail_screen.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showAll = false;
  Timer? _debounce;

  /// Recipes loaded via the hybrid repository (cache -> server -> bundled).
  List<Recipe> _allRecipes = [];
  bool _recipesLoading = true;
  bool _refreshing = false;

  /// How many suggestions to show before "Show more".
  static const int _topCount = 10;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final recipes = await RecipeRepository.loadRecipes();
    if (mounted) {
      setState(() {
        _allRecipes = recipes;
        _recipesLoading = false;
      });
    }
  }

  /// Force-refresh from Firestore (requires internet). Once fetched,
  /// Firestore's persistence caches the data for offline use.
  Future<void> _refreshRecipes() async {
    setState(() => _refreshing = true);
    try {
      final recipes = await RecipeRepository.refreshFromServer();
      if (mounted) {
        setState(() => _allRecipes = recipes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipes updated (${recipes.length} available).'),
            backgroundColor: const Color(0xFF3A7D44),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Couldn\'t refresh — check your internet connection.'),
            backgroundColor: Color(0xFFE63946),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Waits until the user pauses typing (400ms) before applying the search.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<List<FoodItem>>(
        stream: FirestoreService().getFoodItems(),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState ==
                  ConnectionState.waiting ||
              _recipesLoading;
          final items = snapshot.data ?? [];
          final suggested = _recipesLoading
              ? <Recipe>[]
              : RecipeService.suggestRecipes(items, _allRecipes);

          return Column(
            children: [
              _RecipeHeader(
                suggestionCount: suggested.length,
                refreshing: _refreshing,
                onRefresh: _refreshing ? null : _refreshRecipes,
              ),

              // Search sits OUTSIDE the rebuilt results area so the
              // TextField is never recreated when results change —
              // this is what preserves focus while typing.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: _searchField(),
              ),

              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3A7D44)),
                      )
                    : _buildBody(context, items, suggested),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<FoodItem> items, List<Recipe> allSuggested) {
    // Search filter — contains matching on the recipe NAME only, so the
    // query can sit anywhere in the name and every result visibly
    // relates to what was typed.
    final q = _query.trim().toLowerCase();
    final searched = q.isEmpty
        ? allSuggested
        : allSuggested
            .where((r) => r.name.toLowerCase().contains(q))
            .toList();

    // Cap to the top matches unless expanded or searching.
    final capped = _showAll || q.isNotEmpty
        ? searched
        : searched.take(_topCount).toList();
    final hiddenCount = searched.length - capped.length;
    final recipes = capped;

    // ── No search results ─────────────────────────────────────────────
    if (recipes.isEmpty && q.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
        children: const [
          Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: Color(0xFFCED4DA)),
                SizedBox(height: 12),
                Text(
                  'No recipe found with that name',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── No at-risk items / no matches ─────────────────────────────────
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.restaurant_menu_outlined,
                  size: 56, color: Color(0xFFCED4DA)),
              SizedBox(height: 16),
              Text(
                'No recipe suggestions yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF495057),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'When you have items at medium or high\nspoilage risk, recipes to use them up\nwill appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF868E96),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Matched recipes ────────────────────────────────────────────────
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Text(
            q.isEmpty
                ? 'Top suggestions for your at-risk items'
                : 'Search results',
            style: const TextStyle(
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

        // ── Show more (only when results are capped) ───────────────────
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.expand_more,
                    size: 18, color: Color(0xFF3A7D44)),
                label: Text(
                  'Show $hiddenCount more',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A7D44),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Rounded search field used at the top of the recipe list.
  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search recipes',
          hintStyle:
              const TextStyle(fontSize: 13.5, color: Color(0xFFADB5BD)),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: Color(0xFF868E96)),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: Color(0xFF868E96)),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

// ─── Curved recipes header ────────────────────────────────────────────────
class _RecipeHeader extends StatelessWidget {
  final int suggestionCount;
  final bool refreshing;
  final VoidCallback? onRefresh;

  const _RecipeHeader({
    required this.suggestionCount,
    required this.refreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 16, 12, 18),
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
          // ── Refresh recipes (requires internet) ────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0x29FFFFFF), // white at ~16% opacity
              shape: BoxShape.circle,
            ),
            child: refreshing
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Refresh recipes',
                    icon: const Icon(
                      Icons.refresh,
                      size: 19,
                      color: Colors.white,
                    ),
                    onPressed: onRefresh,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Recipe card ──────────────────────────────────────────────────────────
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
                      const Icon(Icons.schedule,
                          size: 14, color: Color(0xFF868E96)),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.prepMinutes}m',
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF868E96)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                recipe.description,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF868E96), height: 1.35),
              ),
              if (usesItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: usesItems
                      .map((name) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
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
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}