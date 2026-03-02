import 'package:flutter/material.dart';

import 'product_management_page.dart';
import 'promotion_management_page.dart';
import '../state/pos_controller.dart';
import 'order_management_page.dart';
import 'pos_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';

const _shellDividerColor = Color(0xFFE3EEF9);

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.controller});

  final PosController controller;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;
  late bool _lastIsAdmin;

  int _pageCountForRole(bool isAdmin) => isAdmin ? 6 : 3;

  @override
  void initState() {
    super.initState();
    _lastIsAdmin = widget.controller.isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isAdmin = widget.controller.isAdmin;
        final oldPagesLength = _pageCountForRole(_lastIsAdmin);
        final newPagesLength = _pageCountForRole(isAdmin);
        final oldSettingsIndex = oldPagesLength - 1;
        final newSettingsIndex = newPagesLength - 1;
        var desiredIndex = _index;
        if (_lastIsAdmin != isAdmin && _index == oldSettingsIndex) {
          // Keep user on Settings when role changes.
          desiredIndex = newSettingsIndex;
        }
        _lastIsAdmin = isAdmin;
        if (desiredIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index = desiredIndex);
          });
        }

        final i18n = widget.controller.i18n;
        final pages = <Widget>[PosPage(controller: widget.controller)];
        final items = <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: const Icon(Icons.point_of_sale),
            label: i18n.posTitle,
          ),
        ];
        if (!isAdmin) {
          pages.add(StatisticsPage(controller: widget.controller, i18n: i18n));
          items.add(
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: i18n.statistics,
            ),
          );
        }
        if (isAdmin) {
          pages.addAll([
            OrderManagementPage(controller: widget.controller, i18n: i18n),
            ProductManagementPage(controller: widget.controller, i18n: i18n),
            PromotionManagementPage(controller: widget.controller),
            StatisticsPage(controller: widget.controller, i18n: i18n),
          ]);
          items.addAll([
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: i18n.orderManagement,
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: i18n.productManagement,
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: i18n.promotionManagement,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: i18n.statistics,
            ),
          ]);
        }
        pages.add(SettingsPage(controller: widget.controller));
        items.add(
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: i18n.settings,
          ),
        );
        if (_index >= pages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index = pages.length - 1);
          });
        }
        final safeIndex = desiredIndex.clamp(0, pages.length - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final useRail =
                constraints.maxWidth >= 1100 ||
                (isLandscape && constraints.maxWidth >= 900);
            if (useRail) {
              final viewPadding = MediaQuery.viewPaddingOf(context);
              return Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: IndexedStack(index: safeIndex, children: pages),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: viewPadding.top,
                        bottom: viewPadding.bottom,
                      ),
                      child: const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: _shellDividerColor,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: viewPadding.top,
                        bottom: viewPadding.bottom,
                      ),
                      child: NavigationRail(
                        selectedIndex: safeIndex,
                        onDestinationSelected: (value) {
                          setState(() => _index = value);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: items
                            .map(
                              (item) => NavigationRailDestination(
                                icon: item.icon,
                                selectedIcon: item.selectedIcon,
                                label: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              body: IndexedStack(index: safeIndex, children: pages),
              bottomNavigationBar: NavigationBar(
                selectedIndex: safeIndex,
                destinations: items,
                onDestinationSelected: (value) {
                  setState(() => _index = value);
                },
              ),
            );
          },
        );
      },
    );
  }
}
