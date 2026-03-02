import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_i18n.dart';
import '../models/cart_item.dart';
import '../models/order_detail.dart';
import '../models/product.dart';
import '../models/refundable_order_item.dart';
import '../services/receipt_print_service.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.controller,
    required this.i18n,
    required this.orderNo,
  });

  final PosController controller;
  final AppI18n i18n;
  final String orderNo;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<OrderDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.controller.loadOrderDetail(widget.orderNo);
  }

  void _reload() {
    setState(() {
      _detailFuture = widget.controller.loadOrderDetail(widget.orderNo);
    });
  }

  Future<void> _openRefundPage(OrderDetail detail) async {
    final i18n = widget.i18n;
    final amount = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => _OrderRefundPage(
          controller: widget.controller,
          i18n: i18n,
          orderNo: detail.orderNo,
        ),
      ),
    );
    if (!mounted || amount == null) return;
    try {
      await widget.controller.refreshSuspendAndOrders().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {}
    _reload();
    if (!mounted) return;
    showLatestSnackBar(context, '${i18n.refund}: ${i18n.formatMoney(amount)}');
  }

  Future<void> _openReceiptPreview(OrderDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReceiptPreviewPage(
          controller: widget.controller,
          i18n: widget.i18n,
          detail: detail,
          initialKind: _PreviewKind.receipt,
        ),
      ),
    );
  }

  Future<void> _openLabelPreview(OrderDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReceiptPreviewPage(
          controller: widget.controller,
          i18n: widget.i18n,
          detail: detail,
          initialKind: _PreviewKind.label,
        ),
      ),
    );
  }

  String _t(String zh, String th, String en) {
    return switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  Future<void> _deleteOrder(OrderDetail detail) async {
    final i18n = widget.i18n;
    if (!widget.controller.isAdmin) {
      showLatestSnackBar(context, i18n.permissionDenied);
      return;
    }
    final adminPin = await widget.controller.settingsStore.loadAdminPin();
    if (!mounted) return;
    var pinInput = '';
    String? errorText;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              _t('删除订单', 'ลบออเดอร์', 'Delete Order'),
              style: const TextStyle(color: Colors.red),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      '此操作不可恢复：${detail.orderNo}',
                      'การกระทำนี้ย้อนกลับไม่ได้: ${detail.orderNo}',
                      'This action cannot be undone: ${detail.orderNo}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => pinInput = value.trim(),
                    decoration: InputDecoration(
                      labelText: _t(
                        '请输入管理员PIN',
                        'กรุณาใส่ PIN ผู้ดูแล',
                        'Enter admin PIN',
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(i18n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  if (pinInput != adminPin) {
                    setState(() {
                      errorText = _t('PIN错误', 'PIN ไม่ถูกต้อง', 'Invalid PIN');
                    });
                    return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(_t('确认删除', 'ยืนยันการลบ', 'Confirm Delete')),
              ),
            ],
          ),
        );
      },
    );
    if (approved != true || !mounted) return;
    try {
      await widget.controller.deleteOrderByNo(detail.orderNo);
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t('订单已删除', 'ลบออเดอร์แล้ว', 'Order deleted'),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        '${_t('删除失败', 'ลบไม่สำเร็จ', 'Delete failed')}: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return Scaffold(
      appBar: AppBar(title: Text(i18n.orderDetails)),
      body: FutureBuilder<OrderDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(child: Text(i18n.noOrders));
          }
          final detail = snapshot.data!;
          final canRefund = detail.status != 'refunded';
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryCard(detail: detail, i18n: i18n),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openReceiptPreview(detail),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(i18n.previewReceipt),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openLabelPreview(detail),
                      icon: const Icon(Icons.local_offer_outlined),
                      label: Text(i18n.previewLabel),
                    ),
                    if (canRefund)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _openRefundPage(detail),
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: Text(i18n.refund),
                      ),
                    if (widget.controller.isAdmin)
                      OutlinedButton.icon(
                        onPressed: () => _deleteOrder(detail),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(_t('删除订单', 'ลบออเดอร์', 'Delete Order')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...detail.items.map((item) => _ItemCard(item: item, i18n: i18n)),
              if (detail.refundRecords.isNotEmpty) ...[
                const SizedBox(height: 10),
                _RefundRecordsCard(detail: detail, i18n: i18n),
              ],
            ],
          );
        },
      ),
    );
  }
}

List<CartItem> _buildReceiptItemsFromDetail(OrderDetail detail) {
  return detail.items
      .asMap()
      .entries
      .map((entry) {
        final index = entry.key;
        final item = entry.value;
        final toppingNames = item.toppings
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        final product = Product(
          id: -(index + 1),
          name: item.localizedName('zh'),
          category: '',
          price: item.unitPrice,
          nameZh: item.productNameZh,
          nameTh: item.productNameTh,
          nameEn: item.productNameEn,
        );
        return CartItem(
          product: product,
          quantity: item.quantity,
          sizeName: item.size,
          sugarName: item.sugar,
          iceName: item.ice,
          toppings: toppingNames
              .asMap()
              .entries
              .map(
                (t) => ToppingSelection(id: t.key + 1, name: t.value, price: 0),
              )
              .toList(growable: false),
          note: item.note,
        );
      })
      .toList(growable: false);
}

String _buildOrderDetailItemOptionsText(OrderDetailItem item, AppI18n i18n) {
  final parts = <String>[];
  if (item.size.trim().isNotEmpty) {
    parts.add('${i18n.size}:${item.size.trim()}');
  }
  if (item.sugar.trim().isNotEmpty) {
    parts.add('${i18n.sugar}:${item.sugar.trim()}');
  }
  if (item.ice.trim().isNotEmpty) {
    parts.add('${i18n.ice}:${item.ice.trim()}');
  }
  if (item.toppings.trim().isNotEmpty) {
    parts.add('${i18n.toppings}:${item.toppings.trim()}');
  }
  if (item.note.trim().isNotEmpty) {
    parts.add('${i18n.note}:${item.note.trim()}');
  }
  return parts.join(' | ');
}

enum _PreviewKind { receipt, label }

class _ReceiptPreviewPage extends StatefulWidget {
  const _ReceiptPreviewPage({
    required this.controller,
    required this.i18n,
    required this.detail,
    required this.initialKind,
  });

  final PosController controller;
  final AppI18n i18n;
  final OrderDetail detail;
  final _PreviewKind initialKind;

  @override
  State<_ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<_ReceiptPreviewPage> {
  int? _printingReceiptCopies;
  bool _isPrintingLabel = false;
  String _storeName = 'TEA STORE';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    final value = await widget.controller.settingsStore.loadStoreName();
    if (!mounted) return;
    setState(() => _storeName = value.trim().isEmpty ? 'TEA STORE' : value);
  }

  PaymentMethod _paymentMethodFromCode(String code) {
    return switch (code) {
      'cash' => PaymentMethod.cash,
      'wechat' => PaymentMethod.wechat,
      'alipay' => PaymentMethod.alipay,
      'promptPayQr' => PaymentMethod.promptPayQr,
      'trueMoneyQr' => PaymentMethod.trueMoneyQr,
      'card' => PaymentMethod.card,
      'deliveryApp' => PaymentMethod.deliveryApp,
      _ => PaymentMethod.cash,
    };
  }

  Future<void> _printReceiptCopies(int copies) async {
    if (_printingReceiptCopies != null) return;
    setState(() => _printingReceiptCopies = copies);
    final i18n = widget.i18n;
    final detail = widget.detail;
    try {
      final receiptIp = await widget.controller.settingsStore.loadPrinterIp();
      final labelIp = await widget.controller.settingsStore
          .loadLabelPrinterIp();
      final targetIp = (receiptIp ?? '').trim().isNotEmpty
          ? receiptIp!.trim()
          : (labelIp ?? '').trim();
      if (targetIp.isEmpty) {
        if (mounted) showLatestSnackBar(context, i18n.printerNotConfigured);
        return;
      }
      final orderType = detail.orderType == OrderType.delivery.name
          ? OrderType.delivery
          : OrderType.inStore;
      final items = _buildReceiptItemsFromDetail(detail);
      const service = ReceiptPrintService();
      await service.printReceiptCopies(
        storeName: await widget.controller.settingsStore.loadStoreName(),
        orderNo: detail.orderNo,
        pickupNo: detail.pickupNo,
        total: detail.total,
        method: _paymentMethodFromCode(detail.paymentMethod),
        orderType: orderType,
        orderChannel: detail.orderChannel,
        platformOrderId: detail.platformOrderId,
        items: items,
        cashReceived: detail.cashReceived,
        changeAmount: detail.changeAmount,
        createdAt: detail.createdAt,
        printerConfig: PrinterConnectionConfig(
          ip: targetIp,
          port: 0,
          enabled: true,
        ),
        printMode: await widget.controller.settingsStore.loadReceiptPrintMode(),
        bottomFeedLinesBeforeCut: await widget.controller.settingsStore
            .loadReceiptBottomFeedLines(),
        receiptCopies: copies,
      );
      if (!mounted) return;
      showLatestSnackBar(context, i18n.printReceiptSuccess);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${i18n.printReceiptFailed}: $e');
    } finally {
      if (mounted) setState(() => _printingReceiptCopies = null);
    }
  }

  Future<void> _printLabel() async {
    if (_isPrintingLabel) return;
    setState(() => _isPrintingLabel = true);
    final i18n = widget.i18n;
    final detail = widget.detail;
    try {
      final receiptIp = await widget.controller.settingsStore.loadPrinterIp();
      final labelIp = await widget.controller.settingsStore
          .loadLabelPrinterIp();
      final targetIp = (labelIp != null && labelIp.trim().isNotEmpty)
          ? labelIp.trim()
          : (receiptIp ?? '').trim();
      if (targetIp.isEmpty) {
        if (mounted) showLatestSnackBar(context, i18n.printerNotConfigured);
        return;
      }
      const service = ReceiptPrintService();
      await service.printDeliveryLabel(
        storeName: await widget.controller.settingsStore.loadStoreName(),
        orderNo: detail.orderNo,
        pickupNo: detail.pickupNo,
        orderChannel: detail.orderChannel,
        platformOrderId: detail.platformOrderId,
        items: _buildReceiptItemsFromDetail(detail),
        createdAt: detail.createdAt,
        printerConfig: PrinterConnectionConfig(
          ip: targetIp,
          port: 0,
          enabled: true,
        ),
        printMode: await widget.controller.settingsStore.loadReceiptPrintMode(),
        bottomFeedLinesBeforeCut: await widget.controller.settingsStore
            .loadLabelBottomFeedLines(),
      );
      if (!mounted) return;
      showLatestSnackBar(context, i18n.printReceiptSuccess);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${i18n.printReceiptFailed}: $e');
    } finally {
      if (mounted) setState(() => _isPrintingLabel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    const printI18n = AppI18n(AppLanguage.th);
    final detail = widget.detail;
    final isLabelPreview = widget.initialKind == _PreviewKind.label;
    final orderType = detail.orderType == OrderType.delivery.name
        ? OrderType.delivery
        : OrderType.inStore;
    final method = _paymentMethodFromCode(detail.paymentMethod);
    final subtotal = detail.items.fold<double>(
      0,
      (sum, e) => sum + e.lineTotal,
    );
    final combinedDiscount = subtotal - detail.total;
    final rows = isLabelPreview
        ? _buildLabelPreviewRows(
            detail: detail,
            i18n: printI18n,
            storeName: _storeName,
          )
        : <String>[
            _storeName,
            '${printI18n.pickupNo} ${detail.pickupNo}',
            '${printI18n.orderNo}: ${detail.orderNo}',
            '${printI18n.createdAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(detail.createdAt)}',
            '${printI18n.paymentMethod}: ${printI18n.paymentLabel(method)}',
            '${printI18n.orderType}: ${printI18n.orderTypeLabelByCode(orderType.name)}',
            if (orderType == OrderType.delivery &&
                detail.orderChannel.trim().isNotEmpty)
              '${printI18n.orderChannel}: ${detail.orderChannel}',
            if (orderType == OrderType.delivery &&
                detail.platformOrderId.trim().isNotEmpty)
              '${printI18n.platformOrderId}: ${detail.platformOrderId}',
            '--------------------------------',
            ...detail.items.expand((e) {
              final options = _buildOrderDetailItemOptionsText(e, printI18n);
              return <String>[
                '${e.localizedName(AppLanguage.th.name)} x${e.quantity}  ${printI18n.formatMoney(e.lineTotal)}',
                if (options.isNotEmpty) '  $options',
              ];
            }),
            '--------------------------------',
            '${printI18n.subtotal}: ${printI18n.formatMoney(subtotal)}',
            '${printI18n.discount}: ${combinedDiscount > 0 ? '-${printI18n.formatMoney(combinedDiscount)}' : printI18n.formatMoney(0)}',
            '${printI18n.total}: ${printI18n.formatMoney(detail.total)}',
            if (method == PaymentMethod.cash && detail.cashReceived != null)
              '${printI18n.cashReceived}: ${printI18n.formatMoney(detail.cashReceived!)}',
            if (method == PaymentMethod.cash && detail.changeAmount != null)
              '${printI18n.change}: ${printI18n.formatMoney(detail.changeAmount!)}',
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isLabelPreview ? i18n.labelPreview : i18n.receiptPreview),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasWidth = constraints.maxWidth;
                    final baseReceiptWidth = math
                        .min(math.max(220, canvasWidth - 24), 420.0)
                        .toDouble();
                    final paperWidth = isLabelPreview
                        ? baseReceiptWidth * 58 / 80
                        : baseReceiptWidth;
                    final paperLabel = isLabelPreview ? '58mm' : '80mm';
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE3EEF9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${isLabelPreview ? i18n.labelPreview : i18n.receiptPreview} · $paperLabel',
                            style: const TextStyle(
                              color: Color(0xFF607D8B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: paperWidth,
                                ),
                                child: CustomPaint(
                                  painter: const _DashedBorderPainter(
                                    color: Color(0xFFB0BEC5),
                                    strokeWidth: 1,
                                    dash: 6,
                                    gap: 4,
                                    radius: 10,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        rows.join('\n'),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          height: 1.4,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              if (isLabelPreview)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _isPrintingLabel ? null : _printLabel,
                      icon: _isPrintingLabel
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.local_print_shop_outlined),
                      label: Text(i18n.printLabel),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _printingReceiptCopies != null
                          ? null
                          : () => _printReceiptCopies(1),
                      icon: _printingReceiptCopies == 1
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(i18n.printReceiptOneCopy),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _printingReceiptCopies != null
                          ? null
                          : () => _printReceiptCopies(2),
                      icon: _printingReceiptCopies == 2
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(i18n.printReceiptTwoCopies),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _buildLabelPreviewRows({
  required OrderDetail detail,
  required AppI18n i18n,
  required String storeName,
}) {
  final expanded = <OrderDetailItem>[];
  for (final item in detail.items) {
    final qty = item.quantity < 1 ? 1 : item.quantity;
    for (var i = 0; i < qty; i++) {
      expanded.add(item);
    }
  }
  if (expanded.isEmpty) return <String>[storeName];

  final rows = <String>[];
  for (var i = 0; i < expanded.length; i++) {
    final item = expanded[i];
    rows.addAll([
      storeName,
      '${i18n.pickupNo}: ${detail.pickupNo} ${i + 1}/${expanded.length}',
      '${i18n.orderNo}: ${detail.orderNo}',
      if (detail.orderChannel.trim().isNotEmpty)
        '${i18n.orderChannel}: ${detail.orderChannel}',
      if (detail.platformOrderId.trim().isNotEmpty)
        '${i18n.platformOrderId}: ${detail.platformOrderId}',
      '${i18n.createdAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(detail.createdAt)}',
      '--------------------------------',
      item.localizedName(AppLanguage.th.name),
      ...() {
        final options = _buildOrderDetailItemOptionsText(item, i18n);
        if (options.isEmpty) return const <String>[];
        return <String>['  $options'];
      }(),
    ]);
    if (i < expanded.length - 1) {
      rows.addAll(const ['================================', '']);
    }
  }
  return rows;
}

class _OrderRefundPage extends StatefulWidget {
  const _OrderRefundPage({
    required this.controller,
    required this.i18n,
    required this.orderNo,
  });

  final PosController controller;
  final AppI18n i18n;
  final String orderNo;

  @override
  State<_OrderRefundPage> createState() => _OrderRefundPageState();
}

class _OrderRefundPageState extends State<_OrderRefundPage> {
  List<RefundableOrderItem> _items = const <RefundableOrderItem>[];
  String? _loadError;
  bool _loading = true;
  bool _isSubmitting = false;
  final Map<int, int> _selectedQty = <int, int>{};
  String _refundReason = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await widget.controller
          .loadRefundableOrderItems(widget.orderNo)
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = widget.i18n.loadTimeoutRetry;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    double refundTotal = 0;
    for (final item in _items) {
      final qty = _selectedQty[item.orderItemId] ?? 0;
      if (qty > 0) {
        refundTotal += item.lineAmount(qty);
      }
    }
    final canSubmitRefund = !_isSubmitting && !_loading && refundTotal > 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 6),
            Text('${i18n.refund} · ${widget.orderNo}'),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.refundableItems,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loadError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadItems,
                              child: Text(i18n.retry),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                    ? Center(child: Text(i18n.noPaidOrders))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var index = 0; index < _items.length; index++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Builder(
                                  builder: (_) {
                                    final item = _items[index];
                                    final selected =
                                        _selectedQty[item.orderItemId] ?? 0;
                                    final remain = item.remainingQuantity;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.productName),
                                              Text(
                                                '${i18n.remaining}: $remain · ${i18n.formatMoney(item.unitPrice)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: selected > 0
                                              ? () => setState(() {
                                                  _selectedQty[item
                                                          .orderItemId] =
                                                      selected - 1;
                                                })
                                              : null,
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text('$selected'),
                                        IconButton(
                                          onPressed: selected < remain
                                              ? () => setState(() {
                                                  _selectedQty[item
                                                          .orderItemId] =
                                                      selected + 1;
                                                })
                                              : null,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text('${i18n.refundTotal}: ${i18n.formatMoney(refundTotal)}'),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => _refundReason = value,
                decoration: InputDecoration(
                  labelText: i18n.reason,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(i18n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: canSubmitRefund
                          ? () => _submitRefund(i18n)
                          : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(i18n.refund),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<int, int> _selectedRefundQtyMap() {
    final pick = <int, int>{};
    _selectedQty.forEach((key, value) {
      if (value > 0) pick[key] = value;
    });
    return pick;
  }

  double _selectedRefundTotal(Map<int, int> pick) {
    double total = 0;
    for (final item in _items) {
      final qty = pick[item.orderItemId] ?? 0;
      if (qty > 0) {
        total += item.lineAmount(qty);
      }
    }
    return total;
  }

  Future<bool> _confirmRefund(
    AppI18n i18n,
    Map<int, int> pick,
    double amount,
  ) async {
    final selectedLines = _items
        .where((item) => (pick[item.orderItemId] ?? 0) > 0)
        .map((item) => '${item.productName} x${pick[item.orderItemId] ?? 0}')
        .toList(growable: false);
    final preview = selectedLines.take(6).join('\n');
    final hasMore = selectedLines.length > 6;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(i18n.refundConfirmTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n.refundConfirmHint),
            const SizedBox(height: 8),
            Text('${i18n.selectedItems}: ${selectedLines.length}'),
            Text('${i18n.refundTotal}: ${i18n.formatMoney(amount)}'),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(preview),
              if (hasMore) const Text('...'),
            ],
          ],
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
    return confirmed == true;
  }

  Future<void> _submitRefund(AppI18n i18n) async {
    final pick = _selectedRefundQtyMap();
    final amount = _selectedRefundTotal(pick);
    final confirmed = await _confirmRefund(i18n, pick, amount);
    if (!confirmed || !mounted) return;
    final navigator = Navigator.of(context);
    setState(() => _isSubmitting = true);
    try {
      final refundedAmount = await widget.controller
          .refundOrderItems(
            orderNo: widget.orderNo,
            reason: _refundReason.trim(),
            refundQtyByOrderItem: pick,
          )
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      navigator.pop(refundedAmount);
    } on TimeoutException {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      showLatestSnackBar(context, i18n.refundTimeoutRetry);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      showLatestSnackBar(context, '$e');
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail, required this.i18n});

  final OrderDetail detail;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3EEF9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.orderNo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _Line(
              label: i18n.createdAt,
              value: DateFormat('yyyy-MM-dd HH:mm').format(detail.createdAt),
            ),
            if (detail.pickupNo.trim().isNotEmpty)
              _Line(label: i18n.pickupNo, value: detail.pickupNo),
            _Line(
              label: i18n.orderType,
              value: i18n.orderTypeLabelByCode(detail.orderType),
            ),
            if (detail.orderType == 'delivery' &&
                detail.orderChannel.trim().isNotEmpty)
              _Line(label: i18n.orderChannel, value: detail.orderChannel),
            if (detail.orderType == 'delivery' &&
                detail.platformOrderId.trim().isNotEmpty)
              _Line(label: i18n.platformOrderId, value: detail.platformOrderId),
            _Line(
              label: i18n.status,
              value: i18n.orderStatusLabel(detail.status),
            ),
            _Line(
              label: i18n.paymentMethod,
              value: i18n.paymentLabelByCode(detail.paymentMethod),
            ),
            _Line(
              label: i18n.subtotal,
              value: i18n.formatMoney(detail.subtotal),
            ),
            if (detail.promoAmount > 0)
              _Line(
                label: i18n.activityDiscount,
                value: i18n.formatMoney(-detail.promoAmount),
              ),
            _Line(
              label: i18n.discount,
              value: i18n.formatMoney(-detail.discount),
            ),
            _Line(
              label: i18n.total,
              value: i18n.formatMoney(detail.total),
              bold: true,
            ),
            if (detail.cashReceived != null)
              _Line(
                label: i18n.cashReceived,
                value: i18n.formatMoney(detail.cashReceived!),
              ),
            if (detail.changeAmount != null)
              _Line(
                label: i18n.change,
                value: i18n.formatMoney(detail.changeAmount!),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.dash = 6,
    this.gap = 4,
    this.radius = 8,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.i18n});

  final OrderDetailItem item;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    final hasRefund = item.refundedQuantity > 0;
    final fullyRefunded = item.isFullyRefunded;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3EEF9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.productName} x${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (hasRefund) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fullyRefunded
                      ? const Color(0xFFECEFF1)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: fullyRefunded
                        ? const Color(0xFF90A4AE)
                        : const Color(0xFFF9A825),
                  ),
                ),
                child: Text(
                  fullyRefunded
                      ? '${i18n.refund}: ${item.refundedQuantity}/${item.quantity} · ${i18n.orderStatusLabel('refunded')}'
                      : '${i18n.refund}: ${item.refundedQuantity}/${item.quantity} · ${i18n.remaining}: ${item.remainingQuantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fullyRefunded
                        ? const Color(0xFF455A64)
                        : const Color(0xFFB26A00),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${i18n.size}: ${item.size} | ${i18n.sugar}: ${item.sugar} | ${i18n.ice}: ${item.ice}',
            ),
            if (item.toppings.trim().isNotEmpty)
              Text('${i18n.toppings}: ${item.toppings}'),
            if (item.note.trim().isNotEmpty) Text('${i18n.note}: ${item.note}'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${i18n.unitPrice}: ${i18n.formatMoney(item.unitPrice)}'),
                Text(
                  '${i18n.lineTotal}: ${i18n.formatMoney(item.lineTotal)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: fullyRefunded
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: fullyRefunded ? Colors.grey : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundRecordsCard extends StatelessWidget {
  const _RefundRecordsCard({required this.detail, required this.i18n});

  final OrderDetail detail;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3EEF9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.refundRecords,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...detail.refundRecords.map((record) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${i18n.refundAmount}: ${i18n.formatMoney(record.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(record.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${i18n.refundType}: ${i18n.refundTypeLabel(record.refundType)}',
                    ),
                    Text('${i18n.operatorName}: ${record.operatorName}'),
                    if (record.reason.trim().isNotEmpty)
                      Text('${i18n.reason}: ${record.reason}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
