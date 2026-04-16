import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../components/add_item_modal.dart'; 

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final FirestoreService _db = FirestoreService();
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sorting Chips
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['All', 'Today', 'Yesterday', 'This Week'].map((label) {
              return ChoiceChip(
                label: Text(label),
                selected: _filter == label,
                onSelected: (val) => setState(() => _filter = label),
              );
            }).toList(),
          ),
        ),
        // Expenses List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getItemStream(), 
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var docs = snapshot.data!.docs;

              // Filter logic
              final now = DateTime.now();
              docs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                // Use 'userDate' if available, otherwise fallback to 'timestamp'
                final date = (data['userDate'] as Timestamp?)?.toDate() ?? 
                             (data['timestamp'] as Timestamp?)?.toDate() ?? now;
                final difference = now.difference(date).inDays;

                if (_filter == 'Today') return difference == 0;
                if (_filter == 'Yesterday') return difference == 1;
                if (_filter == 'This Week') return difference <= 7;
                return difference <= 7; 
              }).toList();

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  
                  // Extract correct keys from your FirestoreService
                  final String name = data['itemName'] ?? 'Unnamed Item';
                  final int price = data['itemPrice'] ?? 0;
                  final DateTime displayDate = (data['userDate'] as Timestamp?)?.toDate() ?? 
                                               (data['timestamp'] as Timestamp?)?.toDate() ?? now;

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(Icons.receipt, color: Colors.white, size: 20),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${displayDate.month}/${displayDate.day}/${displayDate.year}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("₱$price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditModal(context, docId, name, price);
                            } else if (value == 'delete') {
                              _db.deleteItem(docId); //
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text("Edit")),
                            const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditModal(BuildContext context, String id, String name, int price) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddItemModal(
        itemID: id,
        initialName: name,
        initialPrice: price,
      ),
    );
  }
}