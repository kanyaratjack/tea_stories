import 'package:flutter/material.dart';

import '../l10n/app_i18n.dart';
import '../models/user_role.dart';
import '../services/receipt_print_service.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final PosController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _printerIpController;
  late final TextEditingController _labelPrinterIpController;
  late final TextEditingController _uploadApiController;
  late final TextEditingController _deliveryChannelsController;
  ReceiptPrintMode _receiptPrintMode = ReceiptPrintMode.bitmap;
  int _bottomFeedLinesBeforeCut = 6;
  int _labelBottomFeedLinesBeforeCut = 6;

  String t(String zh, String th, String en) {
    final i18n = widget.controller.i18n;
    return switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController();
    _printerIpController = TextEditingController();
    _labelPrinterIpController = TextEditingController();
    _uploadApiController = TextEditingController();
    _deliveryChannelsController = TextEditingController();
    _loadPrinterSettings();
  }

  Future<void> _loadPrinterSettings() async {
    final store = widget.controller.settingsStore;
    final storeName = await store.loadStoreName();
    final ip = await store.loadPrinterIp() ?? '';
    final labelIp = await store.loadLabelPrinterIp() ?? '';
    final receiptPrintMode = await store.loadReceiptPrintMode();
    final bottomFeedLines = await store.loadReceiptBottomFeedLines();
    final labelBottomFeedLines = await store.loadLabelBottomFeedLines();
    if (!mounted) return;
    setState(() {
      _storeNameController.text = storeName;
      _printerIpController.text = ip;
      _labelPrinterIpController.text = labelIp;
      _receiptPrintMode = receiptPrintMode;
      _bottomFeedLinesBeforeCut = bottomFeedLines;
      _labelBottomFeedLinesBeforeCut = labelBottomFeedLines;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _printerIpController.dispose();
    _labelPrinterIpController.dispose();
    _uploadApiController.dispose();
    _deliveryChannelsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.controller.i18n;
    final roleText = widget.controller.isAdmin
        ? i18n.roleAdmin
        : i18n.roleClerk;
    return Scaffold(
      appBar: AppBar(title: Text(i18n.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SettingsGroupCard(
              title: t('基础设置', 'ตั้งค่าพื้นฐาน', 'General'),
              children: [
                _SettingsCell(
                  icon: Icons.language_outlined,
                  title: t('语言', 'ภาษา', 'Language'),
                  subtitle: i18n.getLanguageLabel(widget.controller.language),
                  onTap: _openLanguagePanel,
                ),
                _SettingsCell(
                  icon: Icons.verified_user_outlined,
                  title: i18n.role,
                  subtitle: roleText,
                  onTap: _openRolePanel,
                ),
              ],
            ),
            if (widget.controller.isAdmin) ...[
              const SizedBox(height: 12),
              _SettingsGroupCard(
                title: t('打印与网络', 'การพิมพ์และเครือข่าย', 'Printing & Network'),
                children: [
                  _SettingsCell(
                    icon: Icons.print_outlined,
                    title: i18n.printerSettings,
                    subtitle:
                        '${_storeNameController.text.trim()} · ${t('小票机', 'เครื่องพิมพ์ใบเสร็จ', 'Receipt')}: ${_printerIpController.text.trim().isEmpty ? t('未设置', 'ยังไม่ตั้งค่า', 'Not set') : _printerIpController.text.trim()} · ${t('标签机', 'เครื่องพิมพ์ฉลาก', 'Label')}: ${_labelPrinterIpController.text.trim().isEmpty ? t('未设置', 'ยังไม่ตั้งค่า', 'Not set') : _labelPrinterIpController.text.trim()} · ${_receiptPrintModeLabel()} · ${t('小票底部', 'ท้ายบิล', 'Receipt Feed')} $_bottomFeedLinesBeforeCut · ${t('标签底部', 'ท้ายฉลาก', 'Label Feed')} $_labelBottomFeedLinesBeforeCut',
                    onTap: _openPrinterSettingsPanel,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _receiptPrintModeLabel() {
    return _receiptPrintMode == ReceiptPrintMode.bitmap
        ? t('位图', 'ภาพ', 'Bitmap')
        : t('文本', 'ข้อความ', 'Text');
  }

  Future<void> _openLanguagePanel() async {
    final i18n = widget.controller.i18n;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          children: AppLanguage.values
              .map(
                (lang) => ListTile(
                  title: Text(i18n.getLanguageLabel(lang)),
                  trailing: widget.controller.language == lang
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    widget.controller.setLanguage(lang);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _openRolePanel() async {
    final i18n = widget.controller.i18n;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(i18n.switchToAdmin),
                enabled: !widget.controller.isAdmin,
                onTap: !widget.controller.isAdmin
                    ? () async {
                        Navigator.of(sheetContext).pop();
                        await _switchToAdmin(context);
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(i18n.switchToClerk),
                enabled: widget.controller.isAdmin,
                onTap: widget.controller.isAdmin
                    ? () async {
                        await widget.controller.setUserRole(UserRole.clerk);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
              if (widget.controller.isAdmin)
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: Text(
                    t('修改管理员PIN', 'เปลี่ยนรหัสผู้ดูแล', 'Change Admin PIN'),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _changeAdminPin(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPrinterSettingsPanel() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PrinterNetworkSettingsPage(controller: widget.controller),
      ),
    );
    await _loadPrinterSettings();
  }

  Future<void> _switchToAdmin(BuildContext context) async {
    final i18n = widget.controller.i18n;
    final adminPin = await widget.controller.settingsStore.loadAdminPin();
    if (!context.mounted) return;
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PinDialog(i18n: i18n),
    );
    if (pin == null) return;
    if (pin != adminPin) {
      if (!context.mounted) return;
      showLatestSnackBar(context, i18n.permissionDenied);
      return;
    }
    await widget.controller.setUserRole(UserRole.admin);
  }

  Future<void> _changeAdminPin(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final i18n = widget.controller.i18n;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminPinDialog(i18n: i18n),
    );
    if (result == null) return;
    await widget.controller.settingsStore.saveAdminPin(result);
    showLatestSnackBarOn(
      messenger,
      t('管理员PIN已更新', 'อัปเดตรหัสผู้ดูแลแล้ว', 'Admin PIN updated'),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3EEF9)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsCell extends StatelessWidget {
  const _SettingsCell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PrinterNetworkSettingsPage extends StatefulWidget {
  const _PrinterNetworkSettingsPage({required this.controller});

  final PosController controller;

  @override
  State<_PrinterNetworkSettingsPage> createState() =>
      _PrinterNetworkSettingsPageState();
}

class _PrinterNetworkSettingsPageState
    extends State<_PrinterNetworkSettingsPage> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _printerIpController;
  late final TextEditingController _labelPrinterIpController;
  late final TextEditingController _uploadApiController;
  ReceiptPrintMode _receiptPrintMode = ReceiptPrintMode.bitmap;
  int _bottomFeedLinesBeforeCut = 6;
  int _labelBottomFeedLinesBeforeCut = 6;
  List<String> _deliveryChannels = const <String>[];
  bool _autoPrintReceipt = false;
  int _autoPrintReceiptCopies = 2;
  bool _autoPrintLabel = true;
  bool _autoOpenCashDrawer = false;
  bool _isSaving = false;
  bool _isTestingReceiptPrinter = false;
  bool _isTestingLabelPrinter = false;

  String t(String zh, String th, String en) {
    final i18n = widget.controller.i18n;
    return switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController();
    _printerIpController = TextEditingController();
    _labelPrinterIpController = TextEditingController();
    _uploadApiController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final store = widget.controller.settingsStore;
    final storeName = await store.loadStoreName();
    final autoPrintReceipt = await store.loadAutoPrintReceipt();
    final autoPrintReceiptCopies = await store.loadAutoPrintReceiptCopies();
    final autoPrintLabel = await store.loadAutoPrintLabel();
    final autoOpenCashDrawer = await store.loadAutoOpenCashDrawer();
    final ip = await store.loadPrinterIp() ?? '';
    final labelIp = await store.loadLabelPrinterIp() ?? '';
    final uploadApi = await store.loadUploadApiBaseUrl() ?? '';
    final deliveryChannels = await store.loadDeliveryChannels();
    final receiptPrintMode = await store.loadReceiptPrintMode();
    final bottomFeedLines = await store.loadReceiptBottomFeedLines();
    final labelBottomFeedLines = await store.loadLabelBottomFeedLines();
    if (!mounted) return;
    setState(() {
      _storeNameController.text = storeName;
      _autoPrintReceipt = autoPrintReceipt;
      _autoPrintReceiptCopies = autoPrintReceiptCopies;
      _autoPrintLabel = autoPrintLabel;
      _autoOpenCashDrawer = autoOpenCashDrawer;
      _printerIpController.text = ip;
      _labelPrinterIpController.text = labelIp;
      _uploadApiController.text = uploadApi;
      _deliveryChannels = List<String>.from(deliveryChannels);
      _receiptPrintMode = receiptPrintMode;
      _bottomFeedLinesBeforeCut = bottomFeedLines;
      _labelBottomFeedLinesBeforeCut = labelBottomFeedLines;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _printerIpController.dispose();
    _labelPrinterIpController.dispose();
    _uploadApiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.controller.i18n;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('打印与网络', 'การพิมพ์และเครือข่าย', 'Printing & Network')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsCell(
              icon: Icons.tune,
              title: t('自动行为', 'การทำงานอัตโนมัติ', 'Automation'),
              subtitle: _autoBehaviorSummary(),
              onTap: _openAutoBehaviorSettings,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _storeNameController,
              decoration: InputDecoration(
                labelText: t('店铺名称', 'ชื่อร้าน', 'Store Name'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReceiptPrintMode>(
              initialValue: _receiptPrintMode,
              decoration: InputDecoration(
                labelText: t('打印模式', 'โหมดการพิมพ์', 'Print Mode'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: ReceiptPrintMode.bitmap,
                  child: Text(
                    t(
                      '位图打印（更稳）',
                      'พิมพ์แบบภาพ (เสถียรกว่า)',
                      'Bitmap (Stable)',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: ReceiptPrintMode.text,
                  child: Text(
                    t(
                      '文本直连（更快）',
                      'ข้อความตรง (เร็วกว่า)',
                      'Text Direct (Faster)',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _receiptPrintMode = value);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${t('底部留白行数', 'จำนวนบรรทัดเว้นท้าย', 'Bottom Feed Lines')}: $_bottomFeedLinesBeforeCut',
                  ),
                ),
                IconButton(
                  onPressed: _bottomFeedLinesBeforeCut > 0
                      ? () => setState(() {
                          _bottomFeedLinesBeforeCut -= 1;
                        })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _bottomFeedLinesBeforeCut < 12
                      ? () => setState(() {
                          _bottomFeedLinesBeforeCut += 1;
                        })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${t('标签底部留白行数', 'จำนวนบรรทัดเว้นท้ายฉลาก', 'Label Bottom Feed Lines')}: $_labelBottomFeedLinesBeforeCut',
                  ),
                ),
                IconButton(
                  onPressed: _labelBottomFeedLinesBeforeCut > 0
                      ? () => setState(() {
                          _labelBottomFeedLinesBeforeCut -= 1;
                        })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _labelBottomFeedLinesBeforeCut < 12
                      ? () => setState(() {
                          _labelBottomFeedLinesBeforeCut += 1;
                        })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _printerIpController,
              decoration: InputDecoration(
                labelText: t(
                  '小票打印机 IP',
                  'IP เครื่องพิมพ์ใบเสร็จ',
                  'Receipt Printer IP',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _labelPrinterIpController,
              decoration: InputDecoration(
                labelText: t(
                  '标签打印机 IP (58mm)',
                  'IP เครื่องพิมพ์ฉลาก (58mm)',
                  'Label Printer IP (58mm)',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _uploadApiController,
              decoration: InputDecoration(
                labelText: t(
                  '上传接口基础地址',
                  'ฐาน URL ของอัปโหลด API',
                  'Upload API Base URL',
                ),
                hintText: t(
                  '例如：https://api.example.com',
                  'เช่น: https://api.example.com',
                  'e.g. https://api.example.com',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              i18n.deliveryChannelSettings,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._deliveryChannels.map(
                  (e) => InputChip(
                    label: Text(e),
                    onDeleted: () {
                      setState(() {
                        _deliveryChannels = _deliveryChannels
                            .where((v) => v != e)
                            .toList(growable: false);
                      });
                    },
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(t('添加平台', 'เพิ่มแพลตฟอร์ม', 'Add Channel')),
                  onPressed: _addDeliveryChannel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _save(i18n),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(i18n.save),
                ),
                OutlinedButton.icon(
                  onPressed: _isTestingReceiptPrinter
                      ? null
                      : () => _testDirectPrint(
                          i18n,
                          _printerIpController.text.trim(),
                          isLabelPrinter: false,
                        ),
                  icon: _isTestingReceiptPrinter
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(
                    t('测试小票机', 'ทดสอบเครื่องใบเสร็จ', 'Test Receipt'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isTestingLabelPrinter
                      ? null
                      : () => _testDirectPrint(
                          i18n,
                          _labelPrinterIpController.text.trim(),
                          isLabelPrinter: true,
                        ),
                  icon: _isTestingLabelPrinter
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_print_shop_outlined),
                  label: Text(t('测试标签机', 'ทดสอบเครื่องฉลาก', 'Test Label')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppI18n i18n) async {
    setState(() => _isSaving = true);
    try {
      final store = widget.controller.settingsStore;
      await store.saveStoreName(_storeNameController.text.trim());
      await store.saveReceiptPrintMode(_receiptPrintMode);
      await store.saveReceiptBottomFeedLines(_bottomFeedLinesBeforeCut);
      await store.saveLabelBottomFeedLines(_labelBottomFeedLinesBeforeCut);
      await store.savePrinterIp(_printerIpController.text.trim());
      await store.saveLabelPrinterIp(_labelPrinterIpController.text.trim());
      await store.saveUploadApiBaseUrl(_uploadApiController.text.trim());
      await store.saveDeliveryChannels(_deliveryChannels);
      if (!mounted) return;
      showLatestSnackBar(context, i18n.printerSaved);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _autoBehaviorSummary() {
    final parts = <String>[];
    if (_autoPrintReceipt) {
      parts.add(
        t(
          '自动小票$_autoPrintReceiptCopies张',
          'พิมพ์ใบเสร็จอัตโนมัติ $_autoPrintReceiptCopies ใบ',
          'Auto receipt x$_autoPrintReceiptCopies',
        ),
      );
    } else {
      parts.add(t('不自动打印小票', 'ไม่พิมพ์ใบเสร็จอัตโนมัติ', 'No auto receipt'));
    }
    parts.add(
      _autoPrintLabel
          ? t('自动标签开', 'พิมพ์ฉลากอัตโนมัติ เปิด', 'Auto label on')
          : t('自动标签关', 'พิมพ์ฉลากอัตโนมัติ ปิด', 'Auto label off'),
    );
    parts.add(
      _autoOpenCashDrawer
          ? t(
              '现金开钱箱开',
              'เปิดลิ้นชักเงินสำหรับเงินสด เปิด',
              'Cash drawer auto on',
            )
          : t(
              '现金开钱箱关',
              'เปิดลิ้นชักเงินสำหรับเงินสด ปิด',
              'Cash drawer auto off',
            ),
    );
    return parts.join(' · ');
  }

  Future<void> _openAutoBehaviorSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _AutoPrintBehaviorSettingsPage(controller: widget.controller),
      ),
    );
    await _load();
  }

  Future<void> _testDirectPrint(
    AppI18n i18n,
    String ip, {
    required bool isLabelPrinter,
  }) async {
    if (ip.isEmpty) {
      showLatestSnackBar(context, i18n.printerNotConfigured);
      return;
    }
    setState(() {
      if (isLabelPrinter) {
        _isTestingLabelPrinter = true;
      } else {
        _isTestingReceiptPrinter = true;
      }
    });
    try {
      const service = ReceiptPrintService();
      await service.printNetworkTest(
        config: PrinterConnectionConfig(ip: ip, port: 0, enabled: true),
      );
      if (!mounted) return;
      showLatestSnackBar(context, i18n.printReceiptSuccess);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${i18n.printReceiptFailed}: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (isLabelPrinter) {
            _isTestingLabelPrinter = false;
          } else {
            _isTestingReceiptPrinter = false;
          }
        });
      }
    }
  }

  Future<void> _addDeliveryChannel() async {
    final inputController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t('新增外卖平台', 'เพิ่มแพลตฟอร์มเดลิเวอรี', 'Add Delivery Channel'),
        ),
        content: TextField(
          controller: inputController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t('例如 Grab', 'เช่น Grab', 'e.g. Grab'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('取消', 'ยกเลิก', 'Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(inputController.text.trim()),
            child: Text(t('添加', 'เพิ่ม', 'Add')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputController.dispose();
    });
    if (!mounted) return;
    final name = (value ?? '').trim();
    if (name.isEmpty) return;
    final exists = _deliveryChannels.any(
      (e) => e.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      showLatestSnackBar(
        context,
        t('平台已存在', 'มีแพลตฟอร์มนี้แล้ว', 'Channel already exists'),
      );
      return;
    }
    setState(() {
      _deliveryChannels = <String>[..._deliveryChannels, name];
    });
  }
}

class _AutoPrintBehaviorSettingsPage extends StatefulWidget {
  const _AutoPrintBehaviorSettingsPage({required this.controller});

  final PosController controller;

  @override
  State<_AutoPrintBehaviorSettingsPage> createState() =>
      _AutoPrintBehaviorSettingsPageState();
}

class _AutoPrintBehaviorSettingsPageState
    extends State<_AutoPrintBehaviorSettingsPage> {
  bool _autoPrintReceipt = false;
  int _autoPrintReceiptCopies = 2;
  bool _autoPrintLabel = true;
  bool _autoOpenCashDrawer = false;
  bool _isSaving = false;

  String t(String zh, String th, String en) {
    final i18n = widget.controller.i18n;
    return switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = widget.controller.settingsStore;
    final autoPrintReceipt = await store.loadAutoPrintReceipt();
    final autoPrintReceiptCopies = await store.loadAutoPrintReceiptCopies();
    final autoPrintLabel = await store.loadAutoPrintLabel();
    final autoOpenCashDrawer = await store.loadAutoOpenCashDrawer();
    if (!mounted) return;
    setState(() {
      _autoPrintReceipt = autoPrintReceipt;
      _autoPrintReceiptCopies = autoPrintReceiptCopies;
      _autoPrintLabel = autoPrintLabel;
      _autoOpenCashDrawer = autoOpenCashDrawer;
    });
  }

  Future<void> _save() async {
    final i18n = widget.controller.i18n;
    setState(() => _isSaving = true);
    try {
      final store = widget.controller.settingsStore;
      await store.saveAutoPrintReceipt(_autoPrintReceipt);
      await store.saveAutoPrintReceiptCopies(_autoPrintReceiptCopies);
      await store.saveAutoPrintLabel(_autoPrintLabel);
      await store.saveAutoOpenCashDrawer(_autoOpenCashDrawer);
      if (!mounted) return;
      showLatestSnackBar(context, i18n.printerSaved);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.controller.i18n;
    return Scaffold(
      appBar: AppBar(title: Text(t('自动行为', 'การทำงานอัตโนมัติ', 'Automation'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i18n.autoPrintReceipt),
              value: _autoPrintReceipt,
              onChanged: (value) => setState(() => _autoPrintReceipt = value),
            ),
            if (_autoPrintReceipt)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t('自动小票张数', 'จำนวนใบเสร็จอัตโนมัติ', 'Auto receipt copies')}: $_autoPrintReceiptCopies',
                    ),
                  ),
                  IconButton(
                    onPressed: _autoPrintReceiptCopies > 1
                        ? () => setState(() {
                            _autoPrintReceiptCopies -= 1;
                          })
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    onPressed: _autoPrintReceiptCopies < 5
                        ? () => setState(() {
                            _autoPrintReceiptCopies += 1;
                          })
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t(
                  '结算后自动打印标签',
                  'พิมพ์ฉลากอัตโนมัติหลังชำระเงิน',
                  'Auto print label after checkout',
                ),
              ),
              value: _autoPrintLabel,
              onChanged: (value) => setState(() => _autoPrintLabel = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i18n.autoOpenCashDrawer),
              subtitle: Text(
                t('仅现金支付生效', 'ใช้เฉพาะออเดอร์เงินสด', 'Cash orders only'),
              ),
              value: _autoOpenCashDrawer,
              onChanged: (value) => setState(() => _autoOpenCashDrawer = value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(i18n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.i18n});

  final AppI18n i18n;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return AlertDialog(
      scrollable: true,
      title: Text(i18n.enterAdminPin),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: i18n.adminPinHint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pinController.text.trim()),
          child: Text(i18n.confirm),
        ),
      ],
    );
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog({required this.i18n});

  final AppI18n i18n;

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  late final TextEditingController _pinController;
  late final TextEditingController _confirmPinController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmPinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  bool _isValidPin(String pin) {
    final exp = RegExp(r'^\d{4,8}$');
    return exp.hasMatch(pin);
  }

  @override
  Widget build(BuildContext context) {
    String t(String zh, String th, String en) => switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final screenWidth = MediaQuery.of(context).size.width;
    return AlertDialog(
      scrollable: true,
      title: Text(t('修改管理员PIN', 'เปลี่ยนรหัสผู้ดูแล', 'Change Admin PIN')),
      content: SizedBox(
        width: screenWidth < 520 ? screenWidth * 0.9 : 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t(
                  '新PIN（4-8位数字）',
                  'PIN ใหม่ (4-8 หลัก)',
                  'New PIN (4-8 digits)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t('确认新PIN', 'ยืนยัน PIN ใหม่', 'Confirm new PIN'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('取消', 'ยกเลิก', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final pin = _pinController.text.trim();
            final confirm = _confirmPinController.text.trim();
            if (!_isValidPin(pin)) {
              setState(
                () => _errorText = t(
                  'PIN必须是4-8位数字',
                  'PIN ต้องเป็นตัวเลข 4-8 หลัก',
                  'PIN must be 4-8 digits',
                ),
              );
              return;
            }
            if (pin != confirm) {
              setState(
                () => _errorText = t(
                  '两次输入的PIN不一致',
                  'PIN ไม่ตรงกัน',
                  'PINs do not match',
                ),
              );
              return;
            }
            Navigator.pop(context, pin);
          },
          child: Text(t('保存', 'บันทึก', 'Save')),
        ),
      ],
    );
  }
}
