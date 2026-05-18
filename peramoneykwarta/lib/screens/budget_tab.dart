import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late DateTime _selectedMonth;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (!next.isAfter(DateTime(now.year, now.month, 1))) {
      setState(() {
        _selectedMonth = next;
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final FirestoreService db = FirestoreService();

    return StreamBuilder<DocumentSnapshot>(
      stream: db.getBudgetStream(),
      builder: (context, budgetSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.getItemStream(),
          builder: (context, expenseSnapshot) {
            double monthlyBudget = 5000.0;
            if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
              final data = budgetSnapshot.data!.data() as Map<String, dynamic>?;
              final history = data?['budgetHistory'] as Map<String, dynamic>?;
              monthlyBudget = (history?[_monthKey] as num?)?.toDouble() ??
                  (data?['monthlyBudget'] as num?)?.toDouble() ??
                  5000.0;
            }

            double totalSpent = 0;
            if (expenseSnapshot.hasData) {
              for (var doc in expenseSnapshot.data!.docs) {
                final userDate =
                    (doc['userDate'] as Timestamp?)?.toDate() ??
                    (doc['timestamp'] as Timestamp?)?.toDate();
                if (userDate == null ||
                    (userDate.year == _selectedMonth.year &&
                        userDate.month == _selectedMonth.month)) {
                  totalSpent += (doc['itemPrice'] as num).toDouble();
                }
              }
            }

            final double remaining = monthlyBudget - totalSpent;
            final int daysInMonth =
                DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
            final int dayOfMonth = _isCurrentMonth ? DateTime.now().day : daysInMonth;
            final int remainingDays = (daysInMonth - dayOfMonth) + 1;
            final bool isPastMonth = !_isCurrentMonth;
            final double dailyAverage = isPastMonth
                ? totalSpent / (dayOfMonth > 0 ? dayOfMonth : 1)
                : remaining / (remainingDays > 0 ? remainingDays : 1);
            final double progress = (totalSpent / monthlyBudget).clamp(0.0, 1.0);
            final bool isOverBudget = remaining < 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selector
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _previousMonth,
                          icon: const Icon(Icons.chevron_left),
                          color: AppTheme.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _monthLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _isCurrentMonth ? null : _nextMonth,
                          icon: const Icon(Icons.chevron_right),
                          color: _isCurrentMonth
                              ? AppTheme.borderLight
                              : AppTheme.textPrimary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Hero spend card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.surfaceDark.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Monthly Spending",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOverBudget
                                    ? AppTheme.errorRed.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOverBudget
                                    ? "Over budget"
                                    : "${(progress * 100).toStringAsFixed(0)}% used",
                                style: TextStyle(
                                  color: isOverBudget
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "₱${totalSpent.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          "of ₱${monthlyBudget.toStringAsFixed(0)} budget",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOverBudget
                                      ? AppTheme.errorRed
                                      : progress > 0.75
                                          ? AppTheme.warningAmber
                                          : AppTheme.successGreen,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stat cards row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: "Remaining",
                          value: "₱${remaining.abs().toStringAsFixed(2)}",
                          sublabel: isOverBudget
                              ? "over limit"
                              : isPastMonth
                                  ? "left that month"
                                  : "left this month",
                          icon: Icons.savings_outlined,
                          iconColor: isOverBudget
                              ? AppTheme.errorRed
                              : AppTheme.successGreen,
                          valueColor: isOverBudget
                              ? AppTheme.errorRed
                              : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: isPastMonth ? "Avg Daily" : "Daily Allowance",
                          value: dailyAverage > 0
                              ? "₱${dailyAverage.toStringAsFixed(2)}"
                              : "₱0",
                          sublabel: isPastMonth
                              ? "avg per day"
                              : "$remainingDays days left",
                          icon: Icons.today_outlined,
                          iconColor: AppTheme.warningAmber,
                          valueColor: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Monthly limit card
                  _StatCard(
                    label: "Monthly Limit",
                    value: "₱${monthlyBudget.toStringAsFixed(0)}",
                    sublabel: "Tap below to update",
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF6366F1),
                    valueColor: AppTheme.textPrimary,
                    wide: true,
                  ),

                  if (_isCurrentMonth) ...[
                    const SizedBox(height: 28),

                    // Divider with label
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppTheme.borderLight)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "Settings",
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppTheme.borderLight)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Update budget button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showSetBudgetDialog(context, db, monthlyBudget);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text(
                          "Update Budget Goal",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSetBudgetDialog(
      BuildContext context, FirestoreService db, double current) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Update Budget",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Set your new monthly spending limit",
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixText: "₱ ",
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            filled: true,
            fillColor: Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.surfaceDark, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              }
              await db.setBudget(amount);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Save",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: wide
          ? Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}
