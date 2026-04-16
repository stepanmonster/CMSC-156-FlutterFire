import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  // Definition of instances
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define data reference
  late final CollectionReference items = _db.collection('items');

  // Create item linked to the current user
  Future<void> insertItem(String itemName, int price, DateTime userDate) {
    final uid = _auth.currentUser?.uid;
    
    if (uid == null) throw Exception("User must be logged in to add items");

    return items.add({
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

  // Get the budget document for the current user
  Stream<DocumentSnapshot> getBudgetStream() {
    final uid = _auth.currentUser?.uid;
    return _db.collection('users').doc(uid).snapshots();
  }

  // Set or update the budget
  Future<void> setBudget(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('users').doc(uid).set({
      'monthlyBudget': amount,
    }, SetOptions(merge: true));
  }
}