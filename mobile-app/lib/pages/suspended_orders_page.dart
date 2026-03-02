import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_i18n.dart';
import '../models/cart_item.dart';
import '../models/suspended_order.dart';
import '../state/pos_controller.dart';

class SuspendedOrdersPage extends StatefulWidget {
  const SuspendedOrdersPage({
    super.key,
    required this.controller,
    required this.i18n,
  });

  final PosController controller;
  final AppI18n i18n;

  @override
  State<SuspendedOrdersPage> createState() => _SuspendedOrdersPageState();
}

class _SuspendedOrdersPageState extends State<SuspendedOrdersPage> {
  late final TextEditingController _searchController;
  String keyword = '';
  bool newestFirst = true;

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
            widget.controller.suspendedOrders
                .where((order) {
                  final key = keyword.trim().toLowerCase();
                  if (key.isEmpty) return true;
                  final label = (order.label ?? '').toLowerCase();
                  return order.ticketNo.toLowerCase().contains(key) ||
                      label.contains(key);
                })
                .toList(growable: false)
              ..sort(
                (a, b) => newestFirst
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt),
              );

        return Scaffold(
          appBar: AppBar(title: Text(i18n.resume)),
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
                            hintText: i18n.searchHint,
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
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            keyword = '';
                            newestFirst = true;
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
                      ? Center(child: Text(i18n.noSuspendedOrders))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final order = list[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE3EEF9),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.ticketNo,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${i18n.total}: ${i18n.formatMoney(order.total)} | ${order.itemCount}',
                                        ),
                                        Text(
                                          '${i18n.createdAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        if ((order.label ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            '${i18n.note}: ${order.label}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _openDetailsDialog(order.id),
                                    child: Text(i18n.details),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await widget.controller
                                          .restoreSuspendedCart(order.id);
                                      if (!context.mounted) return;
                                      Navigator.pop(context, true);
                                    },
                                    child: Text(i18n.resume),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final confirmed =
                                          await _confirmDeleteSuspended(order);
                                      if (confirmed != true) return;
                                      await widget.controller
                                          .deleteSuspendedCart(order.id);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    icon: const Icon(
                                      Icons.warning_amber_rounded,
                                    ),
                                    label: Text(i18n.clear),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetailsDialog(int suspendedId) async {
    final i18n = widget.i18n;
    final items = await widget.controller.loadSuspendedCartDetails(suspendedId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(i18n.details),
          content: SizedBox(
            width: 560,
            height: 420,
            child: items.isEmpty
                ? Center(child: Text(i18n.noSuspendedOrders))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 10),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _DetailRow(item: item, i18n: i18n);
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeleteSuspended(SuspendedOrder order) {
    final i18n = widget.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(i18n.clear),
          ],
        ),
        content: Text(
          '${t('确认删除挂单', 'ยืนยันการลบบิลพัก', 'Delete suspended order')} ${order.ticketNo}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(i18n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(i18n.confirm),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item, required this.i18n});

  final CartItem item;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    final optionsParts = <String>[
      if (item.sizeName.trim().isNotEmpty) item.sizeName,
      if (item.sugarName.trim().isNotEmpty) item.sugarName,
      if (item.iceName.trim().isNotEmpty) item.iceName,
    ];
    final toppings = item.toppings.isEmpty
        ? null
        : '${i18n.toppings}: ${item.toppings.map((e) => e.name).join(', ')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.product.localizedName(i18n.language.name)} x${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(i18n.formatMoney(item.subtotal)),
          ],
        ),
        const SizedBox(height: 2),
        if (optionsParts.isNotEmpty)
          Text(
            optionsParts.join(' | '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (toppings != null)
          Text(toppings, style: Theme.of(context).textTheme.bodySmall),
        if (item.note.trim().isNotEmpty)
          Text(
            '${i18n.note}: ${item.note}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
