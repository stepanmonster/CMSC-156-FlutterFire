import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  // Definition of instances
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define data reference
  late final CollectionReference items = _db.collection('items');

  Future<void> insertItem(String itemName, int price, DateTime userDate) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) throw Exception("User must be logged in to add items");

    await items.add({
      'itemName': itemName,
      'itemPrice': price,
      'userId': uid,
      'userDate': userDate,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Read items only for the currently logged-in user
  Stream<QuerySnapshot> getItemStream() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) return const Stream.empty();

    return items
        .where('userId', isEqualTo: uid)
        .orderBy('userDate', descending: true) // Sort by the actual expense date
        .snapshots();
  }

  // Update item
  Future<void> updateItem(String itemID, String newItemName, int newPrice, DateTime selectedDate) {
    return items.doc(itemID).update({
      'itemName': newItemName,
      'itemPrice': newPrice,
      'userDate': selectedDate,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Delete item
  Future<void> deleteItem(String itemID) {
    return items.doc(itemID).delete();
  }

  // Get frequent item name suggestions for the current user.
  // Uses the same filter/sort as getItemStream() so the existing
  // Firestore composite index (userId + userDate) applies.
  Future<List<String>> getRecentItemNames({int limit = 8}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snap = await items
        .where('userId', isEqualTo: uid)
        .orderBy('userDate', descending: true)
        .limit(100)
        .get();

    final frequency = <String, int>{};
    final recency = <String, int>{};
    var order = 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['itemName'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      if (!recency.containsKey(name)) recency[name] = order;
      frequency[name] = (frequency[name] ?? 0) + 1;
      order++;
    }

    final names = frequency.keys.toList()
      ..sort((a, b) {
        final byFreq = frequency[b]!.compareTo(frequency[a]!);
        if (byFreq != 0) return byFreq;
        return recency[a]!.compareTo(recency[b]!);
      });

    return names.take(limit).toList();
  }

  // Get the budget document for the current user
  Stream<DocumentSnapshot> getBudgetStream() {
    final uid = _auth.currentUser?.uid;
    return _db.collection('users').doc(uid).snapshots();
  }

  // Set or update the budget
  Future<void> setBudget(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    await _db.collection('users').doc(uid).set({
      'monthlyBudget': amount,
      'budgetHistory.$monthKey': amount,
    }, SetOptions(merge: true));
  }
}