import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/debt_service.dart';
import '../utils/debt_math.dart';
import '../utils/format.dart';
import '../components/add_debt_modal.dart';
import '../components/app_snackbar.dart';
import '../components/shimmer_loading.dart';
import '../theme/app_theme.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  final DebtService _debtService = DebtService();
  String _filter = 'All';

  static const _filters = ['All', 'Owe', 'Owed'];

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddDebtModal(),
    );
  }

  void _showEditModal(Map<String, dynamic> debt, String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDebtModal(
        debtId: id,
        initialDescription: debt['description'] as String?,
        initialAmount: (debt['amount'] as num?)?.toDouble(),
        initialDirection: debt['direction'] as String?,
        initialPerson: debt['person'] as String?,
        initialDueDate: (debt['dueDate'] as Timestamp?)?.toDate(),
      ),
    );
  }

  void _showPaymentDialog(Map<String, dynamic> debt, String id) {
    final remaining = debtRemaining(debt);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Record Payment",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Remaining: ${formatCurrency(remaining)}",
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixText: "₱ ",
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide:
                  const BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(
                  color: AppTheme.surfaceDark, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide:
                  const BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                AppSnackbar.show(
                    context, "Please enter a valid amount");
                return;
              }
              if (amount > remaining) {
                AppSnackbar.show(
                  context,
                  "Payment cannot exceed ${formatCurrency(remaining)}",
                );
                return;
              }
              try {
                await _debtService.recordPayment(id, amount);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackbar.show(context, "Failed to record payment: $e");
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              if (mounted) {
                AppSnackbar.show(this.context, "Payment recorded",
                    isError: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Save",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmMarkPaid(Map<String, dynamic> debt, String id) {
    final remaining = debtRemaining(debt);
    final description = debt['description'] as String? ?? 'this debt';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: const Text(
          "Mark as paid?",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          "This will settle the remaining ${formatCurrency(remaining)} of \u201C$description\u201D. Payments can't be reversed.",
          style: const TextStyle(
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _debtService.recordPayment(id, remaining);
                if (!context.mounted) return;
                AppSnackbar.show(context, "Debt marked as paid",
                    isError: false);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackbar.show(context, "Error: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Mark Paid",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: const Text(
          "Delete debt?",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          "This action cannot be undone.",
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _debtService.deleteDebt(id);
                if (!context.mounted) return;
                AppSnackbar.show(context, "Debt deleted", isError: false);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackbar.show(context, "Error: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.handshake_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Debts",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _debtService.getDebtStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppTheme.borderLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 34,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Something went wrong",
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Please try again later.",
                    style: AppTheme.caption,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.only(top: 16),
              child: ShimmerList(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: AppTheme.borderLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      size: 40,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "No debts yet",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Track what you owe or what others owe you.\nTap the button below to add one.",
                    textAlign: TextAlign.center,
                    style: AppTheme.caption.copyWith(height: 1.5),
                  ),
                ],
              ),
            );
          }

          final debts = docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();
          final totals = debtTotals(debts);

          final filteredDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (_filter == 'Owe') return data['direction'] == 'owe';
            if (_filter == 'Owed') return data['direction'] == 'owed';
            return true;
          }).toList();

          return Column(
            children: [
              _buildSummaryRow(totals),
              _buildFilters(),
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppTheme.borderLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 34,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No debts for $_filter",
                              style: AppTheme.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Try a different filter.",
                              style: AppTheme.caption,
                            ),
                          ],
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: ListView.separated(
                          key: ValueKey(_filter),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final doc = filteredDocs[i];
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final id = doc.id;
                            final status = debtStatus(data);

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                  milliseconds: 300 + (i * 50).clamp(0, 300)),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 15 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _DebtCard(
                                debt: data,
                                onEdit: () => _showEditModal(data, id),
                                onPayment: () =>
                                    _showPaymentDialog(data, id),
                                onMarkPaid: () =>
                                    _confirmMarkPaid(data, id),
                                onDelete: () => _confirmDelete(id),
                                showPaidActions: status != 'paid',
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddModal();
        },
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          "Add Debt",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(({double owe, double owed}) totals) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: "You owe",
              value: formatCurrency(totals.owe),
              icon: Icons.arrow_outward_rounded,
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: "Owed to you",
              value: formatCurrency(totals.owed),
              icon: Icons.south_west_rounded,
              color: AppTheme.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((label) {
            final isSelected = _filter == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _filter = label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 20 : 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.surfaceDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.surfaceDark
                          : AppTheme.borderLight,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Summary card for total owe / owed balances — follows the _StatCard
// styling used on the Budget tab (white, light border, tinted icon).
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// A single debt row — follows the _ExpenseCard layout from the
// Expenses tab, plus partial-payment progress and status handling.
class _DebtCard extends StatelessWidget {
  final Map<String, dynamic> debt;
  final VoidCallback onEdit;
  final VoidCallback onPayment;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;
  final bool showPaidActions;

  const _DebtCard({
    required this.debt,
    required this.onEdit,
    required this.onPayment,
    required this.onMarkPaid,
    required this.onDelete,
    required this.showPaidActions,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime date) {
    return "${_months[date.month - 1]} ${date.day}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final status = debtStatus(debt);
    final remaining = debtRemaining(debt);
    final progress = debtProgress(debt);
    final overdue = isOverdue(debt, DateTime.now());

    final amount = (debt['amount'] as num?)?.toDouble() ?? 0;
    final paid = (debt['paidAmount'] as num?)?.toDouble() ?? 0;
    final direction = debt['direction'] as String? ?? 'owe';
    final isOwedToMe = direction == 'owed';
    final description = (debt['description'] as String?) ?? 'Untitled';
    final person = (debt['person'] as String?) ?? '';
    final dueDate = (debt['dueDate'] as Timestamp?)?.toDate();

    final statusLabel = status == 'paid'
        ? 'Paid'
        : status == 'partial'
            ? 'Partial'
            : 'Pending';
    final statusColor = status == 'paid'
        ? AppTheme.successGreen
        : status == 'partial'
            ? AppTheme.warningAmber
            : AppTheme.textMuted;

    final dueText = dueDate != null ? 'Due ${_formatDate(dueDate)}' : '';
    final subtitle = [person, dueText].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isOwedToMe
                          ? AppTheme.successGreen
                          : AppTheme.errorRed)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOwedToMe
                      ? Icons.south_west_rounded
                      : Icons.arrow_outward_rounded,
                  color: isOwedToMe
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (overdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "OVERDUE",
                              style: TextStyle(
                                color: AppTheme.errorRed,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(status == 'paid' ? amount : remaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: status == 'paid'
                          ? AppTheme.successGreen
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(
                        Icons.more_horiz,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'payment') onPayment();
                        if (value == 'edit') onEdit();
                        if (value == 'markPaid') onMarkPaid();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        if (showPaidActions) ...[
                          const PopupMenuItem(
                            value: 'payment',
                            child: Row(
                              children: [
                                Icon(Icons.payments_outlined,
                                    size: 16, color: AppTheme.textPrimary),
                                SizedBox(width: 8),
                                Text("Record payment",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'markPaid',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 16, color: AppTheme.successGreen),
                                SizedBox(width: 8),
                                Text(
                                  "Mark paid",
                                  style: TextStyle(
                                    color: AppTheme.successGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 16, color: AppTheme.textPrimary),
                              SizedBox(width: 8),
                              Text("Edit",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 16, color: AppTheme.errorRed),
                              SizedBox(width: 8),
                              Text(
                                "Delete",
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
          if (paid > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${formatCurrency(paid)} of ${formatCurrency(amount)} paid",
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
