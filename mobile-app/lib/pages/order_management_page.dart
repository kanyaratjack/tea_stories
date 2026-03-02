import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_i18n.dart';
import 'order_detail_page.dart';
import '../state/pos_controller.dart';

enum _OrderStatusFilter { all, paid, partiallyRefunded, refunded }

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({
    super.key,
    required this.controller,
    required this.i18n,
  });

  final PosController controller;
  final AppI18n i18n;

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  late final TextEditingController _searchController;
  String keyword = '';
  bool newestFirst = true;
  _OrderStatusFilter statusFilter = _OrderStatusFilter.all;

  String _t(String zh, String th, String en) {
    final lang = widget.controller.language;
    return switch (lang) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future<void>.microtask(widget.controller.refreshSuspendAndOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final list =
            widget.controller.recentPaidOrders
                .where((order) {
                  final key = keyword.trim().toLowerCase();
                  if (key.isEmpty) return true;
                  return order.orderNo.toLowerCase().contains(key) ||
                      order.pickupNo.toLowerCase().contains(key) ||
                      order.platformOrderId.toLowerCase().contains(key) ||
                      order.orderChannel.toLowerCase().contains(key);
                })
                .where((order) {
                  return switch (statusFilter) {
                    _OrderStatusFilter.all => true,
                    _OrderStatusFilter.paid => order.status == 'paid',
                    _OrderStatusFilter.partiallyRefunded =>
                      order.status == 'partially_refunded',
                    _OrderStatusFilter.refunded => order.status == 'refunded',
                  };
                })
                .toList(growable: false)
              ..sort(
                (a, b) => newestFirst
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt),
              );

        return Scaffold(
          appBar: AppBar(
            title: Text(i18n.orderManagement),
            actions: [
              IconButton(
                tooltip: i18n.retry,
                onPressed: widget.controller.refreshSuspendAndOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => keyword = value),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: i18n.searchOrderHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<bool>(
                          initialValue: newestFirst,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: true,
                              child: Text(i18n.sortNewest),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text(i18n.sortOldest),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => newestFirst = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<_OrderStatusFilter>(
                          initialValue: statusFilter,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: _OrderStatusFilter.all,
                              child: Text(i18n.allStatus),
                            ),
                            DropdownMenuItem(
                              value: _OrderStatusFilter.paid,
                              child: Text(i18n.orderStatusLabel('paid')),
                            ),
                            DropdownMenuItem(
                              value: _OrderStatusFilter.partiallyRefunded,
                              child: Text(
                                i18n.orderStatusLabel('partially_refunded'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: _OrderStatusFilter.refunded,
                              child: Text(i18n.orderStatusLabel('refunded')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => statusFilter = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            keyword = '';
                            newestFirst = true;
                            statusFilter = _OrderStatusFilter.all;
                          });
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: Text(i18n.reset),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(i18n.noOrders))
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: list.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final order = list[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFE3EEF9),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          _openOrderDetails(order.orderNo),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    order.orderNo,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${i18n.orderType}: ${i18n.orderTypeLabelByCode(order.orderType)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                  if (order.orderType ==
                                                          'delivery' &&
                                                      order.orderChannel
                                                          .trim()
                                                          .isNotEmpty)
                                                    Text(
                                                      '${i18n.orderChannel}: ${order.orderChannel}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  if (order.orderType ==
                                                          'delivery' &&
                                                      order.platformOrderId
                                                          .trim()
                                                          .isNotEmpty)
                                                    Text(
                                                      '${i18n.platformOrderId}: ${order.platformOrderId}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  if (order.refundedAmount > 0)
                                                    Text(
                                                      '${i18n.refundAmount}: ${i18n.formatMoney(order.refundedAmount)}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  Text(
                                                    '${i18n.createdAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  i18n.formatMoney(
                                                    order.actualAmount,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  alignment: WrapAlignment.end,
                                                  children: [
                                                    _OrderStatusChip(
                                                      label: i18n
                                                          .orderStatusLabel(
                                                            order.status,
                                                          ),
                                                      color: _statusColor(
                                                        order.status,
                                                      ),
                                                    ),
                                                    _OrderStatusChip(
                                                      label: _syncStateLabel(
                                                        widget.controller
                                                            .orderSyncStateOf(
                                                              order.orderNo,
                                                            ),
                                                      ),
                                                      color: _syncStateColor(
                                                        widget.controller
                                                            .orderSyncStateOf(
                                                              order.orderNo,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (widget.controller.hasMoreRecentPaidOrders)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed:
                                        widget
                                            .controller
                                            .isLoadingMoreRecentPaidOrders
                                        ? null
                                        : widget
                                              .controller
                                              .loadMoreRecentPaidOrders,
                                    child: Text(
                                      widget
                                              .controller
                                              .isLoadingMoreRecentPaidOrders
                                          ? i18n.loadingMore
                                          : i18n.loadMore,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Text(
                                  i18n.noMoreOrders,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_refunded':
        return const Color(0xFFF9A825);
      case 'refunded':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF1565C0);
    }
  }

  String _syncStateLabel(BackendSyncState state) {
    return switch (state) {
      BackendSyncState.unknown => _t('待同步', 'รอซิงก์', 'Pending sync'),
      BackendSyncState.pending => _t('同步中', 'กำลังซิงก์', 'Syncing'),
      BackendSyncState.synced => _t('已同步', 'ซิงก์แล้ว', 'Synced'),
      BackendSyncState.failed => _t('同步失败', 'ซิงก์ล้มเหลว', 'Sync failed'),
      BackendSyncState.disabled => _t(
        '未配置后台',
        'ยังไม่ตั้งค่า Backend',
        'Backend not set',
      ),
    };
  }

  Color _syncStateColor(BackendSyncState state) {
    return switch (state) {
      BackendSyncState.synced => const Color(0xFF2E7D32),
      BackendSyncState.failed => const Color(0xFFC62828),
      BackendSyncState.disabled => const Color(0xFF757575),
      BackendSyncState.pending => const Color(0xFF1565C0),
      BackendSyncState.unknown => const Color(0xFFF9A825),
    };
  }

  Future<void> _openOrderDetails(String orderNo) async {
    final i18n = widget.i18n;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          controller: widget.controller,
          i18n: i18n,
          orderNo: orderNo,
        ),
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
