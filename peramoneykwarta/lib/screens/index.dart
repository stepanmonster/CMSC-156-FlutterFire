import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'expenses_tab.dart';
import 'budget_tab.dart';
import '../components/add_item_modal.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  void _showAddExpenseModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddItemModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          title: const Text("PeraMoneyKwarta"),
          actions: [
            IconButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: "Expenses"),
              Tab(icon: Icon(Icons.account_balance_wallet), text: "Budget"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ExpensesTab(),
            BudgetTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          onPressed: () => _showAddExpenseModal(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}