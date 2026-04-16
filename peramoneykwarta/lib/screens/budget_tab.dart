import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

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
              monthlyBudget = (data?['monthlyBudget'] as num?)?.toDouble() ?? 5000.0;
            }

            double totalSpent = 0;
            if (expenseSnapshot.hasData) {
              for (var doc in expenseSnapshot.data!.docs) {
                totalSpent += (doc['itemPrice'] as num).toDouble();
              }
            }

            final double remaining = monthlyBudget - totalSpent;
            final int daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
            final int remainingDays = (daysInMonth - DateTime.now().day) + 1;
            final double dailyAverage = remaining / (remainingDays > 0 ? remainingDays : 1);
            final double progress = (totalSpent / monthlyBudget).clamp(0.0, 1.0);
            final bool isOverBudget = remaining < 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero spend card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.2),
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
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOverBudget
                                    ? const Color(0xFFEF4444).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOverBudget ? "Over budget" : "${(progress * 100).toStringAsFixed(0)}% used",
                                style: TextStyle(
                                  color: isOverBudget ? const Color(0xFFFCA5A5) : Colors.white.withOpacity(0.8),
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
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOverBudget
                                  ? const Color(0xFFEF4444)
                                  : progress > 0.75
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF34D399),
                            ),
                          ),
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
                          sublabel: isOverBudget ? "over limit" : "left this month",
                          icon: Icons.savings_outlined,
                          iconColor: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                          valueColor: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: "Daily Allowance",
                          value: dailyAverage > 0 ? "₱${dailyAverage.toStringAsFixed(2)}" : "₱0",
                          sublabel: "$remainingDays days left",
                          icon: Icons.today_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          valueColor: const Color(0xFF0F172A),
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
                    valueColor: const Color(0xFF0F172A),
                    wide: true,
                  ),

                  const SizedBox(height: 28),

                  // Divider with label
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[200])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text("Settings", style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[200])),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Update budget button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _showSetBudgetDialog(context, db, monthlyBudget),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text(
                        "Update Budget Goal",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSetBudgetDialog(BuildContext context, FirestoreService db, double current) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Budget", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF0F172A))),
            SizedBox(height: 4),
            Text("Set your new monthly spending limit", style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixText: "₱ ",
            prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              db.setBudget(double.tryParse(controller.text) ?? current);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: wide
          ? Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 12),
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(sublabel, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
    );
  }
}