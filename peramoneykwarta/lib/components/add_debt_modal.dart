import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debt_service.dart';
import '../components/app_snackbar.dart';
import '../components/styled_fields.dart';
import '../theme/app_theme.dart';

class AddDebtModal extends StatefulWidget {
  final String? debtId;
  final String? initialDescription;
  final double? initialAmount;
  final String? initialDirection; // 'owe' | 'owed'
  final String? initialPerson;
  final DateTime? initialDueDate;

  const AddDebtModal({
    super.key,
    this.debtId,
    this.initialDescription,
    this.initialAmount,
    this.initialDirection,
    this.initialPerson,
    this.initialDueDate,
  });

  @override
  State<AddDebtModal> createState() => _AddDebtModalState();
}

class _AddDebtModalState extends State<AddDebtModal> {
  final DebtService _debtService = DebtService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  String _direction = 'owe';
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.debtId != null) {
      _descriptionController.text = widget.initialDescription ?? '';
      if (widget.initialAmount != null) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(0);
      }
      _direction = widget.initialDirection ?? 'owe';
      _personController.text = widget.initialPerson ?? '';
      _dueDate = widget.initialDueDate;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _personController.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get _formattedDueDate {
    if (_dueDate == null) return 'No due date (optional)';
    return '${_months[_dueDate!.month - 1]} ${_dueDate!.day}, ${_dueDate!.year}';
  }

  void _handleSubmit() async {
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final person = _personController.text.trim();

    if (description.isEmpty) {
      AppSnackbar.show(context, 'Please enter a description');
      return;
    }
    if (amount == null || amount <= 0) {
      AppSnackbar.show(context, 'Please enter a valid amount greater than 0');
      return;
    }
    if (person.isEmpty) {
      AppSnackbar.show(context, "Please enter who it's for (e.g. Mom)");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.debtId == null) {
        await _debtService.insertDebt(
          description: description,
          amount: amount,
          direction: _direction,
          person: person,
          dueDate: _dueDate,
        );
      } else {
        await _debtService.updateDebt(
          debtId: widget.debtId!,
          description: description,
          amount: amount,
          direction: _direction,
          person: person,
          dueDate: _dueDate,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Failed to save: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDueDate() async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
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
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  void _clearDueDate() {
    HapticFeedback.lightImpact();
    setState(() => _dueDate = null);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.debtId != null;

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
                          isEditing ? Icons.edit_rounded : Icons.handshake_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Debt' : 'New Debt',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Edit the details below'
                                : 'Track what you owe or lent',
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

                  // Direction: I owe / Owed to me
                  Row(
                    children: [
                      Expanded(
                        child: _DirectionOption(
                          label: 'I owe',
                          icon: Icons.arrow_outward_rounded,
                          selected: _direction == 'owe',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _direction = 'owe');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DirectionOption(
                          label: 'Owed to me',
                          icon: Icons.south_west_rounded,
                          selected: _direction == 'owed',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _direction = 'owed');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  FieldLabel(label: 'Description'),
                  const SizedBox(height: 8),
                  StyledTextField(
                    controller: _descriptionController,
                    hint: 'e.g. Cash advance, Borrowed cash...',
                    icon: Icons.notes_rounded,
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(label: 'Amount (₱)'),
                  const SizedBox(height: 8),
                  StyledTextField(
                    controller: _amountController,
                    hint: '0',
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(label: 'Person'),
                  const SizedBox(height: 8),
                  StyledTextField(
                    controller: _personController,
                    hint: 'e.g. Mom, Juan, Sibling...',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(label: 'Due Date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDueDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.borderLight, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formattedDueDate,
                              style: TextStyle(
                                fontSize: 15,
                                color: _dueDate == null
                                    ? AppTheme.textMuted
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_dueDate != null)
                            GestureDetector(
                              onTap: _clearDueDate,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.textMuted,
                                  size: 18,
                                ),
                              ),
                            ),
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
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              side: const BorderSide(
                                  color: AppTheme.borderLight, width: 1.5),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
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
                                  isEditing ? 'Save Changes' : 'Add Debt',
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

// Direction selector chip — selected uses surfaceDark, unselected stays
// light, matching the filter pill pattern used across the app.
class _DirectionOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.surfaceDark : AppTheme.borderLight,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
