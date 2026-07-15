import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/risk_badge.dart';
import 'add_item_screen.dart';
import '../../core/theme/app_shadows.dart';

class ItemDetailScreen extends StatelessWidget {
  final FoodItem item;

  const ItemDetailScreen({super.key, required this.item});

  String get _expiryStatusLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day,
    );
    final daysLeft = expiry.difference(today).inDays;

    if (daysLeft < 0) return 'Expired ${daysLeft.abs()} day${daysLeft.abs() == 1 ? '' : 's'} ago';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return '1 day remaining';
    return '$daysLeft days remaining';
  }

  IconData get _storageIcon {
    switch (item.storageType) {
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove item?'),
        content: Text('"${item.name}" will be removed from your inventory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirestoreService().deleteFoodItem(item.id);
      if (context.mounted) {
        Navigator.pop(context); // back to inventory list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        title: const Text(
          'Item Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit item',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddItemScreen(existingItem: item),
                ),
              ).then((_) {
                // After editing, pop back to the inventory list so it
                // reflects the change. The detail screen itself was built
                // as a StatelessWidget holding a snapshot of `item`, so it
                // can't refresh in place — returning to the list (whose
                // StreamBuilder is always live) is the simplest fix.
                if (context.mounted) Navigator.pop(context);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete item',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card: icon, name, category/storage, risk badge ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _storageIcon,
                          color: const Color(0xFF3A7D44),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.category} · ${item.storageType}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF868E96),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RiskBadge(riskLevel: item.riskLevel),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFF495057)),
                        const SizedBox(width: 8),
                        Text(
                          _expiryStatusLabel,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF495057),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Detail rows ──────────────────────────────────────────────
            _DetailRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Purchase Date',
              value: DateFormat('dd MMM yyyy').format(item.purchaseDate),
            ),
            _DetailRow(
              icon: Icons.event_busy_outlined,
              label: 'Expiry Date',
              value: DateFormat('dd MMM yyyy').format(item.expiryDate),
            ),
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: item.category,
            ),
            _DetailRow(
              icon: Icons.shelves,
              label: 'Storage Location',
              value: item.storageType,
            ),
            _DetailRow(
              icon: Icons.warning_amber_outlined,
              label: 'Spoilage Risk',
              value: item.riskLevel,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEDEFF1)),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF868E96)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF868E96),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}