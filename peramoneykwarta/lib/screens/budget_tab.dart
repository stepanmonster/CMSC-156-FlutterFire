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
            // Get Budget from Firestore (Default to 5000 if not set)
            double monthlyBudget = 5000.0; 

            if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
              final data = budgetSnapshot.data!.data() as Map<String, dynamic>?;
              
              // Use the null-aware operator and '??' to provide a fallback
              // This replaces that long if-else chain
              monthlyBudget = (data?['monthlyBudget'] as num?)?.toDouble() ?? 5000.0;
            }

            // Calculate Total Spent
            double totalSpent = 0;
            if (expenseSnapshot.hasData) {
              for (var doc in expenseSnapshot.data!.docs) {
                totalSpent += (doc['itemPrice'] as num).toDouble();
              }
            }

            // Calculations
            double remaining = monthlyBudget - totalSpent;
            int daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
            int remainingDays = (daysInMonth - DateTime.now().day) + 1;
            double dailyAverage = remaining / (remainingDays > 0 ? remainingDays : 1);

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildBudgetCard("Monthly Limit", "₱${monthlyBudget.toStringAsFixed(0)}", const Color(0xFF1E293B)),
                  const SizedBox(height: 16),
                  _buildBudgetCard("Remaining", "₱${remaining.toStringAsFixed(2)}", 
                    remaining > 0 ? Colors.green : Colors.red),
                  const SizedBox(height: 16),
                  _buildBudgetCard("Daily Allowance", "₱${dailyAverage.toStringAsFixed(2)}", Colors.orange),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showSetBudgetDialog(context, db, monthlyBudget),
                    icon: const Icon(Icons.edit_note),
                    label: const Text("Update Budget Goal"),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showSetBudgetDialog(BuildContext context, FirestoreService db, double current) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Monthly Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: "₱ "),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              db.setBudget(double.tryParse(controller.text) ?? current);
              Navigator.pop(context);
            }, 
            child: const Text("Save")
          ),
        ],
      ),
    );
  }
}