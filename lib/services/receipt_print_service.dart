import 'dart:io';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../l10n/app_i18n.dart';
import '../models/cart_item.dart';
import '../state/pos_controller.dart';

enum ReceiptPrintMode { text, bitmap }

class PrinterConnectionConfig {
  const PrinterConnectionConfig({
    required this.ip,
    this.port = 0,
    this.enabled = false,
  });

  final String ip;
  final int port;
  final bool enabled;

  bool get isValid =>
      enabled &&
      ip.trim().isNotEmpty &&
      (port == 0 || (port > 0 && port <= 65535)) &&
      !kIsWeb;
}

class ReceiptPrintService {
  const ReceiptPrintService();
  static const _defaultStoreName = 'TEA STORE';
  static const _defaultBottomFeedLinesBeforeCut = 6;
  static const _defaultLabelBottomFeedLinesBeforeCut = 6;
  static const _receiptLanguage = AppLanguage.th;
  static const _thaiCodeTableId = 47;
  static const _thaiInternationalSetId = 13;
  static const List<int?> _thaiProbeCodeTables = [
    47,
    21,
    26,
    30,
    33,
    20,
    255,
    null,
  ];
  static const bool _enableEscPosDebugLog = false;

  static int sanitizeBottomFeedLines(int value) {
    if (value < 0) return 0;
    if (value > 12) return 12;
    return value;
  }

  static int sanitizeReceiptCopies(int value) {
    if (value < 0) return 0;
    if (value > 5) return 5;
    return value;
  }

  static String sanitizeStoreName(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? _defaultStoreName : v;
  }

  Future<void> printNetworkTest({
    required PrinterConnectionConfig config,
  }) async {
    final socket = await _connectSocket(config);
    try {
      final now = DateTime.now();
      final bytes = <int>[
        0x1B,
        0x40, // reset
        ..._asciiLine('TEST PRINT'),
        ..._asciiLine(
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        ),
        ..._asciiLine('IP ${config.ip.trim()}'),
        0x0A,
        0x1D,
        0x56,
        0x00, // cut
      ];
      _debugDumpEscPosBytes('printNetworkTest', bytes);
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } finally {
      await socket.close();
    }
  }

  Future<void> openCashDrawer({required PrinterConnectionConfig config}) async {
    final socket = await _connectSocket(config);
    try {
      // ESC p m t1 t2
      // Different printers/wiring may require different m/pulse values.
      // Send several safe variants for compatibility.
      final bytes = <int>[
        0x1B, 0x40, // ESC @ reset
        0x1B, 0x70, 0x00, 0x19, 0xFA, // pin 2, short pulse
        0x1B, 0x70, 0x00, 0x32, 0x32, // pin 2, common pulse
        0x1B, 0x70, 0x01, 0x19, 0xFA, // pin 5, short pulse
        0x1B, 0x70, 0x01, 0x32, 0x32, // pin 5, common pulse
      ];
      _debugDumpEscPosBytes('openCashDrawer', bytes);
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    } finally {
      await socket.close();
    }
  }

  Future<void> printCheckoutReceipt({
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    String platformOrderId = '',
    required List<CartItem> items,
    double? cashReceived,
    double? changeAmount,
    DateTime? createdAt,
    PrinterConnectionConfig? printerConfig,
    PrinterConnectionConfig? labelPrinterConfig,
    ReceiptPrintMode printMode = ReceiptPrintMode.bitmap,
    int bottomFeedLinesBeforeCut = _defaultBottomFeedLinesBeforeCut,
    int labelBottomFeedLinesBeforeCut = _defaultLabelBottomFeedLinesBeforeCut,
    int receiptCopies = 1,
    bool includeDeliveryLabel = false,
  }) async {
    if (printerConfig == null || !printerConfig.isValid) {
      throw StateError('Printer is not configured or unavailable.');
    }
    final resolvedLabelPrinterConfig =
        (labelPrinterConfig != null && labelPrinterConfig.isValid)
        ? labelPrinterConfig
        : printerConfig;

    final safeStoreName = sanitizeStoreName(storeName);
    final safeBottomLines = sanitizeBottomFeedLines(bottomFeedLinesBeforeCut);
    final safeLabelBottomLines = sanitizeBottomFeedLines(
      labelBottomFeedLinesBeforeCut,
    );
    final safeCopies = sanitizeReceiptCopies(receiptCopies);

    if (safeCopies > 0) {
      await printReceiptCopies(
        storeName: safeStoreName,
        orderNo: orderNo,
        pickupNo: pickupNo,
        total: total,
        method: method,
        orderType: orderType,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
        items: items,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        createdAt: createdAt,
        printerConfig: printerConfig,
        printMode: printMode,
        bottomFeedLinesBeforeCut: safeBottomLines,
        receiptCopies: safeCopies,
      );
    }

    if (includeDeliveryLabel) {
      await printDeliveryLabel(
        storeName: safeStoreName,
        orderNo: orderNo,
        pickupNo: pickupNo,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
        items: items,
        createdAt: createdAt,
        printerConfig: resolvedLabelPrinterConfig,
        printMode: printMode,
        bottomFeedLinesBeforeCut: safeLabelBottomLines,
      );
    }
  }

  Future<void> printReceiptCopies({
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    String platformOrderId = '',
    required List<CartItem> items,
    double? cashReceived,
    double? changeAmount,
    DateTime? createdAt,
    required PrinterConnectionConfig printerConfig,
    ReceiptPrintMode printMode = ReceiptPrintMode.bitmap,
    int bottomFeedLinesBeforeCut = _defaultBottomFeedLinesBeforeCut,
    int receiptCopies = 1,
  }) async {
    const receiptI18n = AppI18n(_receiptLanguage);
    if (!printerConfig.isValid) {
      throw StateError('Receipt printer is not configured or unavailable.');
    }
    final safeStoreName = sanitizeStoreName(storeName);
    final safeBottomLines = sanitizeBottomFeedLines(bottomFeedLinesBeforeCut);
    final safeCopies = sanitizeReceiptCopies(receiptCopies);
    if (safeCopies <= 0) return;
    if (printMode == ReceiptPrintMode.bitmap) {
      final socket = await _connectSocket(printerConfig);
      try {
        await _printViaRasterCopies(
          socket: socket,
          copies: safeCopies,
          i18n: receiptI18n,
          storeName: safeStoreName,
          orderNo: orderNo,
          pickupNo: pickupNo,
          total: total,
          method: method,
          orderType: orderType,
          orderChannel: orderChannel,
          platformOrderId: platformOrderId,
          items: items,
          cashReceived: cashReceived,
          changeAmount: changeAmount,
          createdAt: createdAt,
          bottomFeedLinesBeforeCut: safeBottomLines,
        );
      } finally {
        await socket.close();
      }
      return;
    }
    for (var i = 0; i < safeCopies; i++) {
      await _printTextViaEscPos(
        i18n: receiptI18n,
        storeName: safeStoreName,
        orderNo: orderNo,
        pickupNo: pickupNo,
        total: total,
        method: method,
        orderType: orderType,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
        items: items,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        createdAt: createdAt,
        config: printerConfig,
        printMode: printMode,
        bottomFeedLinesBeforeCut: safeBottomLines,
      );
      if (i < safeCopies - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
  }

  Future<void> _printViaRasterCopies({
    required Socket socket,
    required int copies,
    required AppI18n i18n,
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    required String platformOrderId,
    required List<CartItem> items,
    required double? cashReceived,
    required double? changeAmount,
    required DateTime? createdAt,
    required int bottomFeedLinesBeforeCut,
  }) async {
    final now = createdAt ?? DateTime.now();
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final discount = subtotal - total;

    final lines = <String>[
      storeName,
      '${i18n.pickupNo} $pickupNo',
      '${i18n.orderNo}: $orderNo',
      '${i18n.createdAt}: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      '${i18n.paymentMethod}: ${i18n.paymentLabel(method)}',
      '${i18n.orderType}: ${i18n.orderTypeLabelByCode(orderType.name)}',
      if (orderType == OrderType.delivery && orderChannel.trim().isNotEmpty)
        '${i18n.orderChannel}: $orderChannel',
      if (orderType == OrderType.delivery && platformOrderId.trim().isNotEmpty)
        '${i18n.platformOrderId}: $platformOrderId',
      '--------------------------------',
    ];

    for (final item in items) {
      final name = item.product.localizedName(_receiptLanguage.name);
      lines.add('$name x${item.quantity}  ${i18n.formatMoney(item.subtotal)}');
      final options = _buildOptionsText(item, i18n);
      if (options.isNotEmpty) {
        lines.add('  $options');
      }
    }

    lines.addAll([
      '--------------------------------',
      '${i18n.subtotal}: ${i18n.formatMoney(subtotal)}',
      '${i18n.discount}: ${discount > 0 ? '-${i18n.formatMoney(discount)}' : i18n.formatMoney(0)}',
      '${i18n.total}: ${i18n.formatMoney(total)}',
      if (method == PaymentMethod.cash && cashReceived != null)
        '${i18n.cashReceived}: ${i18n.formatMoney(cashReceived)}',
      if (method == PaymentMethod.cash && changeAmount != null)
        '${i18n.change}: ${i18n.formatMoney(changeAmount)}',
    ]);

    final png = await _renderReceiptPng(lines);
    final raster = img.decodePng(png);
    if (raster == null) {
      throw StateError('Unable to decode rendered receipt image.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];
    bytes.addAll(generator.reset());
    for (var i = 0; i < copies; i++) {
      bytes.addAll(generator.imageRaster(raster, align: PosAlign.left));
      bytes.addAll(generator.feed(bottomFeedLinesBeforeCut));
      bytes.addAll([0x1D, 0x56, 0x00]);
    }
    _debugDumpEscPosBytes('printViaRasterCopies', bytes);
    socket.add(bytes);
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> printDeliveryLabel({
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required String orderChannel,
    String platformOrderId = '',
    required List<CartItem> items,
    DateTime? createdAt,
    required PrinterConnectionConfig printerConfig,
    ReceiptPrintMode printMode = ReceiptPrintMode.bitmap,
    int bottomFeedLinesBeforeCut = _defaultLabelBottomFeedLinesBeforeCut,
  }) async {
    const receiptI18n = AppI18n(_receiptLanguage);
    if (!printerConfig.isValid) {
      throw StateError('Label printer is not configured or unavailable.');
    }
    await _printDeliveryLabel(
      i18n: receiptI18n,
      storeName: sanitizeStoreName(storeName),
      orderNo: orderNo,
      pickupNo: pickupNo,
      orderChannel: orderChannel,
      platformOrderId: platformOrderId,
      items: items,
      createdAt: createdAt,
      config: printerConfig,
      printMode: printMode,
      bottomFeedLinesBeforeCut: sanitizeBottomFeedLines(
        bottomFeedLinesBeforeCut,
      ),
    );
  }

  Future<void> _printTextViaEscPos({
    required AppI18n i18n,
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    required String platformOrderId,
    required List<CartItem> items,
    required PrinterConnectionConfig config,
    required ReceiptPrintMode printMode,
    required int bottomFeedLinesBeforeCut,
    double? cashReceived,
    double? changeAmount,
    DateTime? createdAt,
  }) async {
    final socket = await _connectSocket(config);
    try {
      if (printMode == ReceiptPrintMode.bitmap) {
        await _printViaRaster(
          socket: socket,
          i18n: i18n,
          storeName: storeName,
          orderNo: orderNo,
          pickupNo: pickupNo,
          total: total,
          method: method,
          orderType: orderType,
          orderChannel: orderChannel,
          platformOrderId: platformOrderId,
          items: items,
          cashReceived: cashReceived,
          changeAmount: changeAmount,
          createdAt: createdAt,
          bottomFeedLinesBeforeCut: bottomFeedLinesBeforeCut,
        );
        return;
      }

      final receiptI18n = i18n;
      final isChinese = _receiptLanguage == AppLanguage.zh;
      final encode = _encodeCp874;
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final stylesNormal = const PosStyles();
      final stylesCenter = const PosStyles(align: PosAlign.center);
      final stylesPickup = const PosStyles(
        align: PosAlign.center,
        bold: true,
        width: PosTextSize.size2,
        height: PosTextSize.size2,
      );
      final now = createdAt ?? DateTime.now();
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final discount = subtotal - total;

      final bytes = <int>[];
      void addLine(String text, {PosStyles styles = const PosStyles()}) {
        if (isChinese) {
          bytes.addAll(
            generator.text(
              text,
              styles: styles,
              containsChinese: true,
              linesAfter: 0,
            ),
          );
        } else {
          bytes.addAll(
            generator.textEncoded(encode(text), styles: styles, linesAfter: 0),
          );
        }
      }

      bytes.addAll(generator.reset());
      bytes.addAll([0x1C, 0x2E]); // FS . : cancel Kanji/double-byte mode
      if (isChinese) {
        // Do not force a missing profile code table (e.g. CP936 may be absent).
        // Chinese path uses containsChinese=true and library's GBK encoding path.
      } else {
        bytes.addAll([0x1B, 0x52, _thaiInternationalSetId]);
        bytes.addAll([0x1B, 0x74, _thaiCodeTableId]);
      }
      addLine(storeName, styles: stylesCenter);
      addLine('${receiptI18n.pickupNo} $pickupNo', styles: stylesPickup);
      addLine('${receiptI18n.orderNo}: $orderNo', styles: stylesNormal);
      addLine(
        '${receiptI18n.createdAt}: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        styles: stylesNormal,
      );
      addLine(
        '${receiptI18n.paymentMethod}: ${receiptI18n.paymentLabel(method)}',
        styles: stylesNormal,
      );
      addLine(
        '${receiptI18n.orderType}: ${receiptI18n.orderTypeLabelByCode(orderType.name)}',
        styles: stylesNormal,
      );
      if (orderType == OrderType.delivery && orderChannel.trim().isNotEmpty) {
        addLine(
          '${receiptI18n.orderChannel}: $orderChannel',
          styles: stylesNormal,
        );
      }
      if (orderType == OrderType.delivery &&
          platformOrderId.trim().isNotEmpty) {
        addLine(
          '${receiptI18n.platformOrderId}: $platformOrderId',
          styles: stylesNormal,
        );
      }
      bytes.addAll(generator.hr(ch: '-', linesAfter: 0));

      for (final item in items) {
        final name = item.product.localizedName(_receiptLanguage.name);
        final lineTotal = receiptI18n.formatMoney(item.subtotal);
        if (isChinese) {
          addLine('$name x${item.quantity}  $lineTotal', styles: stylesNormal);
        } else {
          bytes.addAll(
            generator.row([
              PosColumn(
                textEncoded: encode('$name x${item.quantity}'),
                width: 8,
                styles: stylesNormal,
              ),
              PosColumn(
                textEncoded: encode(lineTotal),
                width: 4,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]),
          );
        }
        final options = _buildOptionsText(item, receiptI18n);
        if (options.isNotEmpty) {
          addLine('  $options', styles: stylesNormal);
        }
      }

      bytes.addAll(generator.hr(ch: '-', linesAfter: 0));
      if (isChinese) {
        addLine(
          '${receiptI18n.subtotal}: ${receiptI18n.formatMoney(subtotal)}',
          styles: stylesNormal,
        );
        addLine(
          '${receiptI18n.discount}: ${discount > 0 ? '-${receiptI18n.formatMoney(discount)}' : receiptI18n.formatMoney(0)}',
          styles: stylesNormal,
        );
        addLine(
          '${receiptI18n.total}: ${receiptI18n.formatMoney(total)}',
          styles: const PosStyles(
            bold: true,
            width: PosTextSize.size2,
            height: PosTextSize.size2,
          ),
        );
      } else {
        bytes.addAll(
          generator.row([
            PosColumn(
              textEncoded: encode(receiptI18n.subtotal),
              width: 8,
              styles: stylesNormal,
            ),
            PosColumn(
              textEncoded: encode(receiptI18n.formatMoney(subtotal)),
              width: 4,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]),
        );
        bytes.addAll(
          generator.row([
            PosColumn(
              textEncoded: encode(receiptI18n.discount),
              width: 8,
              styles: stylesNormal,
            ),
            PosColumn(
              textEncoded: encode(
                discount > 0
                    ? '-${receiptI18n.formatMoney(discount)}'
                    : receiptI18n.formatMoney(0),
              ),
              width: 4,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]),
        );
        bytes.addAll(
          generator.row([
            PosColumn(
              textEncoded: encode(receiptI18n.total),
              width: 8,
              styles: const PosStyles(
                bold: true,
                width: PosTextSize.size2,
                height: PosTextSize.size2,
              ),
            ),
            PosColumn(
              textEncoded: encode(receiptI18n.formatMoney(total)),
              width: 4,
              styles: const PosStyles(
                align: PosAlign.right,
                bold: true,
                width: PosTextSize.size2,
                height: PosTextSize.size2,
              ),
            ),
          ]),
        );
      }
      if (method == PaymentMethod.cash && cashReceived != null) {
        if (isChinese) {
          addLine(
            '${receiptI18n.cashReceived}: ${receiptI18n.formatMoney(cashReceived)}',
            styles: stylesNormal,
          );
        } else {
          bytes.addAll(
            generator.row([
              PosColumn(
                textEncoded: encode(receiptI18n.cashReceived),
                width: 8,
                styles: stylesNormal,
              ),
              PosColumn(
                textEncoded: encode(receiptI18n.formatMoney(cashReceived)),
                width: 4,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]),
          );
        }
      }
      if (method == PaymentMethod.cash && changeAmount != null) {
        if (isChinese) {
          addLine(
            '${receiptI18n.change}: ${receiptI18n.formatMoney(changeAmount)}',
            styles: stylesNormal,
          );
        } else {
          bytes.addAll(
            generator.row([
              PosColumn(
                textEncoded: encode(receiptI18n.change),
                width: 8,
                styles: stylesNormal,
              ),
              PosColumn(
                textEncoded: encode(receiptI18n.formatMoney(changeAmount)),
                width: 4,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]),
          );
        }
      }

      // Cut without extra 5 blank lines from generator.cut().
      bytes.addAll(generator.feed(bottomFeedLinesBeforeCut));
      bytes.addAll([0x1D, 0x56, 0x00]);
      _debugDumpEscPosBytes('printCheckoutReceipt', bytes);
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      await socket.close();
    }
  }

  Future<void> _printViaRaster({
    required Socket socket,
    required AppI18n i18n,
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    required String platformOrderId,
    required List<CartItem> items,
    required double? cashReceived,
    required double? changeAmount,
    required DateTime? createdAt,
    required int bottomFeedLinesBeforeCut,
  }) async {
    final now = createdAt ?? DateTime.now();
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final discount = subtotal - total;

    final lines = <String>[
      storeName,
      '${i18n.pickupNo} $pickupNo',
      '${i18n.orderNo}: $orderNo',
      '${i18n.createdAt}: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      '${i18n.paymentMethod}: ${i18n.paymentLabel(method)}',
      '${i18n.orderType}: ${i18n.orderTypeLabelByCode(orderType.name)}',
      if (orderType == OrderType.delivery && orderChannel.trim().isNotEmpty)
        '${i18n.orderChannel}: $orderChannel',
      if (orderType == OrderType.delivery && platformOrderId.trim().isNotEmpty)
        '${i18n.platformOrderId}: $platformOrderId',
      '--------------------------------',
    ];

    for (final item in items) {
      final name = item.product.localizedName(_receiptLanguage.name);
      lines.add('$name x${item.quantity}  ${i18n.formatMoney(item.subtotal)}');
      final options = _buildOptionsText(item, i18n);
      if (options.isNotEmpty) {
        lines.add('  $options');
      }
    }

    lines.addAll([
      '--------------------------------',
      '${i18n.subtotal}: ${i18n.formatMoney(subtotal)}',
      '${i18n.discount}: ${discount > 0 ? '-${i18n.formatMoney(discount)}' : i18n.formatMoney(0)}',
      '${i18n.total}: ${i18n.formatMoney(total)}',
      if (method == PaymentMethod.cash && cashReceived != null)
        '${i18n.cashReceived}: ${i18n.formatMoney(cashReceived)}',
      if (method == PaymentMethod.cash && changeAmount != null)
        '${i18n.change}: ${i18n.formatMoney(changeAmount)}',
    ]);

    final png = await _renderReceiptPng(lines);
    final raster = img.decodePng(png);
    if (raster == null) {
      throw StateError('Unable to decode rendered receipt image.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.imageRaster(raster, align: PosAlign.left));
    bytes.addAll(generator.feed(bottomFeedLinesBeforeCut));
    bytes.addAll([0x1D, 0x56, 0x00]);
    _debugDumpEscPosBytes('printThaiViaRaster', bytes);
    socket.add(bytes);
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _printDeliveryLabel({
    required AppI18n i18n,
    required String storeName,
    required String orderNo,
    required String pickupNo,
    required String orderChannel,
    required String platformOrderId,
    required List<CartItem> items,
    required DateTime? createdAt,
    required PrinterConnectionConfig config,
    required ReceiptPrintMode printMode,
    required int bottomFeedLinesBeforeCut,
  }) async {
    final socket = await _connectSocket(config);
    try {
      final cupItems = _expandLabelCupItems(items);
      if (cupItems.isEmpty) return;
      final totalCups = cupItems.length;
      final now = createdAt ?? DateTime.now();

      if (printMode == ReceiptPrintMode.bitmap) {
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm58, profile);
        for (var i = 0; i < totalCups; i++) {
          final item = cupItems[i];
          final lines = <String>[
            storeName,
            '${i18n.pickupNo}: $pickupNo ${i + 1}/$totalCups',
            '${i18n.orderNo}: $orderNo',
            if (orderChannel.trim().isNotEmpty)
              '${i18n.orderChannel}: $orderChannel',
            if (platformOrderId.trim().isNotEmpty)
              '${i18n.platformOrderId}: $platformOrderId',
            '${i18n.createdAt}: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            '------------------------------',
            item.product.localizedName(_receiptLanguage.name),
            ...() {
              final options = _buildOptionsText(item, i18n);
              if (options.isEmpty) return const <String>[];
              return <String>['  $options'];
            }(),
          ];
          final png = await _renderReceiptPng(
            lines,
            receiptWidth: 384,
            horizontalPadding: 10,
            verticalPadding: 10,
            fontSize: 22,
            lineSpacing: 1.2,
          );
          final raster = img.decodePng(png);
          if (raster == null) {
            throw StateError('Unable to decode rendered label image.');
          }
          final bytes = <int>[];
          bytes.addAll(generator.reset());
          bytes.addAll(generator.imageRaster(raster, align: PosAlign.left));
          bytes.addAll(generator.feed(bottomFeedLinesBeforeCut));
          bytes.addAll([0x1D, 0x56, 0x00]);
          socket.add(bytes);
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
        return;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final encode = _encodeCp874;
      for (var i = 0; i < totalCups; i++) {
        final item = cupItems[i];
        final bytes = <int>[];
        bytes.addAll(generator.reset());
        bytes.addAll([0x1B, 0x52, _thaiInternationalSetId]);
        bytes.addAll([0x1B, 0x74, _thaiCodeTableId]);
        bytes.addAll(
          generator.textEncoded(
            encode(storeName),
            styles: const PosStyles(align: PosAlign.center, bold: true),
            linesAfter: 0,
          ),
        );
        bytes.addAll(
          generator.textEncoded(
            encode('${i18n.pickupNo}: $pickupNo ${i + 1}/$totalCups'),
            linesAfter: 0,
          ),
        );
        bytes.addAll(
          generator.textEncoded(
            encode('${i18n.orderNo}: $orderNo'),
            linesAfter: 0,
          ),
        );
        if (orderChannel.trim().isNotEmpty) {
          bytes.addAll(
            generator.textEncoded(
              encode('${i18n.orderChannel}: $orderChannel'),
            ),
          );
        }
        if (platformOrderId.trim().isNotEmpty) {
          bytes.addAll(
            generator.textEncoded(
              encode('${i18n.platformOrderId}: $platformOrderId'),
            ),
          );
        }
        bytes.addAll(generator.hr(ch: '-', linesAfter: 0));
        bytes.addAll(
          generator.textEncoded(
            encode(item.product.localizedName(_receiptLanguage.name)),
            linesAfter: 0,
          ),
        );
        final options = _buildOptionsText(item, i18n);
        if (options.isNotEmpty) {
          bytes.addAll(
            generator.textEncoded(encode('  $options'), linesAfter: 0),
          );
        }
        bytes.addAll(generator.feed(bottomFeedLinesBeforeCut));
        bytes.addAll([0x1D, 0x56, 0x00]);
        socket.add(bytes);
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    } finally {
      await socket.close();
    }
  }

  List<CartItem> _expandLabelCupItems(List<CartItem> items) {
    final cups = <CartItem>[];
    for (final item in items) {
      final count = item.quantity < 1 ? 1 : item.quantity;
      for (var i = 0; i < count; i++) {
        cups.add(item);
      }
    }
    return cups;
  }

  Future<Uint8List> _renderReceiptPng(
    List<String> lines, {
    double receiptWidth = 560.0,
    double horizontalPadding = 12.0,
    double verticalPadding = 10.0,
    double fontSize = 27.0,
    double lineSpacing = 1.25,
  }) async {
    final textPainters = <TextPainter>[];
    double totalHeight = verticalPadding;
    for (final text in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: receiptWidth - horizontalPadding * 2);
      textPainters.add(painter);
      totalHeight += painter.height * lineSpacing;
    }
    totalHeight += verticalPadding;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintBg = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, receiptWidth, totalHeight), paintBg);

    double y = verticalPadding;
    for (final painter in textPainters) {
      painter.paint(canvas, Offset(horizontalPadding, y));
      y += painter.height * lineSpacing;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      receiptWidth.toInt(),
      totalHeight.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Unable to render receipt image bytes.');
    }
    return data.buffer.asUint8List();
  }

  Future<void> printThaiCodePageProbe({
    required PrinterConnectionConfig config,
  }) async {
    final socket = await _connectSocket(config);
    try {
      final bytes = <int>[];
      final now = DateTime.now();

      // Raw ESC/POS path for code-page diagnosis, avoid generator remapping.
      bytes.addAll([0x1B, 0x40]); // ESC @ reset
      bytes.addAll([0x1B, 0x52, _thaiInternationalSetId]);
      bytes.addAll(_asciiLine('THAI CODE PAGE TEST'));
      bytes.addAll(
        _asciiLine(
          'TIME ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        ),
      );
      bytes.addAll(_asciiLine('PRINTER ${config.ip.trim()}'));
      bytes.addAll(_asciiLine('================================'));

      for (final tableId in _thaiProbeCodeTables) {
        if (tableId != null) {
          bytes.addAll([0x1B, 0x74, tableId]);
        }
        bytes.addAll(
          _asciiLine(tableId == null ? 'DEFAULT(no ESC t)' : 'ESC t $tableId'),
        );
        bytes.addAll(_cp874Line('ทดสอบภาษาไทย: ชานมไข่มุก ฿123'));
        bytes.addAll(_cp874Line('ทดสอบข้อความ: รับเงินสด พร้อมเพย์ ทรูมันนี่'));
        bytes.addAll(_asciiLine('--------------------------------'));
      }

      bytes.addAll([0x0A]);
      bytes.addAll([0x1D, 0x56, 0x00]);
      _debugDumpEscPosBytes('printThaiCodePageProbe', bytes);
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      await socket.close();
    }
  }

  Future<void> printDensityProbe({
    required PrinterConnectionConfig config,
  }) async {
    final socket = await _connectSocket(config);
    try {
      final bytes = <int>[];
      final now = DateTime.now();
      final levels = <int>[0, 2, 4, 6, 8, 10, 12];

      bytes.addAll([0x1B, 0x40]); // ESC @
      bytes.addAll(_asciiLine('PRINT DENSITY TEST'));
      bytes.addAll(
        _asciiLine(
          'TIME ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        ),
      );
      bytes.addAll(_asciiLine('PRINTER ${config.ip.trim()}'));
      bytes.addAll(
        _asciiLine('Select clearest level and tell me that number.'),
      );
      bytes.addAll(_asciiLine('================================'));

      for (final level in levels) {
        bytes.addAll(_setDensityBytes(level));
        bytes.addAll(_asciiLine('DENSITY LEVEL $level'));
        bytes.addAll(_cp874Line('ทดสอบความเข้ม: ภาษาไทย ชานมไข่มุก ฿123'));
        bytes.addAll(_asciiLine('###############################'));
        bytes.addAll(_asciiLine('--------------------------------'));
      }

      // Restore to a moderate default for safety after probe.
      bytes.addAll(_setDensityBytes(8));
      bytes.addAll([0x0A, 0x1D, 0x56, 0x00]);
      _debugDumpEscPosBytes('printDensityProbe', bytes);
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      await socket.close();
    }
  }

  Future<Socket> _connectSocket(PrinterConnectionConfig config) async {
    Socket? socket;
    final ip = config.ip.trim();
    final ports = config.port > 0
        ? <int>[config.port]
        : <int>[9100, 9101, 9102, 8008];
    Object? lastError;
    for (final port in ports) {
      try {
        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 4),
        );
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (socket == null) {
      throw SocketException(
        'Cannot connect to $ip. Tried ports: ${ports.join(', ')}. Last error: $lastError',
      );
    }
    return socket;
  }

  Uint8List _encodeCp874(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      if (rune <= 0x7F) {
        bytes.add(rune);
        continue;
      }
      if (rune == 0x0E3F) {
        bytes.add(0xDF); // Thai Baht sign
        continue;
      }
      if (rune >= 0x0E01 && rune <= 0x0E3A) {
        bytes.add(0xA1 + (rune - 0x0E01));
        continue;
      }
      if (rune >= 0x0E40 && rune <= 0x0E5B) {
        bytes.add(0xE0 + (rune - 0x0E40));
        continue;
      }
      bytes.add(0x3F); // '?'
    }
    return Uint8List.fromList(bytes);
  }

  List<int> _asciiLine(String text) => <int>[
    ...text.codeUnits.where((e) => e <= 0x7F),
    0x0A,
  ];

  List<int> _cp874Line(String text) => <int>[..._encodeCp874(text), 0x0A];

  List<int> _setDensityBytes(int level) {
    final value = level.clamp(0, 15);
    // Common ESC/POS-compatible command on many thermal printer firmwares.
    // Unsupported devices usually ignore it without side effects.
    return <int>[0x12, 0x23, value];
  }

  void _debugDumpEscPosBytes(String label, List<int> bytes) {
    if (!_enableEscPosDebugLog) return;
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    debugPrint('[ESC_POS][$label] len=${bytes.length}');
    debugPrint('[ESC_POS][$label] hex=$hex');
  }

  String _buildOptionsText(CartItem item, AppI18n i18n) {
    final parts = <String>[];
    if (item.sizeName.trim().isNotEmpty) {
      parts.add('${i18n.size}:${item.sizeName.trim()}');
    }
    if (item.sugarName.trim().isNotEmpty) {
      parts.add('${i18n.sugar}:${item.sugarName.trim()}');
    }
    if (item.iceName.trim().isNotEmpty) {
      parts.add('${i18n.ice}:${item.iceName.trim()}');
    }
    if (item.toppings.isNotEmpty) {
      final toppingNames = item.toppings
          .map((e) => e.name.trim())
          .where((e) => e.isNotEmpty)
          .join(',');
      if (toppingNames.isNotEmpty) {
        parts.add('${i18n.toppings}:$toppingNames');
      }
    }
    if (item.note.trim().isNotEmpty) {
      parts.add('${i18n.note}:${item.note.trim()}');
    }
    return parts.join(' | ');
  }
}
