import 'package:cloud_firestore/cloud_firestore.dart';

// Pure helpers for debt calculations.
// No side effects — same input, same output (code-quality standard).

// Remaining balance: amount - paidAmount (clamped to >= 0 so a lowered
// amount can never show a negative balance).
double debtRemaining(Map<String, dynamic> debt) {
  final amount = (debt['amount'] as num?)?.toDouble() ?? 0;
  final paid = (debt['paidAmount'] as num?)?.toDouble() ?? 0;
  final remaining = amount - paid;
  return remaining < 0 ? 0 : remaining;
}

// Payment progress from 0.0 to 1.0.
double debtProgress(Map<String, dynamic> debt) {
  final amount = (debt['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) return 0;
  final paid = (debt['paidAmount'] as num?)?.toDouble() ?? 0;
  return (paid / amount).clamp(0.0, 1.0);
}

// Derived status: 'pending' (nothing paid), 'partial', or 'paid'.
// Kept derived instead of stored so it can never drift from the numbers.
String debtStatus(Map<String, dynamic> debt) {
  final amount = (debt['amount'] as num?)?.toDouble() ?? 0;
  final paid = (debt['paidAmount'] as num?)?.toDouble() ?? 0;
  if (amount > 0 && paid >= amount) return 'paid';
  if (paid > 0) return 'partial';
  return 'pending';
}

// True when the due date is before today and the debt is not fully paid.
// Date-only comparison: a debt due today is not overdue until tomorrow.
bool isOverdue(Map<String, dynamic> debt, DateTime now) {
  final due = (debt['dueDate'] as Timestamp?)?.toDate();
  if (due == null) return false;
  if (debtStatus(debt) == 'paid') return false;

  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  return dueDay.isBefore(today);
}

// Remaining balances split by direction, summed across all debts.
// Paid debts contribute 0 (their remaining is 0).
({double owe, double owed}) debtTotals(List<Map<String, dynamic>> debts) {
  double owe = 0;
  double owed = 0;

  for (final debt in debts) {
    final remaining = debtRemaining(debt);
    if (debt['direction'] == 'owe') {
      owe += remaining;
    } else if (debt['direction'] == 'owed') {
      owed += remaining;
    }
  }

  return (owe: owe, owed: owed);
}
