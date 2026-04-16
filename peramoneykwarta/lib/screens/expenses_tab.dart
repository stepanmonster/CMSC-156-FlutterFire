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

  static const _filters = ['All', 'Today', 'Yesterday', 'This Week'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips row
        Container(
          color: const Color(0xFFF8F7F4),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((label) {
                final isSelected = _filter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.grey[200]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Expenses List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getItemStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("Something went wrong", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("${snapshot.error}", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0F172A),
                    strokeWidth: 2.5,
                  ),
                );
              }

              var docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.receipt_long_outlined, size: 38, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "No expenses yet",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Tap the button below to log your first one.",
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              // Filter logic
              final now = DateTime.now();
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final date = (data['userDate'] as Timestamp?)?.toDate() ??
                    (data['timestamp'] as Timestamp?)?.toDate() ??
                    now;
                final difference = now.difference(date).inDays;
                if (_filter == 'Today') return difference == 0;
                if (_filter == 'Yesterday') return difference == 1;
                if (_filter == 'This Week') return difference <= 7;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        "No expenses for $_filter",
                        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              // Compute total for this filter period
              double totalShown = filtered.fold(0, (sum, d) {
                final data = d.data() as Map<String, dynamic>;
                return sum + ((data['itemPrice'] as num?)?.toDouble() ?? 0);
              });

              return Column(
                children: [
                  // Summary bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${filtered.length} expense${filtered.length != 1 ? 's' : ''}",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "₱${totalShown.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        final String name = data['itemName'] ?? 'Unnamed Item';
                        final int price = data['itemPrice'] ?? 0;
                        final DateTime displayDate = (data['userDate'] as Timestamp?)?.toDate() ??
                            (data['timestamp'] as Timestamp?)?.toDate() ??
                            now;

                        return _ExpenseCard(
                          name: name,
                          price: price,
                          date: displayDate,
                          onEdit: () => _showEditModal(context, docId, name, price),
                          onDelete: () async {
                            try {
                              await _db.deleteItem(docId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                        SizedBox(width: 10),
                                        Text("Expense deleted", style: TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF22C55E),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
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
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemModal(itemID: id, initialName: name, initialPrice: price),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final String name;
  final int price;
  final DateTime date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.name,
    required this.price,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_rounded, color: Color(0xFF0F172A), size: 20),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(date),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Price + Menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₱$price",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: Icon(Icons.more_horiz, color: Colors.grey[400], size: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                    if (value == 'edit') onEdit();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text("Edit", style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text("Delete", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}