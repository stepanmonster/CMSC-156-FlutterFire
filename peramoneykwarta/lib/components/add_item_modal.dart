import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

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
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.itemID != null) {
      _nameController.text = widget.initialName ?? "";
      _priceController.text = widget.initialPrice?.toString() ?? "";
    }
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isNotEmpty) {
      if (widget.itemID == null) {
        firestoreService.insertItem(name, price, _selectedDate);
      } else {
        firestoreService.updateItem(widget.itemID!, name, price);
      }
      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Prevents picking future dates
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.itemID == null ? "Add Expense" : "Update Expense",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Item Name"),
            autofocus: true,
          ),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: "Price"),
            keyboardType: TextInputType.number,
          ),
          
          // --- ADDED DATE PICKER UI SECTION ---
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: Color(0xFF1E293B)),
            title: Text(
              "Date of Expense: ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}",
              style: const TextStyle(fontSize: 14),
            ),
            trailing: TextButton(
              onPressed: _pickDate,
              child: const Text("Change", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          // ------------------------------------

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
              ),
              child: Text(widget.itemID == null ? "Save Expense" : "Update Expense"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}