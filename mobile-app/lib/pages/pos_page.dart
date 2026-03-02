import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'checkout_page.dart';
import 'suspended_orders_page.dart';
import '../l10n/app_i18n.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/spec_option.dart';
import '../services/receipt_print_service.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

const _blue = Color(0xFF1976D2);
const _blueBorder = Color(0xFF90CAF9);
const _receiptPrinter = ReceiptPrintService();

class _OptionChipWrap extends StatelessWidget {
  const _OptionChipWrap({
    required this.selected,
    required this.maxWidth,
    required this.child,
  });

  final bool selected;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
  }
}

class PosPage extends StatelessWidget {
  const PosPage({super.key, required this.controller});

  final PosController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final i18n = controller.i18n;
        return Scaffold(
          appBar: AppBar(
            title: Text(i18n.posTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${controller.beverageProducts.length} ${i18n.productsUnit}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape =
                        constraints.maxWidth > constraints.maxHeight;
                    final isWide = constraints.maxWidth >= 900;

                    if (isLandscape || isWide) {
                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _ProductPanel(
                              controller: controller,
                              i18n: i18n,
                            ),
                          ),
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: const Color(0xFFDCEBFA),
                          ),
                          Expanded(
                            flex: 2,
                            child: _CartPanel(
                              controller: controller,
                              i18n: i18n,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _ProductPanel(
                            controller: controller,
                            i18n: i18n,
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFDCEBFA)),
                        Expanded(
                          flex: 2,
                          child: _CartPanel(controller: controller, i18n: i18n),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: SafeArea(
                  child: _PrinterStatusIndicators(controller: controller),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _PrinterConnState { checking, online, offline, notConfigured }

class _PrinterStatusIndicators extends StatefulWidget {
  const _PrinterStatusIndicators({required this.controller});

  final PosController controller;

  @override
  State<_PrinterStatusIndicators> createState() =>
      _PrinterStatusIndicatorsState();
}

class _PrinterStatusIndicatorsState extends State<_PrinterStatusIndicators> {
  static const _defaultPorts = <int>[9100, 9101, 9102, 8008];
  _PrinterConnState _receiptState = _PrinterConnState.checking;
  _PrinterConnState _labelState = _PrinterConnState.checking;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final receiptIp = (await widget.controller.settingsStore.loadPrinterIp())
          ?.trim();
      final labelIp =
          (await widget.controller.settingsStore.loadLabelPrinterIp())?.trim();
      final receiptState = await _probeByIp(receiptIp);
      final labelState = await _probeByIp(labelIp);
      if (!mounted) return;
      setState(() {
        _receiptState = receiptState;
        _labelState = labelState;
      });
    } finally {
      _checking = false;
    }
  }

  Future<_PrinterConnState> _probeByIp(String? ip) async {
    if (kIsWeb) return _PrinterConnState.notConfigured;
    final host = (ip ?? '').trim();
    if (host.isEmpty) return _PrinterConnState.notConfigured;
    for (final port in _defaultPorts) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 700),
        );
        await socket.close();
        return _PrinterConnState.online;
      } catch (_) {
        await socket?.close();
      }
    }
    return _PrinterConnState.offline;
  }

  Color _stateColor(_PrinterConnState state) {
    return switch (state) {
      _PrinterConnState.online => const Color(0xFF2E7D32),
      _PrinterConnState.offline => const Color(0xFFD32F2F),
      _PrinterConnState.notConfigured => const Color(0xFF90A4AE),
      _PrinterConnState.checking => const Color(0xFF1976D2),
    };
  }

  String _stateText(_PrinterConnState state) {
    final i18n = widget.controller.i18n;
    return switch (state) {
      _PrinterConnState.online => switch (i18n.language) {
        AppLanguage.th => '已连接',
        AppLanguage.en => 'Online',
        AppLanguage.zh => '已连接',
      },
      _PrinterConnState.offline => switch (i18n.language) {
        AppLanguage.th => '离线',
        AppLanguage.en => 'Offline',
        AppLanguage.zh => '离线',
      },
      _PrinterConnState.notConfigured => switch (i18n.language) {
        AppLanguage.th => '未设置',
        AppLanguage.en => 'Not set',
        AppLanguage.zh => '未设置',
      },
      _PrinterConnState.checking => switch (i18n.language) {
        AppLanguage.th => '检测中',
        AppLanguage.en => 'Checking',
        AppLanguage.zh => '检测中',
      },
    };
  }

  String _labelText({required bool isLabelPrinter}) {
    final i18n = widget.controller.i18n;
    if (isLabelPrinter) {
      return switch (i18n.language) {
        AppLanguage.th => '标签机',
        AppLanguage.en => 'Label',
        AppLanguage.zh => '标签机',
      };
    }
    return switch (i18n.language) {
      AppLanguage.th => '小票机',
      AppLanguage.en => 'Receipt',
      AppLanguage.zh => '小票机',
    };
  }

  Widget _statusIcon({
    required bool isLabelPrinter,
    required _PrinterConnState state,
  }) {
    return Tooltip(
      message:
          '${_labelText(isLabelPrinter: isLabelPrinter)}: ${_stateText(state)}',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _stateColor(state),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x402E7D32),
              blurRadius: 2,
              spreadRadius: 0.2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showReceipt = _receiptState == _PrinterConnState.online;
    final showLabel = _labelState == _PrinterConnState.online;
    if (!showReceipt && !showLabel) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showReceipt)
            _statusIcon(isLabelPrinter: false, state: _receiptState),
          if (showReceipt && showLabel) const SizedBox(width: 6),
          if (showLabel) _statusIcon(isLabelPrinter: true, state: _labelState),
        ],
      ),
    );
  }
}

enum _PromoFilterType { all, discount, normal }

class _ProductPanel extends StatefulWidget {
  const _ProductPanel({required this.controller, required this.i18n});

  final PosController controller;
  final AppI18n i18n;

  @override
  State<_ProductPanel> createState() => _ProductPanelState();
}

class _ProductPanelState extends State<_ProductPanel> {
  _PromoFilterType _promoFilterType = _PromoFilterType.all;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchKeyword,
    );
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final i18n = widget.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final products = controller.filteredProducts
        .where((item) {
          return switch (_promoFilterType) {
            _PromoFilterType.all => true,
            _PromoFilterType.discount => item.hasPromotion,
            _PromoFilterType.normal => !item.hasPromotion,
          };
        })
        .toList(growable: false);
    final allCategoryCount = controller.beverageProducts.length;
    final categoryCountMap = <String, int>{};
    for (final product in controller.beverageProducts) {
      categoryCountMap.update(
        product.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final visibleCategories = controller.categories
        .where((category) {
          if (category == AppI18n.allCategoryKey) return allCategoryCount > 0;
          return (categoryCountMap[category] ?? 0) > 0;
        })
        .toList(growable: false);
    if (!visibleCategories.contains(controller.selectedCategory) &&
        visibleCategories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setCategory(AppI18n.allCategoryKey);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _searchExpanded ? 220 : 40,
                  height: 40,
                  child: _searchExpanded
                      ? TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: i18n.searchHint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: () {
                                _searchController.clear();
                                controller.setSearch('');
                                _searchFocusNode.unfocus();
                                setState(() => _searchExpanded = false);
                              },
                              icon: const Icon(Icons.close),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                          ),
                          onChanged: controller.setSearch,
                        )
                      : OutlinedButton(
                          onPressed: () {
                            setState(() => _searchExpanded = true);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: _blueBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.search),
                        ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 132,
                  height: 40,
                  child: DropdownButtonFormField<_PromoFilterType>(
                    key: ValueKey('_promo_${_promoFilterType.name}'),
                    initialValue: _promoFilterType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _PromoFilterType.all,
                        child: Text(
                          t('全部商品', 'สินค้าทั้งหมด', 'All Items'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: _PromoFilterType.discount,
                        child: Text(
                          t('折扣商品', 'สินค้าลดราคา', 'Discounted'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: _PromoFilterType.normal,
                        child: Text(
                          t('正常商品', 'สินค้าปกติ', 'Regular'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selectedItemBuilder: (context) => [
                      Text(
                        t('全部商品', 'สินค้าทั้งหมด', 'All Items'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        t('折扣商品', 'สินค้าลดราคา', 'Discounted'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        t('正常商品', 'สินค้าปกติ', 'Regular'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _promoFilterType = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                const Spacer(),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    controller.setSearch('');
                    controller.setCategory(AppI18n.allCategoryKey);
                    setState(() {
                      _promoFilterType = _PromoFilterType.all;
                      _searchExpanded = false;
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: Text(i18n.reset),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      int index = 0;
                      index < visibleCategories.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final category = visibleCategories[index];
                          final count = category == AppI18n.allCategoryKey
                              ? allCategoryCount
                              : (categoryCountMap[category] ?? 0);
                          final baseLabel = category == AppI18n.allCategoryKey
                              ? i18n.allCategory
                              : controller.categoryDisplayLabel(category);
                          final isSelected =
                              category == controller.selectedCategory;
                          return ChoiceChip(
                            label: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                children: [
                                  TextSpan(text: baseLabel),
                                  TextSpan(
                                    text: ' $count',
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFD6E9FF)
                                          : const Color(0xFF7A8A9A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            selected: isSelected,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            selectedColor: _blue,
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: _blueBorder,
                              width: 1.2,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => controller.setCategory(category),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final count = width >= 1100
                    ? 5
                    : width >= 850
                    ? 4
                    : width >= 560
                    ? 3
                    : 2;

                if (products.isEmpty) {
                  return Center(child: Text(i18n.noProducts));
                }

                return GridView.builder(
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    final item = products[index];
                    return _ProductCard(
                      product: item,
                      i18n: i18n,
                      onTap: () =>
                          _openAddDialog(context, controller, item, i18n),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDialog(
    BuildContext context,
    PosController controller,
    Product product,
    AppI18n i18n,
  ) async {
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final sizeOptions = controller.sizeOptions;
    final sugarOptions = controller.sugarOptions;
    final iceOptions = controller.iceOptions;
    final toppingOptions = controller.toppingOptions;

    var size = sizeOptions.isNotEmpty ? sizeOptions.first : null;
    var sugar = sugarOptions.isNotEmpty ? sugarOptions.first : null;
    var ice = iceOptions.isNotEmpty ? iceOptions.first : null;
    final selectedToppings = <int>{};
    var note = '';
    String optionLabel(SpecOption option) =>
        option.localizedName(controller.language.name);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final chipMaxWidth = MediaQuery.of(context).size.width * 0.5;
            final enableSize = product.showSize && sizeOptions.isNotEmpty;
            final enableSugar = product.showSugar && sugarOptions.isNotEmpty;
            final enableIce = product.showIce && iceOptions.isNotEmpty;
            final enableToppings =
                product.showToppings && toppingOptions.isNotEmpty;
            final extra = enableSize ? (size?.price ?? 0) : 0.0;
            final toppingTotal = toppingOptions
                .where((item) => selectedToppings.contains(item.id))
                .fold<double>(0, (sum, item) => sum + item.price);
            final preview =
                product.effectivePrice +
                extra +
                (enableToppings ? toppingTotal : 0);
            return AlertDialog(
              title: Text(
                '${i18n.options} · ${product.localizedName(controller.language.name)}',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width < 700
                      ? MediaQuery.of(context).size.width * 0.86
                      : 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enableSize) ...[
                        Text(i18n.size),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: sizeOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: size == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(
                                      e.price > 0
                                          ? '${optionLabel(e)} (+${i18n.formatMoney(e.price)})'
                                          : optionLabel(e),
                                    ),
                                    selected: size == e,
                                    labelStyle: TextStyle(
                                      color: size == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) => setState(() => size = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableSugar) ...[
                        Text(i18n.sugar),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: sugarOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: sugar == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(optionLabel(e)),
                                    selected: sugar == e,
                                    labelStyle: TextStyle(
                                      color: sugar == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) =>
                                        setState(() => sugar = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableIce) ...[
                        Text(i18n.ice),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: iceOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: ice == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(optionLabel(e)),
                                    selected: ice == e,
                                    labelStyle: TextStyle(
                                      color: ice == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) => setState(() => ice = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableToppings) ...[
                        Text(i18n.toppings),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: toppingOptions
                              .map(
                                (item) => _OptionChipWrap(
                                  selected: selectedToppings.contains(item.id),
                                  maxWidth: chipMaxWidth,
                                  child: FilterChip(
                                    label: Text(
                                      item.price > 0
                                          ? '${optionLabel(item)} (+${i18n.formatMoney(item.price)})'
                                          : optionLabel(item),
                                    ),
                                    selected: selectedToppings.contains(
                                      item.id,
                                    ),
                                    labelStyle: TextStyle(
                                      color: selectedToppings.contains(item.id)
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          selectedToppings.add(item.id);
                                        } else {
                                          selectedToppings.remove(item.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      TextField(
                        decoration: InputDecoration(
                          labelText: i18n.note,
                          hintText: i18n.noteHint,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (value) => note = value,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${i18n.total}: ${i18n.formatMoney(preview)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
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
                    try {
                      controller.addProductWithOptions(
                        product: product,
                        sizeName: enableSize
                            ? (size != null ? optionLabel(size!) : '')
                            : '',
                        sizeExtraPrice: enableSize ? (size?.price ?? 0) : 0,
                        sugarName: enableSugar
                            ? (sugar != null ? optionLabel(sugar!) : '')
                            : '',
                        iceName: enableIce
                            ? (ice != null ? optionLabel(ice!) : '')
                            : '',
                        toppings: enableToppings
                            ? toppingOptions
                                  .where(
                                    (item) =>
                                        selectedToppings.contains(item.id),
                                  )
                                  .map(
                                    (item) => ToppingSelection(
                                      id: item.id,
                                      name: optionLabel(item),
                                      price: item.price,
                                    ),
                                  )
                                  .toList(growable: false)
                            : const [],
                        note: note,
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      showLatestSnackBar(
                        context,
                        t(
                          '加入购物车失败: $e',
                          'เพิ่มลงตะกร้าไม่สำเร็จ: $e',
                          'Add to cart failed: $e',
                        ),
                      );
                    }
                  },
                  child: Text(i18n.addToCart),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.i18n,
    required this.onTap,
  });

  final Product product;
  final AppI18n i18n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBDEFB)),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    color: const Color(0xFFF5F9FF),
                    child: _ProductImage(
                      imageUrl: (product.imageUrl ?? '').trim().isEmpty
                          ? null
                          : product.imageUrl!.trim(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: product.localizedName(
                                    i18n.language.name,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '  ${i18n.categoryLabel(product.category)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: (product.description ?? '').trim().isNotEmpty
                              ? Text(
                                  product.description!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        product.hasPromotion
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    i18n.formatMoney(product.effectivePrice),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    i18n.formatMoney(product.price),
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.black54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                i18n.formatMoney(product.price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _ProductImageFallback();
    }
    final value = imageUrl!.startsWith('file://')
        ? Uri.parse(imageUrl!).toFilePath()
        : imageUrl!;
    final isHttp = value.startsWith('http://') || value.startsWith('https://');
    if (!isHttp && !kIsWeb) {
      return Image.file(
        File(value),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _ProductImageFallback(),
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _ProductImageFallback(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF90A4AE)),
    );
  }
}

class _CartPanel extends StatefulWidget {
  const _CartPanel({required this.controller, required this.i18n});

  final PosController controller;
  final AppI18n i18n;

  @override
  State<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<_CartPanel> {
  bool _matchesSpecOptionLabel(
    SpecOption option,
    String selectedLabel,
    String languageCode,
  ) {
    final needle = selectedLabel.trim();
    if (needle.isEmpty) return false;
    if (option.localizedName(languageCode) == needle) return true;
    if (option.name.trim() == needle) return true;
    if ((option.nameZh ?? '').trim() == needle) return true;
    if ((option.nameTh ?? '').trim() == needle) return true;
    if ((option.nameEn ?? '').trim() == needle) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final i18n = widget.i18n;
    final inStorePricing = controller.previewPricing(OrderType.inStore);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                i18n.cartTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 2,
                children: [
                  TextButton(
                    onPressed: controller.cart.isEmpty
                        ? null
                        : () => _openSuspendDialog(context, controller, i18n),
                    child: Text(i18n.suspend),
                  ),
                  TextButton(
                    onPressed: () =>
                        _openResumeSheet(context, controller, i18n),
                    child: Text(i18n.resume),
                  ),
                  TextButton(
                    onPressed: controller.cart.isEmpty
                        ? null
                        : controller.clearCart,
                    child: Text(i18n.clear),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: controller.cart.isEmpty
                ? Center(child: Text(i18n.emptyCartHint))
                : ListView.builder(
                    itemCount: controller.cart.length,
                    itemBuilder: (context, index) {
                      final item = controller.cart[index];
                      return _CartItemTile(
                        item: item,
                        i18n: i18n,
                        onAdd: () => controller.increase(item),
                        onMinus: () => controller.decrease(item),
                        onDelete: () => controller.remove(item),
                        onEdit: () => _openEditDialog(context, item),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          _AmountRow(
            label: i18n.subtotal,
            value: inStorePricing.rawSubtotal,
            i18n: i18n,
          ),
          if (inStorePricing.productDiscountAmount > 0)
            _AmountRow(
              label: i18n.productDiscount,
              value: -inStorePricing.productDiscountAmount,
              i18n: i18n,
            ),
          if (inStorePricing.promoAmount > 0)
            _AmountRow(
              label: i18n.activityDiscount,
              value: -inStorePricing.promoAmount,
              i18n: i18n,
              valueColor: const Color(0xFFD32F2F),
            ),
          _AmountRow(
            label: i18n.total,
            value: inStorePricing.total,
            i18n: i18n,
            emphasis: true,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: controller.canCheckout
                ? () => _openCheckoutDialog(context, controller, i18n)
                : null,
            icon: controller.isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.point_of_sale),
            label: Text(i18n.openCheckout),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context, CartItem item) async {
    final i18n = widget.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final sizeOptions = widget.controller.sizeOptions;
    final sugarOptions = widget.controller.sugarOptions;
    final iceOptions = widget.controller.iceOptions;
    final toppingOptions = widget.controller.toppingOptions;
    final enableSize = item.product.showSize && sizeOptions.isNotEmpty;
    final enableSugar = item.product.showSugar && sugarOptions.isNotEmpty;
    final enableIce = item.product.showIce && iceOptions.isNotEmpty;
    final enableToppings =
        item.product.showToppings && toppingOptions.isNotEmpty;
    final languageCode = widget.controller.language.name;
    final sizeMatched = sizeOptions.where(
      (e) => _matchesSpecOptionLabel(e, item.sizeName, languageCode),
    );
    final sugarMatched = sugarOptions.where(
      (e) => _matchesSpecOptionLabel(e, item.sugarName, languageCode),
    );
    final iceMatched = iceOptions.where(
      (e) => _matchesSpecOptionLabel(e, item.iceName, languageCode),
    );
    var size = enableSize
        ? (sizeMatched.isNotEmpty ? sizeMatched.first : sizeOptions.first)
        : null;
    var sugar = enableSugar
        ? (sugarMatched.isNotEmpty ? sugarMatched.first : sugarOptions.first)
        : null;
    var ice = enableIce
        ? (iceMatched.isNotEmpty ? iceMatched.first : iceOptions.first)
        : null;
    final selectedToppings = enableToppings
        ? item.toppings.map((e) => e.id).toSet()
        : <int>{};
    var note = item.note;
    String optionLabel(SpecOption option) =>
        option.localizedName(widget.controller.language.name);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final chipMaxWidth = MediaQuery.of(context).size.width * 0.5;
            return AlertDialog(
              title: Text(
                '${i18n.editItem}: ${item.product.localizedName(widget.controller.language.name)}',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width < 700
                      ? MediaQuery.of(context).size.width * 0.86
                      : 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enableSize) ...[
                        Text(i18n.size),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: sizeOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: size == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(
                                      e.price > 0
                                          ? '${optionLabel(e)} (+${i18n.formatMoney(e.price)})'
                                          : optionLabel(e),
                                    ),
                                    selected: size == e,
                                    labelStyle: TextStyle(
                                      color: size == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) => setState(() => size = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableSugar) ...[
                        Text(i18n.sugar),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: sugarOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: sugar == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(optionLabel(e)),
                                    selected: sugar == e,
                                    labelStyle: TextStyle(
                                      color: sugar == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) =>
                                        setState(() => sugar = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableIce) ...[
                        Text(i18n.ice),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: iceOptions
                              .map(
                                (e) => _OptionChipWrap(
                                  selected: ice == e,
                                  maxWidth: chipMaxWidth,
                                  child: ChoiceChip(
                                    label: Text(optionLabel(e)),
                                    selected: ice == e,
                                    labelStyle: TextStyle(
                                      color: ice == e
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) => setState(() => ice = e),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (enableToppings) ...[
                        Text(i18n.toppings),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: toppingOptions
                              .map(
                                (top) => _OptionChipWrap(
                                  selected: selectedToppings.contains(top.id),
                                  maxWidth: chipMaxWidth,
                                  child: FilterChip(
                                    label: Text(
                                      top.price > 0
                                          ? '${optionLabel(top)} (+${i18n.formatMoney(top.price)})'
                                          : optionLabel(top),
                                    ),
                                    selected: selectedToppings.contains(top.id),
                                    labelStyle: TextStyle(
                                      color: selectedToppings.contains(top.id)
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          selectedToppings.add(top.id);
                                        } else {
                                          selectedToppings.remove(top.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                      ],
                      TextFormField(
                        initialValue: note,
                        decoration: InputDecoration(
                          labelText: i18n.note,
                          hintText: i18n.noteHint,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (value) => note = value,
                      ),
                    ],
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
                    try {
                      widget.controller.updateItemOptions(
                        item: item,
                        sizeName: enableSize
                            ? (size != null ? optionLabel(size!) : '')
                            : '',
                        sizeExtraPrice: enableSize ? (size?.price ?? 0) : 0,
                        sugarName: enableSugar
                            ? (sugar != null ? optionLabel(sugar!) : '')
                            : '',
                        iceName: enableIce
                            ? (ice != null ? optionLabel(ice!) : '')
                            : '',
                        toppings: enableToppings
                            ? toppingOptions
                                  .where(
                                    (top) => selectedToppings.contains(top.id),
                                  )
                                  .map(
                                    (top) => ToppingSelection(
                                      id: top.id,
                                      name: optionLabel(top),
                                      price: top.price,
                                    ),
                                  )
                                  .toList(growable: false)
                            : const [],
                        note: note,
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      showLatestSnackBar(
                        context,
                        t(
                          '保存规格失败: $e',
                          'บันทึกตัวเลือกไม่สำเร็จ: $e',
                          'Save options failed: $e',
                        ),
                      );
                    }
                  },
                  child: Text(i18n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSuspendDialog(
    BuildContext context,
    PosController controller,
    AppI18n i18n,
  ) async {
    var label = '';
    final ticket = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSaving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(i18n.suspend),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: label,
                      autofocus: false,
                      decoration: InputDecoration(
                        labelText: i18n.note,
                        hintText: i18n.noteHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => label = value,
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text(i18n.cancel),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        try {
                          final ticket = await controller
                              .suspendCurrentCart(label: label)
                              .timeout(const Duration(seconds: 8));
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, ticket);
                        } on TimeoutException {
                          if (dialogContext.mounted) {
                            setState(() {
                              isSaving = false;
                              errorText = switch (i18n.language) {
                                AppLanguage.th => 'พักบิลหมดเวลา กรุณาลองใหม่',
                                AppLanguage.en =>
                                  'Suspend order timed out. Please retry.',
                                AppLanguage.zh => '挂单超时，请重试',
                              };
                            });
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setState(() {
                              isSaving = false;
                              errorText = '$e';
                            });
                          }
                        }
                      },
                child: Text(i18n.save),
              ),
            ],
          ),
        );
      },
    );
    if (ticket != null && context.mounted) {
      showLatestSnackBar(context, '${i18n.suspend}: $ticket');
    }
  }

  Future<void> _openResumeSheet(
    BuildContext context,
    PosController controller,
    AppI18n i18n,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SuspendedOrdersPage(controller: controller, i18n: i18n),
      ),
    );
  }

  Future<void> _checkout(
    BuildContext context,
    PosController controller,
    AppI18n i18n,
    PaymentMethod method, {
    double? cashReceived,
    required double deliveryPlatformDiscount,
    required OrderType orderType,
    required String orderChannel,
    required String platformOrderId,
  }) async {
    try {
      final paidTotal = controller.estimateCheckoutTotal(
        orderType,
        deliveryPlatformDiscount: deliveryPlatformDiscount,
      );
      final receiptItems = controller.buildReceiptItemsForOrderType(orderType);
      final checkoutResult = await controller.checkoutWith(
        method: method,
        cashReceivedAmount: cashReceived,
        deliveryPlatformDiscount: deliveryPlatformDiscount,
        orderType: orderType,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
      );
      final orderNo = checkoutResult.orderNo;
      final pickupNo = checkoutResult.pickupNo;
      final checkoutOrderChannel = checkoutResult.orderChannel;
      final checkoutPlatformOrderId = checkoutResult.platformOrderId;
      final autoPrintReceipt = await controller.settingsStore
          .loadAutoPrintReceipt();
      final autoPrintReceiptCopies = await controller.settingsStore
          .loadAutoPrintReceiptCopies();
      final autoPrintLabel = await controller.settingsStore
          .loadAutoPrintLabel();
      final autoOpenCashDrawer = await controller.settingsStore
          .loadAutoOpenCashDrawer();
      if (autoPrintReceipt || autoPrintLabel || autoOpenCashDrawer) {
        // Don't block checkout dialog rendering by waiting print pipeline.
        Future<void>(() async {
          String? printError;
          if (autoPrintReceipt) {
            printError = await _printReceipt(
              controller: controller,
              i18n: i18n,
              orderNo: orderNo,
              pickupNo: pickupNo,
              total: paidTotal,
              method: method,
              orderType: orderType,
              orderChannel: checkoutOrderChannel,
              platformOrderId: checkoutPlatformOrderId,
              cashReceived: cashReceived,
              changeAmount: method == PaymentMethod.cash
                  ? ((cashReceived ?? 0) - paidTotal).clamp(0, double.infinity)
                  : null,
              items: receiptItems,
              allowSystemFallback: true,
              receiptCopies: autoPrintReceiptCopies,
              includeLabel: autoPrintLabel,
            );
          } else if (autoPrintLabel) {
            printError = await _printLabel(
              controller: controller,
              i18n: i18n,
              orderNo: orderNo,
              pickupNo: pickupNo,
              orderChannel: checkoutOrderChannel,
              platformOrderId: checkoutPlatformOrderId,
              items: receiptItems,
            );
          }
          String? drawerError;
          if (method == PaymentMethod.cash && autoOpenCashDrawer) {
            drawerError = await _openCashDrawer(controller, i18n);
          }
          if (context.mounted) {
            if (printError != null) {
              showLatestSnackBar(
                context,
                '${i18n.printReceiptFailed}: $printError',
              );
            } else if (autoPrintReceipt || autoPrintLabel) {
              showLatestSnackBar(context, i18n.printReceiptSuccess);
            }
            if (drawerError != null) {
              showLatestSnackBar(
                context,
                '${i18n.openCashDrawerFailed}: $drawerError',
              );
            }
          }
        });
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isPrintingReceipt = false;
          var isPrintingLabel = false;
          var isOpeningDrawer = false;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(i18n.cashSuccess),
              content: Text(
                '${i18n.orderNo}: $orderNo\n${i18n.pickupNo}: $pickupNo\n${i18n.total}: ${i18n.formatMoney(paidTotal)}\n${i18n.orderType}: ${i18n.orderTypeLabelByCode(orderType.name)}${checkoutOrderChannel.trim().isNotEmpty ? '\n${i18n.orderChannel}: $checkoutOrderChannel' : ''}${checkoutPlatformOrderId.trim().isNotEmpty ? '\n${i18n.platformOrderId}: $checkoutPlatformOrderId' : ''}\n${i18n.paymentMethod}: ${i18n.paymentLabel(method)}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(i18n.confirm),
                ),
                FilledButton.icon(
                  onPressed: isPrintingReceipt
                      ? null
                      : () async {
                          setState(() => isPrintingReceipt = true);
                          final printError = await _printReceipt(
                            controller: controller,
                            i18n: i18n,
                            orderNo: orderNo,
                            pickupNo: pickupNo,
                            total: paidTotal,
                            method: method,
                            orderType: orderType,
                            orderChannel: checkoutOrderChannel,
                            platformOrderId: checkoutPlatformOrderId,
                            cashReceived: cashReceived,
                            changeAmount: method == PaymentMethod.cash
                                ? ((cashReceived ?? 0) - paidTotal).clamp(
                                    0,
                                    double.infinity,
                                  )
                                : null,
                            items: receiptItems,
                            allowSystemFallback: true,
                            receiptCopies: await controller.settingsStore
                                .loadAutoPrintReceiptCopies(),
                            includeLabel: false,
                          );
                          if (!dialogContext.mounted) return;
                          showLatestSnackBar(
                            dialogContext,
                            printError == null
                                ? i18n.printReceiptSuccess
                                : '${i18n.printReceiptFailed}: $printError',
                          );
                          if (dialogContext.mounted) {
                            setState(() => isPrintingReceipt = false);
                          }
                        },
                  icon: isPrintingReceipt
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(i18n.printReceipt),
                ),
                OutlinedButton.icon(
                  onPressed: isPrintingLabel
                      ? null
                      : () async {
                          setState(() => isPrintingLabel = true);
                          final printError = await _printLabel(
                            controller: controller,
                            i18n: i18n,
                            orderNo: orderNo,
                            pickupNo: pickupNo,
                            orderChannel: checkoutOrderChannel,
                            platformOrderId: checkoutPlatformOrderId,
                            items: receiptItems,
                          );
                          if (!dialogContext.mounted) return;
                          showLatestSnackBar(
                            dialogContext,
                            printError == null
                                ? i18n.printReceiptSuccess
                                : '${i18n.printReceiptFailed}: $printError',
                          );
                          if (dialogContext.mounted) {
                            setState(() => isPrintingLabel = false);
                          }
                        },
                  icon: isPrintingLabel
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_print_shop_outlined),
                  label: Text(i18n.printLabel),
                ),
                if (method == PaymentMethod.cash)
                  OutlinedButton.icon(
                    onPressed: isOpeningDrawer
                        ? null
                        : () async {
                            setState(() => isOpeningDrawer = true);
                            final error = await _openCashDrawer(
                              controller,
                              i18n,
                            );
                            if (!dialogContext.mounted) return;
                            showLatestSnackBar(
                              dialogContext,
                              error == null
                                  ? i18n.openCashDrawerSuccess
                                  : '${i18n.openCashDrawerFailed}: $error',
                            );
                            if (dialogContext.mounted) {
                              setState(() => isOpeningDrawer = false);
                            }
                          },
                    icon: isOpeningDrawer
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.point_of_sale_outlined),
                    label: Text(i18n.openCashDrawer),
                  ),
              ],
            ),
          );
        },
      );
      if (!context.mounted) return;
      showLatestSnackBar(
        context,
        '${i18n.cashSuccess} · ${i18n.orderNo}: $orderNo',
      );
    } catch (e) {
      if (!context.mounted) return;
      showLatestSnackBar(context, '${i18n.checkoutFailed}: $e');
    }
  }

  Future<({PrinterConnectionConfig? receipt, PrinterConnectionConfig? label})>
  _loadPrinterConfigs(PosController controller) async {
    final receiptIp = await controller.settingsStore.loadPrinterIp();
    final labelIp = await controller.settingsStore.loadLabelPrinterIp();
    final receipt = (receiptIp == null || receiptIp.trim().isEmpty)
        ? null
        : PrinterConnectionConfig(ip: receiptIp.trim(), port: 0, enabled: true);
    final label = (labelIp == null || labelIp.trim().isEmpty)
        ? null
        : PrinterConnectionConfig(ip: labelIp.trim(), port: 0, enabled: true);
    return (receipt: receipt, label: label);
  }

  Future<String?> _printReceipt({
    required PosController controller,
    required AppI18n i18n,
    required String orderNo,
    required String pickupNo,
    required double total,
    required PaymentMethod method,
    required OrderType orderType,
    required String orderChannel,
    required String platformOrderId,
    required double? cashReceived,
    required double? changeAmount,
    required List<CartItem> items,
    required bool allowSystemFallback,
    required int receiptCopies,
    required bool includeLabel,
  }) async {
    try {
      final configs = await _loadPrinterConfigs(controller);
      if (!allowSystemFallback && configs.receipt == null) {
        return i18n.printerNotConfigured;
      }
      await _receiptPrinter.printCheckoutReceipt(
        storeName: await controller.settingsStore.loadStoreName(),
        orderNo: orderNo,
        pickupNo: pickupNo,
        total: total,
        method: method,
        orderType: orderType,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        items: items,
        printerConfig: configs.receipt,
        labelPrinterConfig: configs.label,
        printMode: await controller.settingsStore.loadReceiptPrintMode(),
        bottomFeedLinesBeforeCut: await controller.settingsStore
            .loadReceiptBottomFeedLines(),
        labelBottomFeedLinesBeforeCut: await controller.settingsStore
            .loadLabelBottomFeedLines(),
        receiptCopies: receiptCopies,
        includeDeliveryLabel: includeLabel,
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> _openCashDrawer(
    PosController controller,
    AppI18n i18n,
  ) async {
    try {
      final configs = await _loadPrinterConfigs(controller);
      final drawerConfig = configs.receipt ?? configs.label;
      if (drawerConfig == null) return i18n.printerNotConfigured;
      await _receiptPrinter.openCashDrawer(config: drawerConfig);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> _printLabel({
    required PosController controller,
    required AppI18n i18n,
    required String orderNo,
    required String pickupNo,
    required String orderChannel,
    required String platformOrderId,
    required List<CartItem> items,
  }) async {
    try {
      final configs = await _loadPrinterConfigs(controller);
      final labelConfig = configs.label ?? configs.receipt;
      if (labelConfig == null) return i18n.printerNotConfigured;
      await _receiptPrinter.printDeliveryLabel(
        storeName: await controller.settingsStore.loadStoreName(),
        orderNo: orderNo,
        pickupNo: pickupNo,
        orderChannel: orderChannel,
        platformOrderId: platformOrderId,
        items: items,
        printerConfig: labelConfig,
        printMode: await controller.settingsStore.loadReceiptPrintMode(),
        bottomFeedLinesBeforeCut: await controller.settingsStore
            .loadLabelBottomFeedLines(),
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> _openCheckoutDialog(
    BuildContext context,
    PosController controller,
    AppI18n i18n,
  ) async {
    final navigator = Navigator.of(context);
    final deliveryChannels = await controller.settingsStore
        .loadDeliveryChannels();
    if (!context.mounted) return;
    final payload = await navigator.push<CheckoutSubmitData>(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          i18n: i18n,
          inStoreTotal: controller.estimateCheckoutTotal(OrderType.inStore),
          deliveryTotal: controller.estimateCheckoutTotal(OrderType.delivery),
          initialMethod: controller.paymentMethod,
          deliveryChannels: deliveryChannels,
          initialCashReceived: controller.cashReceived,
        ),
      ),
    );
    if (payload == null) return;
    if (!navigator.mounted) return;
    await _checkout(
      navigator.context,
      controller,
      i18n,
      payload.method,
      cashReceived: payload.cashReceived,
      deliveryPlatformDiscount: payload.deliveryPlatformDiscount,
      orderType: payload.orderType,
      orderChannel: payload.orderChannel,
      platformOrderId: payload.platformOrderId,
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.i18n,
    required this.onAdd,
    required this.onMinus,
    required this.onDelete,
    required this.onEdit,
  });

  final CartItem item;
  final AppI18n i18n;
  final VoidCallback onAdd;
  final VoidCallback onMinus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rawUnitPrice =
        item.product.price + item.sizeExtraPrice + item.toppingTotal;
    final rawSubtotal = rawUnitPrice * item.quantity;
    final hasItemDiscount = rawSubtotal - item.subtotal > 0.001;
    final optionParts = <String>[
      if (item.product.showSize && item.sizeName.trim().isNotEmpty)
        item.sizeName,
      if (item.product.showSugar && item.sugarName.trim().isNotEmpty)
        item.sugarName,
      if (item.product.showIce && item.iceName.trim().isNotEmpty) item.iceName,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3EEF9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.localizedName(i18n.language.name),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      if (optionParts.isNotEmpty)
                        Text(
                          optionParts.join(' | '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (item.product.showToppings && item.toppings.isNotEmpty)
                        Text(
                          '${i18n.toppings}: ${item.toppings.map((e) => e.name).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (item.note.trim().isNotEmpty)
                        Text(
                          '${i18n.note}: ${item.note}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      i18n.formatMoney(item.subtotal),
                      style: TextStyle(
                        fontWeight: hasItemDiscount
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: hasItemDiscount ? const Color(0xFFD32F2F) : null,
                      ),
                    ),
                    if (hasItemDiscount)
                      Text(
                        i18n.formatMoney(rawSubtotal),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A7A),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: onMinus,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                TextButton(onPressed: onEdit, child: Text(i18n.editItem)),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.i18n,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final double value;
  final AppI18n i18n;
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasis ? 18 : 14,
      fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
    );

    final valueStyle = valueColor == null
        ? style
        : style.copyWith(color: valueColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(i18n.formatMoney(value), style: valueStyle),
        ],
      ),
    );
  }
}
