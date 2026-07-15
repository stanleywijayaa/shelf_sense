import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../widgets/risk_badge.dart';
import '../inventory/item_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  List<FoodItem> _expiringSoon(List<FoodItem> items) {
    final cutoff = DateTime.now().add(const Duration(days: 3));
    return items.where((item) => item.expiryDate.isBefore(cutoff)).toList();
  }

  List<FoodItem> _requiresAttention(List<FoodItem> items) {
    return items
        .where((i) => i.riskLevel == 'High' || i.riskLevel == 'Medium')
        .take(5)
        .toList();
  }

  List<FoodItem> _consumptionPriority(List<FoodItem> items) {
    return items.take(5).toList();
  }

  String _daysLabel(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
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
      // No AppBar — the curved green header below replaces it.
      body: StreamBuilder<List<FoodItem>>(
        stream: FirestoreService().getFoodItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final loading =
              snapshot.connectionState == ConnectionState.waiting;

          final attentionItems = _requiresAttention(items);
          final priorityItems = _consumptionPriority(items);
          final expiringSoonCount = _expiringSoon(items).length;
          final highRiskCount =
              items.where((i) => i.riskLevel == 'High').length;

          return Column(
            children: [
              // ── Curved green header ──────────────────────────────────
              _CurvedHeader(itemCount: items.length),

              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3A7D44)),
                      )
                    : snapshot.hasError
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Failed to load dashboard.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFF868E96)),
                              ),
                            ),
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              // ── Summary stats ──────────────────────
                              const _SectionHeader(title: 'Summary'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Total items',
                                      value: '${items.length}',
                                      icon: Icons.inventory_2_outlined,
                                      color: const Color(0xFF3A7D44),
                                      backgroundColor:
                                          const Color(0xFFEFF6F0),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Expiring soon',
                                      value: '$expiringSoonCount',
                                      icon: Icons.schedule_outlined,
                                      color: const Color(0xFFB8650A),
                                      backgroundColor:
                                          const Color(0xFFFFF4E0),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'High risk',
                                      value: '$highRiskCount',
                                      icon: Icons.warning_amber_outlined,
                                      color: const Color(0xFFC62828),
                                      backgroundColor:
                                          const Color(0xFFFCE8E8),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // ── Requires attention ─────────────────
                              const _SectionHeader(
                                title: 'Requires attention',
                                subtitle: 'High & medium risk items',
                              ),
                              const SizedBox(height: 12),
                              attentionItems.isEmpty
                                  ? const _EmptyCard(
                                      icon: Icons.check_circle_outline,
                                      message: 'All items are looking good!',
                                    )
                                  : Column(
                                      children: attentionItems
                                          .map((item) => _AttentionItemRow(
                                                item: item,
                                                daysLabel: _daysLabel(
                                                    item.expiryDate),
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ItemDetailScreen(
                                                            item: item),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),

                              const SizedBox(height: 28),

                              // ── Consumption priority ───────────────
                              const _SectionHeader(
                                title: 'Consumption priority',
                                subtitle: 'Use these up first',
                              ),
                              const SizedBox(height: 12),
                              priorityItems.isEmpty
                                  ? const _EmptyCard(
                                      icon: Icons.add_shopping_cart_outlined,
                                      message:
                                          'Add items to your inventory to get started.',
                                    )
                                  : Column(
                                      children: List.generate(
                                        priorityItems.length,
                                        (index) => _PriorityItemRow(
                                          rank: index + 1,
                                          item: priorityItems[index],
                                          daysLabel: _daysLabel(
                                              priorityItems[index]
                                                  .expiryDate),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ItemDetailScreen(
                                                item: priorityItems[index],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Curved green header ──────────────────────────────────────────────────
class _CurvedHeader extends StatelessWidget {
  final int itemCount;
  const _CurvedHeader({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 16, 18, 22),
      decoration: const BoxDecoration(
        color: Color(0xFF3A7D44),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ShelfSense',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            itemCount == 0
                ? 'Add items to start tracking freshness'
                : 'Keeping $itemCount item${itemCount == 1 ? '' : 's'} fresh',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFCDE3D2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────
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

// ─── Stat card ────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
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
              fontSize: 24,
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

// ─── Attention row (with risk edge strip) ─────────────────────────────────
class _AttentionItemRow extends StatelessWidget {
  final FoodItem item;
  final String daysLabel;
  final VoidCallback onTap;

  const _AttentionItemRow({
    required this.item,
    required this.daysLabel,
    required this.onTap,
  });

  Color get _edgeColor {
    switch (item.riskLevel) {
      case 'High':
        return const Color(0xFFC62828);
      case 'Medium':
        return const Color(0xFFBA7517);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.card,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _edgeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Priority row ─────────────────────────────────────────────────────────
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
        boxShadow: AppShadows.card,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
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
              RiskBadge(riskLevel: item.riskLevel),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────
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
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFCED4DA)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF868E96)),
          ),
        ],
      ),
    );
  }
}