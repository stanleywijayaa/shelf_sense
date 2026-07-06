import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../inventory/inventory_screen.dart';
import '../recipe/recipe_screen.dart';
 
/// Root wrapper for the app's main navigation.
///
/// Uses an IndexedStack instead of Navigator.push so all three screens
/// stay alive in memory when switching tabs — scroll positions and
/// state are preserved across tab switches, which feels more natural.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
 
  @override
  State<MainScreen> createState() => _MainScreenState();
}
 
class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
 
  // All three screens are instantiated once and kept alive by IndexedStack.
  // Adding a new tab later just means adding to this list and the nav items.
  final List<Widget> _screens = const [
    HomeScreen(),
    InventoryScreen(),
    RecipeScreen(),
  ];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack renders all children but only shows the one at
      // `_currentIndex` — this is what preserves state across tab switches.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF3A7D44),
        unselectedItemColor: const Color(0xFFADB5BD),
        backgroundColor: Colors.white,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
        ],
      ),
    );
  }
}