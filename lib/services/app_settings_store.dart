import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_i18n.dart';
import 'receipt_print_service.dart';
import '../models/user_role.dart';

class AppSettingsStore {
  static const _languageKey = 'app_language';
  static const _roleKey = 'user_role';
  static const _printerIpKey = 'printer_ip';
  static const _labelPrinterIpKey = 'label_printer_ip';
  static const _printerPortKey = 'printer_port';
  static const _directPrintEnabledKey = 'direct_print_enabled';
  static const _autoPrintReceiptKey = 'auto_print_receipt';
  static const _autoOpenCashDrawerKey = 'auto_open_cash_drawer';
  static const _autoPrintLabelKey = 'auto_print_label';
  static const _autoPrintReceiptCopiesKey = 'auto_print_receipt_copies';
  static const _uploadApiBaseUrlKey = 'upload_api_base_url';
  static const _adminPinKey = 'admin_pin';
  static const _deliveryChannelsKey = 'delivery_channels';
  static const _receiptPrintModeKey = 'receipt_print_mode';
  static const _receiptBottomFeedLinesKey = 'receipt_bottom_feed_lines';
  static const _labelBottomFeedLinesKey = 'label_bottom_feed_lines';
  static const _storeNameKey = 'store_name';
  static const List<String> _defaultDeliveryChannels = <String>[
    'Grab',
    'ShopeeFood',
    'Foodpanda',
    'LINE MAN',
  ];

  Future<AppLanguage?> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_languageKey);
      if (raw == null) return null;
      for (final lang in AppLanguage.values) {
        if (lang.name == raw) return lang;
      }
      return null;
    } catch (e) {
      debugPrint('loadLanguage failed, fallback to default: $e');
      return null;
    }
  }

  Future<void> saveLanguage(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language.name);
    } catch (e) {
      debugPrint('saveLanguage failed, ignore: $e');
    }
  }

  Future<UserRole?> loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_roleKey);
      if (raw == null) return null;
      for (final role in UserRole.values) {
        if (role.name == raw) return role;
      }
      return null;
    } catch (e) {
      debugPrint('loadUserRole failed, fallback to default: $e');
      return null;
    }
  }

  Future<void> saveUserRole(UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role.name);
    } catch (e) {
      debugPrint('saveUserRole failed, ignore: $e');
    }
  }

  Future<String?> loadPrinterIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_printerIpKey)?.trim() ?? '';
      return raw.isEmpty ? null : raw;
    } catch (e) {
      debugPrint('loadPrinterIp failed, fallback to null: $e');
      return null;
    }
  }

  Future<void> savePrinterIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = ip.trim();
      if (value.isEmpty) {
        await prefs.remove(_printerIpKey);
      } else {
        await prefs.setString(_printerIpKey, value);
      }
    } catch (e) {
      debugPrint('savePrinterIp failed, ignore: $e');
    }
  }

  Future<String?> loadLabelPrinterIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_labelPrinterIpKey)?.trim() ?? '';
      return raw.isEmpty ? null : raw;
    } catch (e) {
      debugPrint('loadLabelPrinterIp failed, fallback to null: $e');
      return null;
    }
  }

  Future<void> saveLabelPrinterIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = ip.trim();
      if (value.isEmpty) {
        await prefs.remove(_labelPrinterIpKey);
      } else {
        await prefs.setString(_labelPrinterIpKey, value);
      }
    } catch (e) {
      debugPrint('saveLabelPrinterIp failed, ignore: $e');
    }
  }

  Future<int> loadPrinterPort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_printerPortKey);
      if (value == null || value <= 0 || value > 65535) return 9100;
      return value;
    } catch (e) {
      debugPrint('loadPrinterPort failed, fallback to default: $e');
      return 9100;
    }
  }

  Future<void> savePrinterPort(int port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (port <= 0 || port > 65535) {
        await prefs.remove(_printerPortKey);
      } else {
        await prefs.setInt(_printerPortKey, port);
      }
    } catch (e) {
      debugPrint('savePrinterPort failed, ignore: $e');
    }
  }

  Future<bool> loadDirectPrintEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_directPrintEnabledKey) ?? false;
    } catch (e) {
      debugPrint('loadDirectPrintEnabled failed, fallback to false: $e');
      return false;
    }
  }

  Future<void> saveDirectPrintEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_directPrintEnabledKey, enabled);
    } catch (e) {
      debugPrint('saveDirectPrintEnabled failed, ignore: $e');
    }
  }

  Future<bool> loadAutoPrintReceipt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoPrintReceiptKey) ?? false;
    } catch (e) {
      debugPrint('loadAutoPrintReceipt failed, fallback to false: $e');
      return false;
    }
  }

  Future<void> saveAutoPrintReceipt(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPrintReceiptKey, enabled);
    } catch (e) {
      debugPrint('saveAutoPrintReceipt failed, ignore: $e');
    }
  }

  Future<int> loadAutoPrintReceiptCopies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_autoPrintReceiptCopiesKey) ?? 2;
      final safe = ReceiptPrintService.sanitizeReceiptCopies(value);
      return safe <= 0 ? 1 : safe;
    } catch (e) {
      debugPrint('loadAutoPrintReceiptCopies failed, fallback to 2: $e');
      return 2;
    }
  }

  Future<void> saveAutoPrintReceiptCopies(int copies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final safe = ReceiptPrintService.sanitizeReceiptCopies(copies);
      await prefs.setInt(_autoPrintReceiptCopiesKey, safe <= 0 ? 1 : safe);
    } catch (e) {
      debugPrint('saveAutoPrintReceiptCopies failed, ignore: $e');
    }
  }

  Future<bool> loadAutoOpenCashDrawer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoOpenCashDrawerKey) ?? false;
    } catch (e) {
      debugPrint('loadAutoOpenCashDrawer failed, fallback to false: $e');
      return false;
    }
  }

  Future<void> saveAutoOpenCashDrawer(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoOpenCashDrawerKey, enabled);
    } catch (e) {
      debugPrint('saveAutoOpenCashDrawer failed, ignore: $e');
    }
  }

  Future<bool> loadAutoPrintLabel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoPrintLabelKey) ?? true;
    } catch (e) {
      debugPrint('loadAutoPrintLabel failed, fallback to true: $e');
      return true;
    }
  }

  Future<void> saveAutoPrintLabel(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPrintLabelKey, enabled);
    } catch (e) {
      debugPrint('saveAutoPrintLabel failed, ignore: $e');
    }
  }

  Future<String?> loadUploadApiBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_uploadApiBaseUrlKey)?.trim() ?? '';
      return raw.isEmpty ? null : raw;
    } catch (e) {
      debugPrint('loadUploadApiBaseUrl failed, fallback to null: $e');
      return null;
    }
  }

  Future<void> saveUploadApiBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = url.trim();
      if (value.isEmpty) {
        await prefs.remove(_uploadApiBaseUrlKey);
      } else {
        await prefs.setString(_uploadApiBaseUrlKey, value);
      }
    } catch (e) {
      debugPrint('saveUploadApiBaseUrl failed, ignore: $e');
    }
  }

  Future<String> loadAdminPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_adminPinKey)?.trim() ?? '';
      return raw.isEmpty ? '2580' : raw;
    } catch (e) {
      debugPrint('loadAdminPin failed, fallback to default: $e');
      return '2580';
    }
  }

  Future<void> saveAdminPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = pin.trim();
      if (value.isEmpty) {
        await prefs.remove(_adminPinKey);
      } else {
        await prefs.setString(_adminPinKey, value);
      }
    } catch (e) {
      debugPrint('saveAdminPin failed, ignore: $e');
    }
  }

  Future<List<String>> loadDeliveryChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = prefs.getStringList(_deliveryChannelsKey);
      if (values == null || values.isEmpty) {
        return _defaultDeliveryChannels;
      }
      final cleaned = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return cleaned.isEmpty ? _defaultDeliveryChannels : cleaned;
    } catch (e) {
      debugPrint('loadDeliveryChannels failed, fallback to default: $e');
      return _defaultDeliveryChannels;
    }
  }

  Future<void> saveDeliveryChannels(List<String> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleaned = channels
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (cleaned.isEmpty) {
        await prefs.remove(_deliveryChannelsKey);
      } else {
        await prefs.setStringList(_deliveryChannelsKey, cleaned);
      }
    } catch (e) {
      debugPrint('saveDeliveryChannels failed, ignore: $e');
    }
  }

  Future<ReceiptPrintMode> loadReceiptPrintMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_receiptPrintModeKey) ?? '').trim();
      if (raw == ReceiptPrintMode.text.name) return ReceiptPrintMode.text;
      return ReceiptPrintMode.bitmap;
    } catch (e) {
      debugPrint('loadReceiptPrintMode failed, fallback to bitmap: $e');
      return ReceiptPrintMode.bitmap;
    }
  }

  Future<void> saveReceiptPrintMode(ReceiptPrintMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_receiptPrintModeKey, mode.name);
    } catch (e) {
      debugPrint('saveReceiptPrintMode failed, ignore: $e');
    }
  }

  Future<int> loadReceiptBottomFeedLines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_receiptBottomFeedLinesKey) ?? 6;
      return ReceiptPrintService.sanitizeBottomFeedLines(value);
    } catch (e) {
      debugPrint('loadReceiptBottomFeedLines failed, fallback to 6: $e');
      return 6;
    }
  }

  Future<void> saveReceiptBottomFeedLines(int lines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _receiptBottomFeedLinesKey,
        ReceiptPrintService.sanitizeBottomFeedLines(lines),
      );
    } catch (e) {
      debugPrint('saveReceiptBottomFeedLines failed, ignore: $e');
    }
  }

  Future<int> loadLabelBottomFeedLines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_labelBottomFeedLinesKey) ?? 6;
      return ReceiptPrintService.sanitizeBottomFeedLines(value);
    } catch (e) {
      debugPrint('loadLabelBottomFeedLines failed, fallback to 6: $e');
      return 6;
    }
  }

  Future<void> saveLabelBottomFeedLines(int lines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _labelBottomFeedLinesKey,
        ReceiptPrintService.sanitizeBottomFeedLines(lines),
      );
    } catch (e) {
      debugPrint('saveLabelBottomFeedLines failed, ignore: $e');
    }
  }

  Future<String> loadStoreName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_storeNameKey) ?? '').trim();
      return raw.isEmpty ? 'TEA STORE' : raw;
    } catch (e) {
      debugPrint('loadStoreName failed, fallback to default: $e');
      return 'TEA STORE';
    }
  }

  Future<void> saveStoreName(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = value.trim();
      if (name.isEmpty) {
        await prefs.remove(_storeNameKey);
      } else {
        await prefs.setString(_storeNameKey, name);
      }
    } catch (e) {
      debugPrint('saveStoreName failed, ignore: $e');
    }
  }
}
