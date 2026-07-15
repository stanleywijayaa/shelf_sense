import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final List<String> usesItems;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.usesItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const _DetailHeader(title: 'Recipe details'),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + meta ─────────────────────────────────────────────
            Text(
              recipe.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              recipe.description,
              style: const TextStyle(fontSize: 14, color: Color(0xFF868E96), height: 1.4),
            ),
            const SizedBox(height: 12),
            // ── Info chips: time · ingredients · steps ───────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.schedule,
                  label: '${recipe.prepMinutes} min',
                ),
                _InfoChip(
                  icon: Icons.format_list_bulleted,
                  label:
                      '${recipe.ingredients.length} ingredient${recipe.ingredients.length == 1 ? '' : 's'}',
                ),
                _InfoChip(
                  icon: Icons.restaurant_menu,
                  label:
                      '${recipe.steps.length} step${recipe.steps.length == 1 ? '' : 's'}',
                ),
              ],
            ),

            // ── "Uses your at-risk items" banner ─────────────────────────
            if (usesItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Helps use up:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3A7D44),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usesItems.join(', '),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF2E5C34)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Ingredients ──────────────────────────────────────────────
            _SectionTitle('Ingredients'),
            const SizedBox(height: 10),
            ...recipe.ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 10),
                        child: Icon(Icons.circle, size: 6, color: Color(0xFF3A7D44)),
                      ),
                      Expanded(
                        child: Text(
                          ing,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF343A40), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            // ── Steps ────────────────────────────────────────────────────
            _SectionTitle('Steps'),
            const SizedBox(height: 10),
            ...List.generate(recipe.steps.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A7D44),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            recipe.steps[i],
                            style: const TextStyle(fontSize: 14, color: Color(0xFF343A40), height: 1.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}

// ─── Curved detail header (shared style with the tab screens) ─────────────
class _DetailHeader extends StatelessWidget {
  final String title;

  const _DetailHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(6, topPadding + 8, 18, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF3A7D44),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small tinted info chip (time / ingredients / steps) ──────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2E5C34)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E5C34),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1C1C1E),
      ),
    );
  }
}