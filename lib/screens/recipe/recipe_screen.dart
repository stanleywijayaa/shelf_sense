import 'package:flutter/material.dart';
 
/// Placeholder for the Recipe Suggestions screen (Phase 5).
/// This screen will eventually show recipe recommendations generated
/// from high-risk inventory items. For now it renders a simple
/// coming-soon state so the bottom nav tab doesn't crash.
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        title: const Text(
          'Recipes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 60,
                color: Color(0xFFCED4DA),
              ),
              SizedBox(height: 16),
              Text(
                'Recipes Coming Soon',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF495057),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Recipe suggestions based on high-risk\ningredients will appear here in Phase 5.',
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
      ),
    );
  }
}