import 'package:flutter/material.dart';

import '../l10n/app_i18n.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/promotion_rule.dart';
import '../state/pos_controller.dart';

class PromotionManagementPage extends StatefulWidget {
  const PromotionManagementPage({super.key, required this.controller});

  final PosController controller;

  @override
  State<PromotionManagementPage> createState() =>
      _PromotionManagementPageState();
}

class _PromotionManagementPageState extends State<PromotionManagementPage> {
  bool _loading = true;
  String? _error;
  List<PromotionRule> _rules = const [];
  List<Product> _products = const [];
  List<ProductCategory> _categories = const [];

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
      final rules = await widget.controller.loadPromotionRulesForManagement();
      final products = await widget.controller.loadAllProductsForManagement();
      final categories = await widget.controller.loadCategoriesForManagement(
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _products = products
            .where((item) => !_isAddonCategory(item.category))
            .toList(growable: false);
        _categories = categories
            .where((item) => !_isAddonCategory(item.name))
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
    final i18n = widget.controller.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(t('活动管理', 'จัดการโปรโมชัน', 'Promotion Management')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            label: Text(t('新增活动', 'เพิ่มโปรโมชัน', 'Add Promotion')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _rules.isEmpty
            ? Center(
                child: Text(
                  t('暂无活动规则', 'ยังไม่มีกฎโปรโมชัน', 'No promotion rules yet'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _rules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final rule = _rules[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
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
                                  Text(
                                    rule.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _RuleTypeChip(
                                    type: rule.type,
                                    language: i18n.language,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${t('优先级', 'ลำดับความสำคัญ', 'Priority')} ${rule.priority}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _ruleDesc(rule),
                                style: const TextStyle(color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rule.isActive
                                    ? t('启用中', 'เปิดใช้งาน', 'Enabled')
                                    : t('已停用', 'ปิดใช้งาน', 'Disabled'),
                                style: TextStyle(
                                  color: rule.isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openEdit(rule),
                          child: Text(t('编辑', 'แก้ไข', 'Edit')),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.controller.deletePromotionRule(
                              rule.id,
                            );
                            await _load();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: Text(t('删除', 'ลบ', 'Delete')),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _ruleDesc(PromotionRule rule) {
    final i18n = widget.controller.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    switch (rule.type) {
      case PromotionType.comboPrice:
        final requiredCategory =
            (rule.condition['requiredCategory'] as String?) ?? '';
        final targetCategory =
            (rule.condition['targetCategory'] as String?) ?? '';
        final targetIds =
            (rule.condition['targetProductIds'] as List?) ?? const [];
        final discountAmount =
            (rule.benefit['discountAmount'] as num?)?.toDouble() ?? 0;
        final legacyBundlePrice =
            (rule.benefit['bundlePrice'] as num?)?.toDouble() ?? 0;
        final targetText = targetCategory.isNotEmpty
            ? '${t('分类', 'หมวดหมู่', 'Category')}: ${widget.controller.categoryDisplayLabel(targetCategory)}'
            : '${t('商品数', 'จำนวนสินค้า', 'Products')}: ${targetIds.length}';
        if (discountAmount > 0) {
          return '${t('组合优惠', 'โปรคู่สินค้า', 'Bundle Promo')}: ${t('有', 'เมื่อมี', 'When has')}「${widget.controller.categoryDisplayLabel(requiredCategory)}」${t('时，目标', 'เป้าหมาย', ', target')}($targetText) ${t('每件减', 'ลดต่อชิ้น', 'off per item')} $discountAmount';
        }
        if (legacyBundlePrice > 0) {
          return '${t('组合优惠(旧规则)', 'โปรคู่สินค้า (กฎเก่า)', 'Bundle Promo (Legacy)')}: ${t('有', 'เมื่อมี', 'When has')}「${widget.controller.categoryDisplayLabel(requiredCategory)}」${t('时，目标', 'เป้าหมาย', ', target')}($targetText) ${t('单价', 'ราคา/ชิ้น', 'unit')} $legacyBundlePrice';
        }
        return '${t('组合优惠', 'โปรคู่สินค้า', 'Bundle Promo')}: ${t('有', 'เมื่อมี', 'When has')}「${widget.controller.categoryDisplayLabel(requiredCategory)}」${t('时，目标', 'เป้าหมาย', ', target')}($targetText)';
      case PromotionType.fullReduce:
        final threshold =
            (rule.condition['threshold'] as num?)?.toDouble() ?? 0;
        final reduce = (rule.benefit['reduce'] as num?)?.toDouble() ?? 0;
        return '${t('满减', 'ลดเมื่อครบยอด', 'Spend & Save')}: ${t('满', 'ครบ', 'Spend')} $threshold ${t('减', 'ลด', 'save')} $reduce';
      case PromotionType.nthDiscount:
        final nth = (rule.condition['nth'] as num?)?.toInt() ?? 2;
        final discountPercent =
            (rule.benefit['discountPercent'] as num?)?.toDouble() ?? 0;
        final targetCategory =
            (rule.condition['targetCategory'] as String?) ?? '';
        final targetIds =
            (rule.condition['targetProductIds'] as List?) ?? const [];
        final targetText = targetCategory.isNotEmpty
            ? '${t('分类', 'หมวดหมู่', 'Category')}: ${widget.controller.categoryDisplayLabel(targetCategory)}'
            : '${t('商品数', 'จำนวนสินค้า', 'Products')}: ${targetIds.length}';
        return '${t('第N件折扣', 'ส่วนลดชิ้นที่ N', 'Nth-item Discount')}: ${t('目标', 'เป้าหมาย', 'Target')}($targetText) ${t('第', 'ชิ้นที่', '#')} $nth ${t('件打', 'ลด', 'discount')} ${discountPercent.toStringAsFixed(0)}%';
    }
  }

  Future<void> _openCreate() async {
    final data = await showDialog<_PromotionEditData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PromotionEditDialog(
        products: _products,
        categories: _categories,
        language: widget.controller.language,
      ),
    );
    if (data == null) return;
    await widget.controller.createPromotionRule(
      name: data.name,
      type: data.type,
      priority: data.priority,
      isActive: data.isActive,
      applyInStore: data.applyInStore,
      applyDelivery: data.applyDelivery,
      condition: data.condition,
      benefit: data.benefit,
    );
    await _load();
  }

  Future<void> _openEdit(PromotionRule rule) async {
    final data = await showDialog<_PromotionEditData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PromotionEditDialog(
        existing: rule,
        products: _products,
        categories: _categories,
        language: widget.controller.language,
      ),
    );
    if (data == null) return;
    await widget.controller.updatePromotionRule(
      id: rule.id,
      name: data.name,
      type: data.type,
      priority: data.priority,
      isActive: data.isActive,
      applyInStore: data.applyInStore,
      applyDelivery: data.applyDelivery,
      condition: data.condition,
      benefit: data.benefit,
    );
    await _load();
  }

  bool _isAddonCategory(String category) {
    final value = category.trim().toLowerCase();
    return value == '加料' ||
        value == '小料' ||
        value == 'topping' ||
        value == 'addons';
  }
}

enum _TargetMode { productIds, category }

class _PromotionEditDialog extends StatefulWidget {
  const _PromotionEditDialog({
    required this.products,
    required this.categories,
    required this.language,
    this.existing,
  });

  final PromotionRule? existing;
  final List<Product> products;
  final List<ProductCategory> categories;
  final AppLanguage language;

  @override
  State<_PromotionEditDialog> createState() => _PromotionEditDialogState();
}

class _PromotionEditDialogState extends State<_PromotionEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priorityController;
  late final TextEditingController _requiredCategoryController;
  late final TextEditingController _valueAController;
  late final TextEditingController _valueBController;
  PromotionType _type = PromotionType.comboPrice;
  _TargetMode _targetMode = _TargetMode.productIds;
  bool _isActive = true;
  bool _applyInStore = true;
  String _targetCategory = '';
  final Set<int> _targetIds = <int>{};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _priorityController = TextEditingController(
      text: (existing?.priority ?? 100).toString(),
    );
    _type = existing?.type ?? PromotionType.comboPrice;
    _isActive = existing?.isActive ?? true;
    _applyInStore = existing?.applyInStore ?? true;
    _requiredCategoryController = TextEditingController(
      text: (existing?.condition['requiredCategory'] as String?) ?? '奶茶',
    );
    _targetCategory = (existing?.condition['targetCategory'] as String?) ?? '';
    final targetIds =
        (existing?.condition['targetProductIds'] as List?) ?? const [];
    _targetIds.addAll(
      targetIds.map((e) => (e as num?)?.toInt()).whereType<int>(),
    );
    _targetMode = _targetCategory.trim().isNotEmpty
        ? _TargetMode.category
        : _TargetMode.productIds;

    if (_type == PromotionType.comboPrice) {
      _valueAController = TextEditingController(
        text:
            ((existing?.benefit['discountAmount'] as num?)?.toDouble() ??
                    (existing?.benefit['bundlePrice'] as num?)?.toDouble() ??
                    5)
                .toStringAsFixed(0),
      );
      _valueBController = TextEditingController(
        text: ((existing?.condition['maxApplications'] as num?)?.toInt() ?? 0)
            .toString(),
      );
    } else if (_type == PromotionType.fullReduce) {
      _valueAController = TextEditingController(
        text: ((existing?.condition['threshold'] as num?)?.toDouble() ?? 100)
            .toStringAsFixed(0),
      );
      _valueBController = TextEditingController(
        text: ((existing?.benefit['reduce'] as num?)?.toDouble() ?? 10)
            .toStringAsFixed(0),
      );
    } else {
      _valueAController = TextEditingController(
        text: ((existing?.condition['nth'] as num?)?.toInt() ?? 2).toString(),
      );
      _valueBController = TextEditingController(
        text: ((existing?.benefit['discountPercent'] as num?)?.toDouble() ?? 50)
            .toStringAsFixed(0),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priorityController.dispose();
    _requiredCategoryController.dispose();
    _valueAController.dispose();
    _valueBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String zh, String th, String en) => switch (widget.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final categoryOptions =
        widget.categories.map((e) => e.name).toSet().toList()..sort();
    final targetCategoryValue =
        _targetCategory.isNotEmpty && categoryOptions.contains(_targetCategory)
        ? _targetCategory
        : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogContentHeight = (screenHeight - viewInsetsBottom - 220)
        .clamp(240.0, screenHeight * 0.78)
        .toDouble();
    final compact = screenWidth < 760;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null
            ? t('新增活动', 'เพิ่มโปรโมชัน', 'Add Promotion')
            : t('编辑活动', 'แก้ไขโปรโมชัน', 'Edit Promotion'),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
        child: SizedBox(
          width: compact ? screenWidth * 0.9 : 720,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: t('活动名称', 'ชื่อโปรโมชัน', 'Promotion Name'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (compact) ...[
                  DropdownButtonFormField<PromotionType>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: t('活动类型', 'ประเภทโปรโมชัน', 'Promotion Type'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PromotionType.comboPrice,
                        child: Text(t('组合优惠', 'โปรคู่สินค้า', 'Bundle Promo')),
                      ),
                      DropdownMenuItem(
                        value: PromotionType.fullReduce,
                        child: Text(t('满减', 'ลดเมื่อครบยอด', 'Spend & Save')),
                      ),
                      DropdownMenuItem(
                        value: PromotionType.nthDiscount,
                        child: Text(
                          t('第N件折扣', 'ส่วนลดชิ้นที่ N', 'Nth-item Discount'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priorityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('优先级', 'ลำดับความสำคัญ', 'Priority'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PromotionType>(
                          initialValue: _type,
                          decoration: InputDecoration(
                            labelText: t(
                              '活动类型',
                              'ประเภทโปรโมชัน',
                              'Promotion Type',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: PromotionType.comboPrice,
                              child: Text(
                                t('组合优惠', 'โปรคู่สินค้า', 'Bundle Promo'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: PromotionType.fullReduce,
                              child: Text(
                                t('满减', 'ลดเมื่อครบยอด', 'Spend & Save'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: PromotionType.nthDiscount,
                              child: Text(
                                t(
                                  '第N件折扣',
                                  'ส่วนลดชิ้นที่ N',
                                  'Nth-item Discount',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _type = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _priorityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t('优先级', 'ลำดับความสำคัญ', 'Priority'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (compact) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('启用', 'เปิดใช้งาน', 'Enabled')),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('堂食可用', 'ใช้ได้หน้าร้าน', 'In-store')),
                    value: _applyInStore,
                    onChanged: (v) => setState(() => _applyInStore = v),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t('外卖不参与优惠', 'เดลิเวอรี่ไม่ร่วมโปร', 'Delivery excluded'),
                    ),
                    subtitle: Text(t('固定关闭', 'ปิดถาวร', 'Always off')),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t('启用', 'เปิดใช้งาน', 'Enabled')),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t('堂食可用', 'ใช้ได้หน้าร้าน', 'In-store')),
                          value: _applyInStore,
                          onChanged: (v) => setState(() => _applyInStore = v),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          dense: true,
                          title: Text(
                            t(
                              '外卖不参与优惠',
                              'เดลิเวอรี่ไม่ร่วมโปร',
                              'Delivery excluded',
                            ),
                          ),
                          subtitle: Text(t('固定关闭', 'ปิดถาวร', 'Always off')),
                        ),
                      ),
                    ],
                  ),
                const Divider(),
                if (_type == PromotionType.comboPrice) ...[
                  TextField(
                    controller: _requiredCategoryController,
                    decoration: InputDecoration(
                      labelText: t(
                        '触发分类（如 奶茶）',
                        'หมวดหมู่ที่เป็นเงื่อนไข',
                        'Trigger category',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTargetSelector(categoryOptions, targetCategoryValue),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _valueAController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: t(
                              '每件优惠金额',
                              'ส่วนลดต่อชิ้น',
                              'Discount per item',
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _valueBController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t(
                              '每单最多应用次数(0=不限)',
                              'สูงสุดต่อบิล (0=ไม่จำกัด)',
                              'Max per order (0=unlimited)',
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_type == PromotionType.fullReduce) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _valueAController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: t('满多少', 'ครบยอดเท่าไร', 'Threshold'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _valueBController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: t('减多少', 'ลดเท่าไร', 'Discount amount'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildTargetSelector(categoryOptions, targetCategoryValue),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _valueAController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t('第几件', 'ชิ้นที่เท่าไร', 'Nth item'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _valueBController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: t(
                              '折扣百分比(%)',
                              'เปอร์เซ็นต์ส่วนลด(%)',
                              'Discount percent (%)',
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('取消', 'ยกเลิก', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(t('保存', 'บันทึก', 'Save')),
        ),
      ],
    );
  }

  String _localizedCategory(String raw) {
    for (final c in widget.categories) {
      if (c.name == raw) return c.localizedName(widget.language.name);
    }
    return raw;
  }

  Widget _buildTargetSelector(
    List<String> categoryOptions,
    String? targetCategoryValue,
  ) {
    String t(String zh, String th, String en) => switch (widget.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t('绑定目标', 'ตั้งค่าเป้าหมาย', 'Target Binding')),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(t('按商品', 'ตามสินค้า', 'By Product')),
                selected: _targetMode == _TargetMode.productIds,
                onSelected: (_) =>
                    setState(() => _targetMode = _TargetMode.productIds),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(t('按分类', 'ตามหมวดหมู่', 'By Category')),
                selected: _targetMode == _TargetMode.category,
                onSelected: (_) =>
                    setState(() => _targetMode = _TargetMode.category),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_targetMode == _TargetMode.category)
            DropdownButtonFormField<String>(
              initialValue: targetCategoryValue,
              decoration: InputDecoration(
                labelText: t('目标分类', 'หมวดหมู่เป้าหมาย', 'Target Category'),
                border: OutlineInputBorder(),
              ),
              items: categoryOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(_localizedCategory(e)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _targetCategory = value);
              },
            )
          else
            SizedBox(
              height: 170,
              child: ListView(
                children: widget.products
                    .map(
                      (p) => CheckboxListTile(
                        value: _targetIds.contains(p.id),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${p.localizedName(widget.language.name)} (#${p.id})',
                        ),
                        subtitle: Text(_localizedCategory(p.category)),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _targetIds.add(p.id);
                            } else {
                              _targetIds.remove(p.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final priority = int.tryParse(_priorityController.text.trim()) ?? 100;
    if (name.isEmpty) return;
    Map<String, dynamic> condition = <String, dynamic>{};
    Map<String, dynamic> benefit = <String, dynamic>{};
    final needsTarget =
        _type == PromotionType.comboPrice || _type == PromotionType.nthDiscount;
    if (needsTarget) {
      if (_targetMode == _TargetMode.category &&
          _targetCategory.trim().isEmpty) {
        return;
      }
      if (_targetMode == _TargetMode.productIds && _targetIds.isEmpty) {
        return;
      }
    }
    if (_type == PromotionType.comboPrice) {
      final price = double.tryParse(_valueAController.text.trim());
      final max = int.tryParse(_valueBController.text.trim()) ?? 0;
      if (price == null || price <= 0) return;
      condition = {
        'requiredCategory': _requiredCategoryController.text.trim(),
        'maxApplications': max,
        if (_targetMode == _TargetMode.category)
          'targetCategory': _targetCategory.trim(),
        if (_targetMode == _TargetMode.productIds)
          'targetProductIds': _targetIds.toList(growable: false),
      };
      benefit = {'discountAmount': price};
    } else if (_type == PromotionType.fullReduce) {
      final threshold = double.tryParse(_valueAController.text.trim());
      final reduce = double.tryParse(_valueBController.text.trim());
      if (threshold == null || threshold <= 0) return;
      if (reduce == null || reduce <= 0) return;
      condition = {'threshold': threshold};
      benefit = {'reduce': reduce};
    } else {
      final nth = int.tryParse(_valueAController.text.trim()) ?? 0;
      final discountPercent = double.tryParse(_valueBController.text.trim());
      if (nth < 2) return;
      if (discountPercent == null ||
          discountPercent <= 0 ||
          discountPercent >= 100) {
        return;
      }
      condition = {
        'nth': nth,
        if (_targetMode == _TargetMode.category)
          'targetCategory': _targetCategory.trim(),
        if (_targetMode == _TargetMode.productIds)
          'targetProductIds': _targetIds.toList(growable: false),
      };
      benefit = {'discountPercent': discountPercent};
    }
    Navigator.of(context).pop(
      _PromotionEditData(
        name: name,
        type: _type,
        priority: priority,
        isActive: _isActive,
        applyInStore: _applyInStore,
        applyDelivery: false,
        condition: condition,
        benefit: benefit,
      ),
    );
  }
}

class _PromotionEditData {
  const _PromotionEditData({
    required this.name,
    required this.type,
    required this.priority,
    required this.isActive,
    required this.applyInStore,
    required this.applyDelivery,
    required this.condition,
    required this.benefit,
  });

  final String name;
  final PromotionType type;
  final int priority;
  final bool isActive;
  final bool applyInStore;
  final bool applyDelivery;
  final Map<String, dynamic> condition;
  final Map<String, dynamic> benefit;
}

class _RuleTypeChip extends StatelessWidget {
  const _RuleTypeChip({required this.type, required this.language});

  final PromotionType type;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      PromotionType.comboPrice => (
        switch (language) {
          AppLanguage.th => 'โปรคู่สินค้า',
          AppLanguage.en => 'Bundle Promo',
          AppLanguage.zh => '组合优惠',
        },
        const Color(0xFF1565C0),
      ),
      PromotionType.fullReduce => (
        switch (language) {
          AppLanguage.th => 'ลดเมื่อครบยอด',
          AppLanguage.en => 'Spend & Save',
          AppLanguage.zh => '满减',
        },
        const Color(0xFF2E7D32),
      ),
      PromotionType.nthDiscount => (
        switch (language) {
          AppLanguage.th => 'ส่วนลดชิ้นที่ N',
          AppLanguage.en => 'Nth-item Discount',
          AppLanguage.zh => '第N件折扣',
        },
        const Color(0xFF6A1B9A),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
