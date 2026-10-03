import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../components/app_snackbar.dart';
import '../components/styled_fields.dart';
import '../theme/app_theme.dart';

class AddItemModal extends StatefulWidget {
  final String? itemID;
  final String? initialName;
  final int? initialPrice;

  const AddItemModal({
    super.key,
    this.itemID,
    this.initialName,
    this.initialPrice,
  });

  @override
  State<AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<AddItemModal> {
  static const _defaultSuggestions = [
    'Lunch',
    'Coffee',
    'Transportation',
    'Groceries',
    'Snacks',
    'Load',
  ];

  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<String> _suggestions = [];
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    if (widget.itemID != null) {
      _nameController.text = widget.initialName ?? "";
      _priceController.text = widget.initialPrice?.toString() ?? "";
    }
    _showSuggestions = _nameController.text.isEmpty;
    _nameController.addListener(_onNameChanged);
    _loadSuggestions();
  }

  void _onNameChanged() {
    final show = _nameController.text.isEmpty;
    if (show != _showSuggestions && mounted) {
      setState(() => _showSuggestions = show);
    }
  }

  Future<void> _loadSuggestions() async {
    final recent = await firestoreService.getRecentItemNames(limit: 6);
    if (!mounted) return;

    final merged = <String>[];
    for (final name in [...recent, ..._defaultSuggestions]) {
      if (merged.length >= 8) break;
      if (!merged.any((n) => n.toLowerCase() == name.toLowerCase())) {
        merged.add(name);
      }
    }
    setState(() => _suggestions = merged);
  }

  void _applySuggestion(String name) {
    HapticFeedback.lightImpact();
    _nameController.text = name;
    _nameController.selection = TextSelection.collapsed(offset: name.length);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String get _formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _handleSubmit() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final price = int.tryParse(priceText);

    if (name.isEmpty) {
      AppSnackbar.show(context, "Please enter an item name");
      return;
    }
    if (price == null || price <= 0) {
      AppSnackbar.show(context, "Please enter a valid price greater than 0");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.itemID == null) {
        await firestoreService.insertItem(name, price, _selectedDate);
      } else {
        await firestoreService.updateItem(widget.itemID!, name, price, _selectedDate);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, "Failed to save: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
              builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.surfaceDark,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.surfaceDark,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemID != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? "Update Expense" : "New Expense",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            isEditing ? "Edit the details below" : "Track what you spent",
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FieldLabel(label: "Item Name"),
                  const SizedBox(height: 8),
                  StyledTextField(
                    controller: _nameController,
                    hint: "e.g. Lunch, Grab ride, Coffee...",
                    icon: Icons.receipt_long_rounded,
                    autofocus: true,
                  ),
                  if (_showSuggestions && _suggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((name) {
                        return ActionChip(
                          label: Text(name),
                          onPressed: () => _applySuggestion(name),
                          backgroundColor: AppTheme.background,
                          side: const BorderSide(
                            color: AppTheme.borderLight,
                            width: 1.5,
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FieldLabel(label: "Amount (₱)"),
                  const SizedBox(height: 8),
                  StyledTextField(
                    controller: _priceController,
                    hint: "0",
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(label: "Date"),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.borderLight, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formattedDate,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Today",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              side: const BorderSide(color: AppTheme.borderLight, width: 1.5),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            disabledBackgroundColor: const Color(0xFF475569),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEditing ? "Save Changes" : "Add Expense",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

