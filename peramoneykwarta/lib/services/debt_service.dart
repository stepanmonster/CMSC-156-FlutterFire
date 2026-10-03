import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebtService {
  // Definition of instances
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define data reference
  late final CollectionReference debts = _db.collection('debts');

  static const Set<String> _validDirections = {'owe', 'owed'};

  // Validate debt fields at the boundary
  void _validate({
    required String description,
    required double amount,
    required String direction,
    required String person,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('Description must not be empty');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than 0');
    }
    if (!_validDirections.contains(direction)) {
      throw ArgumentError.value(
          direction, 'direction', "must be 'owe' or 'owed'");
    }
    if (person.trim().isEmpty) {
      throw ArgumentError('Person must not be empty');
    }
  }

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User must be logged in');
    return uid;
  }

  // Create a new debt for the currently logged-in user
  Future<void> insertDebt({
    required String description,
    required double amount,
    required String direction,
    required String person,
    DateTime? dueDate,
  }) async {
    _validate(
      description: description,
      amount: amount,
      direction: direction,
      person: person,
    );

    await debts.add({
      'description': description.trim(),
      'amount': amount,
      'paidAmount': 0,
      'direction': direction,
      'person': person.trim(),
      'dueDate': dueDate,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _uid,
    });
  }

  // Update a debt's details (paidAmount is managed via recordPayment only)
  Future<void> updateDebt({
    required String debtId,
    required String description,
    required double amount,
    required String direction,
    required String person,
    DateTime? dueDate,
  }) async {
    _validate(
      description: description,
      amount: amount,
      direction: direction,
      person: person,
    );

    await debts.doc(debtId).update({
      'description': description.trim(),
      'amount': amount,
      'direction': direction,
      'person': person.trim(),
      'dueDate': dueDate,
    });
  }

  // Delete a debt
  Future<void> deleteDebt(String debtId) {
    return debts.doc(debtId).delete();
  }

  // Record a (partial) payment against a debt.
  // The caller is responsible for clamping the payment to the
  // remaining balance before calling (see debt math helpers).
  Future<void> recordPayment(String debtId, double payment) async {
    if (payment <= 0) {
      throw ArgumentError.value(payment, 'payment', 'must be greater than 0');
    }

    await debts.doc(debtId).update({
      'paidAmount': FieldValue.increment(payment),
    });
  }

  // Read debts only for the currently logged-in user
  Stream<QuerySnapshot> getDebtStream() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) return const Stream.empty();

    return debts
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
