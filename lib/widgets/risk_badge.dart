import 'package:flutter/material.dart';

/// Small colored pill that displays a food item's spoilage risk level.
/// Includes a leading dot indicator so the risk reads at a glance.
class RiskBadge extends StatelessWidget {
  final String riskLevel;

  const RiskBadge({super.key, required this.riskLevel});

  Color get _backgroundColor {
    switch (riskLevel) {
      case 'Low':
        return const Color(0xFFE6F4EA);
      case 'Medium':
        return const Color(0xFFFFF4E0);
      case 'High':
        return const Color(0xFFFCE8E8);
      default:
        return const Color(0xFFF1F3F5);
    }
  }

  Color get _textColor {
    switch (riskLevel) {
      case 'Low':
        return const Color(0xFF1B5E20);
      case 'Medium':
        return const Color(0xFF633806);
      case 'High':
        return const Color(0xFF791F1F);
      default:
        return const Color(0xFF6C757D);
    }
  }

  /// Saturated dot colour — stronger than the text so it reads as a signal.
  Color get _dotColor {
    switch (riskLevel) {
      case 'Low':
        return const Color(0xFF2E7D32);
      case 'Medium':
        return const Color(0xFFBA7517);
      case 'High':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFADB5BD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            riskLevel,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}