import 'package:flutter/material.dart';

import '../l10n/app_i18n.dart';
import '../models/spec_option.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

class SpecManagementPage extends StatefulWidget {
  const SpecManagementPage({
    super.key,
    required this.controller,
    this.initialGroupKey = SpecGroupKey.size,
  });

  final PosController controller;
  final String initialGroupKey;

  @override
  State<SpecManagementPage> createState() => _SpecManagementPageState();
}

class _SpecManagementPageState extends State<SpecManagementPage> {
  bool _loading = true;
  String? _error;
  late String _groupKey;
  List<SpecOption> _all = const <SpecOption>[];

  @override
  void initState() {
    super.initState();
    _groupKey = widget.initialGroupKey;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.controller.loadSpecOptionsForManagement();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.controller.i18n;
    final list = _all
        .where((e) => e.groupKey == _groupKey)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.specManagement),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add),
            label: Text(_t('新增规格项', 'เพิ่มตัวเลือก', 'Add Spec Option')),
          ),
          const SizedBox(width: 8),
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
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _groupKey,
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
                          value: SpecGroupKey.size,
                          child: Text(_groupLabel(SpecGroupKey.size)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.sugar,
                          child: Text(_groupLabel(SpecGroupKey.sugar)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.ice,
                          child: Text(_groupLabel(SpecGroupKey.ice)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.toppings,
                          child: Text(_groupLabel(SpecGroupKey.toppings)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _groupKey = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _groupKey = SpecGroupKey.size);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: Text(widget.controller.i18n.reset),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : list.isEmpty
                  ? Center(
                      child: Text(
                        _t('暂无规格项', 'ยังไม่มีตัวเลือก', 'No spec options'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = list[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE3EEF9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.localizedName(
                                              widget.controller.language.name,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StatusBadge(
                                          label: item.isActive
                                              ? _t('上架', 'วางขาย', 'Listed')
                                              : _t('下架', 'หยุดขาย', 'Unlisted'),
                                          color: item.isActive
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFC62828),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'TH: ${(item.nameTh ?? '').trim().isEmpty ? '-' : item.nameTh!.trim()}  EN: ${(item.nameEn ?? '').trim().isEmpty ? '-' : item.nameEn!.trim()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF607D8B),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.price > 0
                                          ? '${_t('加价', 'เพิ่มราคา', 'Extra')} ฿${item.price.toStringAsFixed(0)}'
                                          : _t(
                                              '无加价',
                                              'ไม่เพิ่มราคา',
                                              'No extra',
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _openEditDialog(item),
                                child: Text(_t('编辑', 'แก้ไข', 'Edit')),
                              ),
                              TextButton(
                                onPressed: () => _deleteSpecOption(item),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFD32F2F),
                                ),
                                child: Text(_t('删除', 'ลบ', 'Delete')),
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
  }

  Future<void> _openAddDialog() async {
    final data = await _showEditDialog(groupKey: _groupKey);
    if (data == null) return;
    try {
      await widget.controller.createSpecOption(
        groupKey: data.groupKey,
        name: data.name,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
        price: data.price,
      );
      if (!mounted) return;
      setState(() => _groupKey = data.groupKey);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        '${_t('保存失败', 'บันทึกไม่สำเร็จ', 'Save failed')}: $e',
      );
    }
  }

  Future<void> _openEditDialog(SpecOption item) async {
    final data = await _showEditDialog(option: item, groupKey: item.groupKey);
    if (data == null) return;
    try {
      await widget.controller.updateSpecOption(
        id: item.id,
        name: data.name,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
        price: data.price,
      );
      await widget.controller.setSpecOptionActive(item.id, data.isActive);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        '${_t('保存失败', 'บันทึกไม่สำเร็จ', 'Save failed')}: $e',
      );
    }
  }

  Future<void> _deleteSpecOption(SpecOption item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('删除规格项', 'ลบตัวเลือก', 'Delete Spec Option')),
        content: Text(
          '${_t('确认删除', 'ยืนยันการลบ', 'Delete')}「${item.localizedName(widget.controller.language.name)}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.controller.i18n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
            child: Text(_t('删除', 'ลบ', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.controller.deleteSpecOption(item.id);
      await _load();
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t('规格项已删除', 'ลบตัวเลือกแล้ว', 'Spec option deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        '${_t('删除失败', 'ลบไม่สำเร็จ', 'Delete failed')}: $e',
      );
    }
  }

  Future<_SpecEditData?> _showEditDialog({
    SpecOption? option,
    required String groupKey,
  }) {
    return showDialog<_SpecEditData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SpecEditDialog(
        option: option,
        groupKey: groupKey,
        language: widget.controller.language,
      ),
    );
  }

  String _groupLabel(String groupKey) {
    return switch (groupKey) {
      SpecGroupKey.size => _t('杯型', 'ขนาดแก้ว', 'Size'),
      SpecGroupKey.sugar => _t('甜度', 'ระดับความหวาน', 'Sugar'),
      SpecGroupKey.ice => _t('冰度', 'ระดับน้ำแข็ง', 'Ice'),
      SpecGroupKey.toppings => _t('小料', 'ท็อปปิ้ง', 'Toppings'),
      _ => groupKey,
    };
  }

  String _t(String zh, String th, String en) {
    return switch (widget.controller.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }
}

class _SpecEditDialog extends StatefulWidget {
  const _SpecEditDialog({
    this.option,
    required this.groupKey,
    required this.language,
  });

  final SpecOption? option;
  final String groupKey;
  final AppLanguage language;

  @override
  State<_SpecEditDialog> createState() => _SpecEditDialogState();
}

class _SpecEditDialogState extends State<_SpecEditDialog> {
  late final TextEditingController _nameZhController;
  late final TextEditingController _nameThController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _priceController;
  late String _groupKey;
  late bool _isActive;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameZhController = TextEditingController(
      text: widget.option?.nameZh ?? widget.option?.name ?? '',
    );
    _nameThController = TextEditingController(
      text: widget.option?.nameTh ?? '',
    );
    _nameEnController = TextEditingController(
      text: widget.option?.nameEn ?? '',
    );
    _priceController = TextEditingController(
      text: widget.option == null
          ? '0'
          : widget.option!.price.toStringAsFixed(0),
    );
    _groupKey = widget.groupKey;
    _isActive = widget.option?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameZhController.dispose();
    _nameThController.dispose();
    _nameEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String zh, String th, String en) => switch (widget.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    String groupLabel(String groupKey) => switch (groupKey) {
      SpecGroupKey.size => t('杯型', 'ขนาดแก้ว', 'Size'),
      SpecGroupKey.sugar => t('甜度', 'ระดับความหวาน', 'Sugar'),
      SpecGroupKey.ice => t('冰度', 'ระดับน้ำแข็ง', 'Ice'),
      SpecGroupKey.toppings => t('小料', 'ท็อปปิ้ง', 'Toppings'),
      _ => groupKey,
    };
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogContentHeight = (screenHeight - viewInsetsBottom - 220)
        .clamp(180.0, screenHeight * 0.72)
        .toDouble();

    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.option == null
            ? t('新增规格项', 'เพิ่มตัวเลือก', 'Add Spec Option')
            : t('编辑规格项', 'แก้ไขตัวเลือก', 'Edit Spec Option'),
      ),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _groupKey,
                      decoration: InputDecoration(
                        labelText: t('类型', 'ประเภท', 'Type'),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SpecGroupKey.size,
                          child: Text(groupLabel(SpecGroupKey.size)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.sugar,
                          child: Text(groupLabel(SpecGroupKey.sugar)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.ice,
                          child: Text(groupLabel(SpecGroupKey.ice)),
                        ),
                        DropdownMenuItem(
                          value: SpecGroupKey.toppings,
                          child: Text(groupLabel(SpecGroupKey.toppings)),
                        ),
                      ],
                      onChanged: widget.option == null
                          ? (value) {
                              if (value == null) return;
                              setState(() => _groupKey = value);
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameZhController,
                  decoration: InputDecoration(
                    labelText: t('名称 (中文)', 'ชื่อ (中文)', 'Name (ZH)'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameThController,
                        decoration: InputDecoration(
                          labelText: t('名称 (ไทย)', 'ชื่อ (ไทย)', 'Name (TH)'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _nameEnController,
                        decoration: InputDecoration(
                          labelText: t('名称 (EN)', 'ชื่อ (EN)', 'Name (EN)'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t(
                      '加价（THB）',
                      'ราคาเพิ่ม (THB)',
                      'Extra Price (THB)',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.option != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isActive,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('上架', 'วางขาย', 'Listed')),
                    subtitle: Text(
                      _isActive
                          ? t('当前为上架状态', 'กำลังวางขาย', 'Currently listed')
                          : t('当前为下架状态', 'หยุดขายอยู่', 'Currently unlisted'),
                    ),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('取消', 'ยกเลิก', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final nameZh = _nameZhController.text.trim();
            final nameTh = _nameThController.text.trim();
            final nameEn = _nameEnController.text.trim();
            final fallbackName = nameZh.isNotEmpty
                ? nameZh
                : (nameTh.isNotEmpty ? nameTh : nameEn);
            final price = double.tryParse(_priceController.text.trim()) ?? 0;
            if (fallbackName.isEmpty || price < 0) {
              setState(
                () => _errorText = t(
                  '请检查输入',
                  'กรุณาตรวจสอบข้อมูล',
                  'Please check inputs',
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _SpecEditData(
                groupKey: _groupKey,
                name: fallbackName,
                nameTh: nameTh,
                nameZh: nameZh,
                nameEn: nameEn,
                price: price,
                isActive: _isActive,
              ),
            );
          },
          child: Text(t('保存', 'บันทึก', 'Save')),
        ),
      ],
    );
  }
}

class _SpecEditData {
  const _SpecEditData({
    required this.groupKey,
    required this.name,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    required this.price,
    required this.isActive,
  });

  final String groupKey;
  final String name;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
  final double price;
  final bool isActive;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
