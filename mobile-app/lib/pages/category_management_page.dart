import 'package:flutter/material.dart';

import '../l10n/app_i18n.dart';
import '../models/product_category.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({
    super.key,
    required this.controller,
    required this.i18n,
  });

  final PosController controller;
  final AppI18n i18n;

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  bool _loading = true;
  String? _error;
  List<ProductCategory> _categories = const <ProductCategory>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.controller.loadCategoriesForManagement();
      if (!mounted) return;
      setState(() {
        _categories = data
            .where((item) => !_isLegacyToppingCategory(item.name))
            .toList(growable: false);
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
    final i18n = widget.i18n;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.categoryManagement),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: i18n.retry,
          ),
          TextButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add),
            label: Text(i18n.addCategory),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _categories.isEmpty
            ? Center(child: Text(i18n.noProducts))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final item = _categories[index];
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.localizedName(
                                  widget.controller.language.name,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TH: ${(item.nameTh ?? '').trim().isEmpty ? '-' : item.nameTh!.trim()}  EN: ${(item.nameEn ?? '').trim().isEmpty ? '-' : item.nameEn!.trim()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text('${item.productCount} ${i18n.productsUnit}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusBadge(
                              label: item.isActive
                                  ? _t('上架', 'วางขาย', 'Listed')
                                  : _t('下架', 'หยุดขาย', 'Unlisted'),
                              color: item.isActive
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _openRenameDialog(item),
                                  child: Text(i18n.editCategory),
                                ),
                                TextButton(
                                  onPressed: () => _deleteCategory(item),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFD32F2F),
                                  ),
                                  child: Text(_t('删除', 'ลบ', 'Delete')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final data = await _showNameDialog();
    if (data == null) return;
    if (_isLegacyToppingCategory(data.name)) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t(
          '“加料”已迁移到规格管理，请在规格管理维护。',
          'หมวดท็อปปิ้งถูกย้ายไปจัดการในเมนูตัวเลือกสินค้าแล้ว',
          'Toppings are managed in Spec Management now.',
        ),
      );
      return;
    }
    try {
      await widget.controller.createCategory(
        data.name,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
      );
      await _load();
      if (!mounted) return;
      showLatestSnackBar(context, widget.i18n.categorySaved);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${widget.i18n.saveFailed}: $e');
    }
  }

  Future<void> _openRenameDialog(ProductCategory category) async {
    final data = await _showNameDialog(category: category);
    if (data == null) return;
    if (_isLegacyToppingCategory(data.name)) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t(
          '“加料”已迁移到规格管理，请在规格管理维护。',
          'หมวดท็อปปิ้งถูกย้ายไปจัดการในเมนูตัวเลือกสินค้าแล้ว',
          'Toppings are managed in Spec Management now.',
        ),
      );
      return;
    }
    try {
      await widget.controller.renameCategory(
        id: category.id,
        newName: data.name,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
      );
      await widget.controller.setCategoryActive(category.id, data.isActive);
      await _load();
      if (!mounted) return;
      showLatestSnackBar(context, widget.i18n.categorySaved);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${widget.i18n.saveFailed}: $e');
    }
  }

  Future<void> _deleteCategory(ProductCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('删除分类', 'ลบหมวดหมู่', 'Delete Category')),
        content: Text(
          '${_t('确认删除', 'ยืนยันการลบ', 'Delete')}「${category.localizedName(widget.controller.language.name)}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.i18n.cancel),
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
      await widget.controller.deleteCategory(category.id);
      await _load();
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t('分类已删除', 'ลบหมวดหมู่แล้ว', 'Category deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${widget.i18n.saveFailed}: $e');
    }
  }

  Future<_CategoryEditData?> _showNameDialog({
    ProductCategory? category,
  }) async {
    return showDialog<_CategoryEditData>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _CategoryNameDialog(i18n: widget.i18n, category: category),
    );
  }

  bool _isLegacyToppingCategory(String category) => category.trim() == '加料';

  String _t(String zh, String th, String en) {
    return switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({required this.i18n, this.category});

  final AppI18n i18n;
  final ProductCategory? category;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _nameZhController;
  late final TextEditingController _nameThController;
  late final TextEditingController _nameEnController;
  late bool _isActive;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameZhController = TextEditingController(
      text: widget.category?.nameZh ?? widget.category?.name ?? '',
    );
    _nameThController = TextEditingController(
      text: widget.category?.nameTh ?? '',
    );
    _nameEnController = TextEditingController(
      text: widget.category?.nameEn ?? '',
    );
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameZhController.dispose();
    _nameThController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogContentHeight = (screenHeight - viewInsetsBottom - 220)
        .clamp(180.0, screenHeight * 0.72)
        .toDouble();

    return AlertDialog(
      title: Text(
        widget.category == null ? i18n.addCategory : i18n.editCategory,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameZhController,
                  decoration: InputDecoration(
                    labelText: '${i18n.categoryName} (中文)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameThController,
                  decoration: InputDecoration(
                    labelText: '${i18n.categoryName} (ไทย)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameEnController,
                  decoration: InputDecoration(
                    labelText: '${i18n.categoryName} (EN)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (widget.category != null) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _isActive,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isActive
                          ? t('上架', 'วางขาย', 'Listed')
                          : t('下架', 'หยุดขาย', 'Unlisted'),
                    ),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final nameZh = _nameZhController.text.trim();
            final nameTh = _nameThController.text.trim();
            final nameEn = _nameEnController.text.trim();
            final name = nameZh.isNotEmpty
                ? nameZh
                : (nameTh.isNotEmpty ? nameTh : nameEn);
            if (name.isEmpty) {
              setState(() => _errorText = i18n.saveFailed);
              return;
            }
            Navigator.pop(
              context,
              _CategoryEditData(
                name: name,
                nameTh: nameTh,
                nameZh: nameZh,
                nameEn: nameEn,
                isActive: _isActive,
              ),
            );
          },
          child: Text(i18n.save),
        ),
      ],
    );
  }
}

class _CategoryEditData {
  const _CategoryEditData({
    required this.name,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    required this.isActive,
  });

  final String name;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
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
