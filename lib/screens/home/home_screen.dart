import 'package:flutter/material.dart';
//import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/risk_badge.dart';
import '../inventory/item_detail_screen.dart';
 
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
 
  // ─── Derived lists from the full inventory ─────────────────────────────────
 
  /// Items expiring within the next 3 days (any risk level).
  List<FoodItem> _expiringSoon(List<FoodItem> items) {
    final cutoff = DateTime.now().add(const Duration(days: 3));
    return items
        .where((item) => item.expiryDate.isBefore(cutoff))
        .toList();
  }
 
  /// Items classified as High or Medium risk, ordered soonest-expiry first.
  /// Capped at 5 for the "Requiring Attention" section.
  List<FoodItem> _requiresAttention(List<FoodItem> items) {
    return items
        .where((item) =>
            item.riskLevel == 'High' || item.riskLevel == 'Medium')
        .take(5)
        .toList();
  }
 
  /// Full inventory ordered by soonest expiry — the consumption priority queue.
  /// Capped at 5 for the dashboard section.
  List<FoodItem> _consumptionPriority(List<FoodItem> items) {
    return items.take(5).toList(); // already ordered by expiryDate from Firestore
  }
 
  // ─── Days remaining label ──────────────────────────────────────────────────
  String _daysLabel(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    final days = expiry.difference(today).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        title: const Text(
          'ShelfSense',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<List<FoodItem>>(
        stream: FirestoreService().getFoodItems(),
        builder: (context, snapshot) {
          // ── Loading ────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3A7D44)),
            );
          }
 
          // ── Error ──────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load dashboard.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF868E96)),
              ),
            );
          }
 
          final items = snapshot.data ?? [];
          final attentionItems = _requiresAttention(items);
          final priorityItems = _consumptionPriority(items);
          final expiringSoonCount = _expiringSoon(items).length;
          final highRiskCount =
              items.where((i) => i.riskLevel == 'High').length;
 
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Section 1: Summary Statistics ──────────────────────────
              _SectionHeader(title: 'Summary'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Items',
                      value: '${items.length}',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF3A7D44),
                      backgroundColor: const Color(0xFFEFF6F0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Expiring Soon',
                      value: '$expiringSoonCount',
                      icon: Icons.schedule_outlined,
                      color: const Color(0xFFB8650A),
                      backgroundColor: const Color(0xFFFFF4E0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'High Risk',
                      value: '$highRiskCount',
                      icon: Icons.warning_amber_outlined,
                      color: const Color(0xFFC62828),
                      backgroundColor: const Color(0xFFFCE8E8),
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 28),
 
              // ── Section 2: Items Requiring Attention ───────────────────
              _SectionHeader(
                title: 'Requires Attention',
                subtitle: 'High & Medium risk items',
              ),
              const SizedBox(height: 12),
              attentionItems.isEmpty
                  ? _EmptyCard(
                      icon: Icons.check_circle_outline,
                      message: 'All items are looking good!',
                    )
                  : Column(
                      children: attentionItems
                          .map((item) => _AttentionItemRow(
                                item: item,
                                daysLabel: _daysLabel(item.expiryDate),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ItemDetailScreen(item: item),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
 
              const SizedBox(height: 28),
 
              // ── Section 3: Recommended Consumption Priority ────────────
              _SectionHeader(
                title: 'Consumption Priority',
                subtitle: 'Use these up first',
              ),
              const SizedBox(height: 12),
              priorityItems.isEmpty
                  ? _EmptyCard(
                      icon: Icons.add_shopping_cart_outlined,
                      message: 'Add items to your inventory to get started.',
                    )
                  : Column(
                      children: List.generate(
                        priorityItems.length,
                        (index) => _PriorityItemRow(
                          rank: index + 1,
                          item: priorityItems[index],
                          daysLabel: _daysLabel(priorityItems[index].expiryDate),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ItemDetailScreen(item: priorityItems[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
 
// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
 
  const _SectionHeader({required this.title, this.subtitle});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              '· $subtitle',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF868E96),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
 
// ─── Summary Stat Card ────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
 
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF868E96),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
 
// ─── Attention Item Row ───────────────────────────────────────────────────────
class _AttentionItemRow extends StatelessWidget {
  final FoodItem item;
  final String daysLabel;
  final VoidCallback onTap;
 
  const _AttentionItemRow({
    required this.item,
    required this.daysLabel,
    required this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category} · $daysLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF868E96),
                      ),
                    ),
                  ],
                ),
              ),
              RiskBadge(riskLevel: item.riskLevel),
            ],
          ),
        ),
      ),
    );
  }
}
 
// ─── Priority Item Row ────────────────────────────────────────────────────────
class _PriorityItemRow extends StatelessWidget {
  final int rank;
  final FoodItem item;
  final String daysLabel;
  final VoidCallback onTap;
 
  const _PriorityItemRow({
    required this.rank,
    required this.item,
    required this.daysLabel,
    required this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Rank number ──────────────────────────────────────────
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3A7D44),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
 
              // ── Name + expiry ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.storageType} · $daysLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF868E96),
                      ),
                    ),
                  ],
                ),
              ),
 
              // ── Risk badge ───────────────────────────────────────────
              RiskBadge(riskLevel: item.riskLevel),
            ],
          ),
        ),
      ),
    );
  }
}
 
// ─── Empty State Card ─────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
 
  const _EmptyCard({required this.icon, required this.message});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFCED4DA)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF868E96),
            ),
          ),
        ],
      ),
    );
  }
}