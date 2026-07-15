import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/food_item_card.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Currently selected storage filter. "All" shows everything.
  String _selectedFilter = 'All';
  static const List<String> _filters = ['All', 'Fridge', 'Freezer', 'Pantry'];

  Future<void> _confirmDelete(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text('Remove item?'),
        content: Text('"${item.name}" will be removed from your inventory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestoreService.deleteFoodItem(item.id);
      if (mounted) {
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
          'My Inventory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Storage filter chips ─────────────────────────────────────
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF495057),
                      ),
                      selectedColor: const Color(0xFF3A7D44),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF3A7D44)
                            : const Color(0xFFDEE2E6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Item list ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<FoodItem>>(
              stream: _firestoreService.getFoodItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3A7D44)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Something went wrong loading your inventory.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF868E96)),
                      ),
                    ),
                  );
                }

                final allItems = snapshot.data ?? [];

                // Apply the storage filter.
                final items = _selectedFilter == 'All'
                    ? allItems
                    : allItems
                        .where((i) => i.storageType == _selectedFilter)
                        .toList();

                // ── Empty states ─────────────────────────────────────
                if (allItems.isEmpty) {
                  return _EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Your inventory is empty',
                    subtitle: 'Tap the + button to add your first food item.',
                  );
                }

                if (items.isEmpty) {
                  // Inventory has items, but none in this storage filter.
                  return _EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Nothing in $_selectedFilter',
                    subtitle: 'You have no items stored in the $_selectedFilter.',
                  );
                }

                // ── Populated list ───────────────────────────────────
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return FoodItemCard(
                      item: item,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailScreen(item: item),
                          ),
                        );
                      },
                      onDelete: () => _confirmDelete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable empty-state widget for both the "no items" and
/// "nothing in this storage" cases.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFCED4DA)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF495057),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF868E96),
              ),
            ),
          ],
        ),
      ),
    );
  }
}