import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../core/constants/food_categories.dart';
import '../core/theme/app_shadows.dart';
import 'risk_badge.dart';

/// A single row card representing one food item in the inventory list.
class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FoodItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  /// Returns a human-readable countdown string, e.g. "3 days left".
  String get _expiryLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day,
    );
    final daysLeft = expiry.difference(today).inDays;

    if (daysLeft < 0) return 'Expired';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  /// Colour of the left edge strip — makes urgency scannable before reading.
  Color get _edgeColor {
    switch (item.riskLevel) {
      case 'High':
        return const Color(0xFFC62828);
      case 'Medium':
        return const Color(0xFFBA7517);
      case 'Low':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFFCED4DA);
    }
  }

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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Risk edge strip ──────────────────────────────────────
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _edgeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _storageIcon(item.storageType),
                          color: const Color(0xFF3A7D44),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${FoodCategories.label(item.category)} · ${item.storageType}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF868E96),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _expiryLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: _expiryLabel == 'Expired'
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF495057),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RiskBadge(riskLevel: item.riskLevel),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Color(0xFFADB5BD),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _storageIcon(String storageType) {
    switch (storageType) {
      case 'Fridge':
        return Icons.kitchen_outlined;
      case 'Freezer':
        return Icons.ac_unit;
      case 'Pantry':
        return Icons.shelves;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}