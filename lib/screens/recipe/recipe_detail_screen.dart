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
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        title: const Text('Recipe', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Color(0xFF3A7D44)),
                const SizedBox(width: 6),
                Text(
                  '${recipe.prepMinutes} min',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A7D44),
                  ),
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