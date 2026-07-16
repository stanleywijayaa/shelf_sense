import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../services/firestore_service.dart';
import '../../services/ml_service.dart';
import '../../core/constants/food_categories.dart';

class AddItemScreen extends StatefulWidget {
  /// If provided, the screen opens in "edit mode": fields are pre-filled
  /// with this item's data, and submitting calls updateFoodItem() instead
  /// of addFoodItem(). If null, the screen behaves as the original
  /// "add new item" form.
  final FoodItem? existingItem;

  const AddItemScreen({super.key, this.existingItem});

  /// Convenience getter used throughout the State class to check
  /// whether we're editing an existing item or adding a new one.
  bool get isEditMode => existingItem != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  // ─── Form & Services ───────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  // ─── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();

  // ─── Dropdown Selections ────────────────────────────────────────────────────
  String? _selectedCategory;
  String? _selectedStorage;

  // Raw model values live in FoodCategories.values; the dropdown shows
  // FoodCategories.label(...) so users never see underscores/jargon.
  final List<String> _categories = FoodCategories.values;

  final List<String> _storageTypes = [
    'Fridge',
    'Freezer',
    'Pantry',
  ];

  // ─── Date Selections ────────────────────────────────────────────────────────
  DateTime? _purchaseDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();

    // If we were given an existing item, pre-fill every field so the
    // user is editing their current data rather than starting blank.
    final item = widget.existingItem;
    if (item != null) {
      _nameController.text = item.name;
      _selectedCategory = item.category;
      _selectedStorage = item.storageType;
      _purchaseDate = item.purchaseDate;
      _expiryDate = item.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─── Date Picker Helper ─────────────────────────────────────────────────────
  Future<void> _pickDate({required bool isPurchaseDate}) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      // Purchase date can be in the past; expiry date should be today or later
      firstDate: isPurchaseDate
          ? DateTime(now.year - 2)
          : now,
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        // Tint the date picker to match ShelfSense green
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3A7D44),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  // ─── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    // Validate form fields (name, category, storage)
    if (!_formKey.currentState!.validate()) return;

    // Validate dates separately since they aren't inside a TextFormField
    if (_purchaseDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both purchase and expiry dates.'),
          backgroundColor: Color(0xFFE63946),
        ),
      );
      return;
    }

    // Sanity check: expiry should be after purchase
    if (_expiryDate!.isBefore(_purchaseDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date must be after purchase date.'),
          backgroundColor: Color(0xFFE63946),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── ML RISK PREDICTION ────────────────────────────────────────────
      // Build a temporary FoodItem to hand to the ML service, which calls
      // the FastAPI backend. If the API is unreachable, MlService falls
      // back to the local rule-based estimate automatically.
      final tempItem = FoodItem(
        id: '',
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        storageType: _selectedStorage!,
        purchaseDate: _purchaseDate!,
        expiryDate: _expiryDate!,
      );
      final predictedRisk = await MlService.predictRisk(tempItem);

      if (widget.isEditMode) {
        // ── EDIT MODE: update the existing Firestore document ───────────
        // Reuse the original item's id via copyWith() so we don't have
        // to rebuild every field manually.
        final updatedItem = widget.existingItem!.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory!,
          storageType: _selectedStorage!,
          purchaseDate: _purchaseDate!,
          expiryDate: _expiryDate!,
          riskLevel: predictedRisk, // from ML API (or local fallback)
        );

        await _firestoreService.updateFoodItem(updatedItem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated!'),
              backgroundColor: Color(0xFF3A7D44),
            ),
          );
          Navigator.pop(context); // back to item detail / inventory
        }
      } else {
        // ── ADD MODE: create a brand new Firestore document ─────────────
        final newItem = FoodItem(
          id: '',  // Firestore generates this automatically
          name: _nameController.text.trim(),
          category: _selectedCategory!,
          storageType: _selectedStorage!,
          purchaseDate: _purchaseDate!,
          expiryDate: _expiryDate!,
          riskLevel: predictedRisk, // from ML API (or local fallback)
        );

        await _firestoreService.addFoodItem(newItem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item added to inventory!'),
              backgroundColor: Color(0xFF3A7D44),
            ),
          );
          Navigator.pop(context); // Go back to inventory list
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? 'Failed to update item: $e'
                  : 'Failed to add item: $e',
            ),
            backgroundColor: const Color(0xFFE63946),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7D44),
        foregroundColor: Colors.white,
        title: Text(
          widget.isEditMode ? 'Edit Food Item' : 'Add Food Item',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Item Name ──────────────────────────────────────────────────
              _SectionLabel(label: 'Item Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(hint: 'e.g. Whole Milk'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Category ───────────────────────────────────────────────────
              _SectionLabel(label: 'Category'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration(hint: 'Select a category'),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(FoodCategories.label(c)),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value),
                validator: (value) =>
                    value == null ? 'Please select a category.' : null,
              ),

              const SizedBox(height: 24),

              // ── Storage Type ───────────────────────────────────────────────
              _SectionLabel(label: 'Storage Location'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStorage,
                decoration: _inputDecoration(hint: 'Select storage type'),
                items: _storageTypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedStorage = value),
                validator: (value) =>
                    value == null ? 'Please select a storage location.' : null,
              ),

              const SizedBox(height: 24),

              // ── Dates ──────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Purchase Date'),
                        const SizedBox(height: 8),
                        _DatePickerButton(
                          label: _purchaseDate != null
                              ? DateFormat('dd MMM yyyy').format(_purchaseDate!)
                              : 'Select date',
                          onTap: () => _pickDate(isPurchaseDate: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Expiry Date'),
                        const SizedBox(height: 8),
                        _DatePickerButton(
                          label: _expiryDate != null
                              ? DateFormat('dd MMM yyyy').format(_expiryDate!)
                              : 'Select date',
                          onTap: () => _pickDate(isPurchaseDate: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Submit Button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7D44),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditMode ? 'Save Changes' : 'Add to Inventory',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared Input Decoration ─────────────────────────────────────────────
  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3A7D44), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE63946)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE63946), width: 1.5),
      ),
    );
  }
}

// ─── Section Label Widget ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF495057),
      ),
    );
  }
}

// ─── Date Picker Button Widget ────────────────────────────────────────────────
class _DatePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDEE2E6)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Color(0xFF3A7D44),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: label == 'Select date'
                      ? const Color(0xFFADB5BD)
                      : const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}