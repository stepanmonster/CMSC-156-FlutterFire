import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../components/add_item_modal.dart';
import '../components/app_snackbar.dart';
import '../components/shimmer_loading.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/period_filter.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final FirestoreService _db = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  PeriodScale _scale = PeriodScale.month;
  DateTime _anchor = DateTime.now();

  static const _scaleLabels = {
    PeriodScale.day: 'Day',
    PeriodScale.week: 'Week',
    PeriodScale.month: 'Month',
    PeriodScale.all: 'All',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 500;
      if (show != _showScrollToTop) {
        setState(() => _showScrollToTop = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildPeriodHeader(),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.getItemStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
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
                          Text(
                            "Pull down to retry",
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const ShimmerList();
                  }

                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppTheme.borderLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.borderLight.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "No expenses yet",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Every peso tracked builds better habits.\nTap the button below to log your first one.",
                            textAlign: TextAlign.center,
                            style: AppTheme.caption.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    );
                  }

                  final now = DateTime.now();
                  final range = periodRange(_scale, _anchor);
                  final filtered = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final date = (data['userDate'] as Timestamp?)?.toDate() ??
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        now;
                    if (range == null) return true;
                    return !date.isBefore(range.start) && date.isBefore(range.end);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
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
                            "No expenses for ${formatPeriodLabel(_scale, _anchor)}",
                            style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Try a different period.",
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    );
                  }

                  double totalShown = filtered.fold(0, (total, d) {
                    final data = d.data() as Map<String, dynamic>;
                    return total + ((data['itemPrice'] as num?)?.toDouble() ?? 0);
                  });

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      key: ValueKey('${_scale.name}-${formatPeriodLabel(_scale, _anchor)}'),
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${filtered.length} expense${filtered.length != 1 ? 's' : ''}",
                                style: AppTheme.caption,
                              ),
                              Text(
                                formatCurrency(totalShown),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {},
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final doc = filtered[i];
                                final data = doc.data() as Map<String, dynamic>;
                                final docId = doc.id;
                                final String name = data['itemName'] ?? 'Unnamed Item';
                                final int price = data['itemPrice'] ?? 0;
                                final DateTime displayDate = (data['userDate'] as Timestamp?)?.toDate() ??
                                    (data['timestamp'] as Timestamp?)?.toDate() ??
                                    now;

                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(milliseconds: 300 + (i * 50).clamp(0, 300)),
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
                                  child: _ExpenseCard(
                                    name: name,
                                    price: price,
                                    date: displayDate,
                                    onEdit: () => _showEditModal(context, docId, name, price),
                                    onDelete: () => _confirmDelete(context, docId),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        if (_showScrollToTop)
          Positioned(
            right: 16,
            bottom: 16,
            child: AnimatedSlide(
              offset: _showScrollToTop ? Offset.zero : const Offset(0, 3),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  backgroundColor: AppTheme.surfaceDark,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _shiftPeriod(int direction) {
    HapticFeedback.lightImpact();
    setState(() => _anchor = shiftPeriod(_scale, _anchor, direction));
  }

  Widget _buildPeriodButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderLight, width: 1.5),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.surfaceDark : AppTheme.textMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    final showNav = _scale != PeriodScale.all;
    final canForward = showNav && canShiftPeriod(_scale, _anchor, DateTime.now(), 1);
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              showNav
                  ? _buildPeriodButton(
                      Icons.chevron_left_rounded,
                      enabled: true,
                      onTap: () => _shiftPeriod(-1),
                    )
                  : const SizedBox(width: 36, height: 36),
              Expanded(
                child: Text(
                  formatPeriodLabel(_scale, _anchor),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              showNav
                  ? _buildPeriodButton(
                      Icons.chevron_right_rounded,
                      enabled: canForward,
                      onTap: () => _shiftPeriod(1),
                    )
                  : const SizedBox(width: 36, height: 36),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _scaleLabels.entries.map((entry) {
                final isSelected = _scale == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _scale = entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 20 : 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.surfaceDark : AppTheme.borderLight,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
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
        ],
      ),
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

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: const Text(
          "Delete expense?",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          "This action cannot be undone.",
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
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
                await _db.deleteItem(docId);
                if (!context.mounted) return;
                AppSnackbar.show(context, "Expense deleted", isError: false);
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(price.toDouble()),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: Icon(
                    Icons.more_horiz,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                    if (value == 'edit') onEdit();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppTheme.textPrimary),
                          SizedBox(width: 8),
                          Text("Edit", style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorRed),
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
    );
  }
}
