import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_i18n.dart';
import '../models/sales_stats.dart';
import '../state/pos_controller.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.controller,
    required this.i18n,
  });

  final PosController controller;
  final AppI18n i18n;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _days = 0;
  late Future<_StatsViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsViewData> _load() async {
    final daily = await widget.controller.loadDailyRevenueStats(days: _days);
    final top = await widget.controller.loadTopProductSalesStats(
      days: _days,
      limit: 10,
    );
    final paymentMethods = await widget.controller.loadPaymentMethodStats(
      days: _days,
    );
    final orderTypes = await widget.controller.loadOrderTypeStats(days: _days);
    final deliveryChannels = await widget.controller.loadDeliveryChannelStats(
      days: _days,
    );
    final hourlyToday = await widget.controller.loadTodayHourlyRevenueStats();
    return _StatsViewData(
      daily: daily,
      topProducts: top,
      paymentMethods: paymentMethods,
      orderTypes: orderTypes,
      deliveryChannels: deliveryChannels,
      hourlyToday: hourlyToday,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.statistics),
        actions: [
          IconButton(
            tooltip: i18n.retry,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_StatsViewData>(
          future: _future,
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
            final data = snapshot.data;
            if (data == null) {
              return Center(child: Text(i18n.noOrders));
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(i18n.recentDays),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        initialValue: _days,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [0, 1, 30, 180, 365]
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(
                                  d == 0
                                      ? i18n.allTime
                                      : d == 1
                                      ? i18n.today
                                      : '$d',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _days = value;
                            _future = _load();
                          });
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(i18n.retry),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryCards(i18n: i18n, data: data),
                const SizedBox(height: 12),
                _HourlyRevenueChart(i18n: i18n, data: data.hourlyToday),
                const SizedBox(height: 12),
                _DailyRevenueList(i18n: i18n, data: data.daily),
                const SizedBox(height: 12),
                _OrderTypeList(i18n: i18n, data: data.orderTypes),
                const SizedBox(height: 12),
                _DeliveryChannelList(i18n: i18n, data: data.deliveryChannels),
                const SizedBox(height: 12),
                _PaymentMethodList(i18n: i18n, data: data.paymentMethods),
                const SizedBox(height: 12),
                _TopProductsList(i18n: i18n, data: data.topProducts),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.i18n, required this.data});

  final AppI18n i18n;
  final _StatsViewData data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(
          title: i18n.grossRevenue,
          value: i18n.formatMoney(data.grossTotal),
          color: const Color(0xFF1565C0),
        ),
        _MetricCard(
          title: i18n.refundAmount,
          value: i18n.formatMoney(data.refundedTotal),
          color: const Color(0xFFD32F2F),
        ),
        _MetricCard(
          title: i18n.activityDiscount,
          value: i18n.formatMoney(data.promoTotal),
          color: const Color(0xFF6A1B9A),
        ),
        _MetricCard(
          title: i18n.netRevenue,
          value: i18n.formatMoney(data.netTotal),
          color: const Color(0xFF2E7D32),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRevenueList extends StatelessWidget {
  const _DailyRevenueList({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<DailyRevenueStat> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.dailyRevenue,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(i18n.noOrders)
          else
            ...data.map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(DateFormat('yyyy-MM-dd').format(row.day)),
                    ),
                    Expanded(
                      child: Text(
                        '${i18n.grossRevenue}: ${i18n.formatMoney(row.grossAmount)}',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${i18n.activityDiscount}: ${i18n.formatMoney(row.promoAmount)}',
                        style: const TextStyle(color: Color(0xFF6A1B9A)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${i18n.refundAmount}: ${i18n.formatMoney(row.refundedAmount)}',
                        style: const TextStyle(color: Color(0xFFD32F2F)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${i18n.netRevenue}: ${i18n.formatMoney(row.netAmount)}',
                        style: const TextStyle(color: Color(0xFF2E7D32)),
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('${row.orderCount}'),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<ProductSalesStat> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.topProducts,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(i18n.noProducts)
          else
            ...data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('#${index + 1}')),
                    Expanded(child: Text(item.productName)),
                    SizedBox(
                      width: 120,
                      child: Text('${i18n.soldQty}: ${item.netQty}'),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        i18n.formatMoney(item.netAmount),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PaymentMethodList extends StatelessWidget {
  const _PaymentMethodList({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<PaymentMethodStat> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.paymentMethodStats,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(i18n.noOrders)
          else
            ...data.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(i18n.paymentLabelByCode(item.paymentMethod)),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text('${i18n.orderCount}: ${item.orderCount}'),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        i18n.formatMoney(item.netAmount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OrderTypeList extends StatelessWidget {
  const _OrderTypeList({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<OrderTypeStat> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.orderTypeStats,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(i18n.noOrders)
          else
            ...data.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(i18n.orderTypeLabelByCode(item.orderType)),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text('${i18n.orderCount}: ${item.orderCount}'),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        i18n.formatMoney(item.netAmount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DeliveryChannelList extends StatelessWidget {
  const _DeliveryChannelList({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<DeliveryChannelStat> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.deliveryChannelStats,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            Text(i18n.noOrders)
          else
            ...data.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(item.channel)),
                    SizedBox(
                      width: 120,
                      child: Text('${i18n.orderCount}: ${item.orderCount}'),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        i18n.formatMoney(item.netAmount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HourlyRevenueChart extends StatelessWidget {
  const _HourlyRevenueChart({required this.i18n, required this.data});

  final AppI18n i18n;
  final List<HourlyRevenueStat> data;

  @override
  Widget build(BuildContext context) {
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.zh => zh,
      AppLanguage.th => th,
      AppLanguage.en => en,
    };

    final byHour = {for (final item in data) item.hour: item};
    final bars = List<HourlyRevenueStat>.generate(24, (hour) {
      return byHour[hour] ??
          HourlyRevenueStat(hour: hour, orderCount: 0, netAmount: 0);
    });
    final maxNet = bars.fold<double>(0, (max, item) {
      return item.netAmount > max ? item.netAmount : max;
    });
    final top = bars.reduce((a, b) => a.netAmount >= b.netAmount ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('今日时段销售额', 'ยอดขายรายชั่วโมงวันนี้', 'Today Hourly Revenue'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            top.netAmount <= 0
                ? t(
                    '今日暂无有效销售数据',
                    'วันนี้ยังไม่มีข้อมูลยอดขายที่มีผล',
                    'No effective sales data for today',
                  )
                : t(
                    '最高时段: ${top.hour.toString().padLeft(2, '0')}:00 - ${top.hour.toString().padLeft(2, '0')}:59  (${i18n.formatMoney(top.netAmount)})',
                    'ช่วงพีค: ${top.hour.toString().padLeft(2, '0')}:00 - ${top.hour.toString().padLeft(2, '0')}:59  (${i18n.formatMoney(top.netAmount)})',
                    'Peak hour: ${top.hour.toString().padLeft(2, '0')}:00 - ${top.hour.toString().padLeft(2, '0')}:59  (${i18n.formatMoney(top.netAmount)})',
                  ),
            style: TextStyle(
              fontSize: 13,
              color: top.netAmount <= 0
                  ? Colors.grey.shade600
                  : const Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars
                    .map((item) {
                      final ratio = maxNet <= 0
                          ? 0.0
                          : (item.netAmount / maxNet);
                      final barHeight = 10 + (ratio * 120);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                item.netAmount <= 0
                                    ? '-'
                                    : i18n.formatMoney(item.netAmount),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 14,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: item.netAmount <= 0
                                    ? const Color(0xFFCFD8DC)
                                    : const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.hour.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsViewData {
  const _StatsViewData({
    required this.daily,
    required this.topProducts,
    required this.paymentMethods,
    required this.orderTypes,
    required this.deliveryChannels,
    required this.hourlyToday,
  });

  final List<DailyRevenueStat> daily;
  final List<ProductSalesStat> topProducts;
  final List<PaymentMethodStat> paymentMethods;
  final List<OrderTypeStat> orderTypes;
  final List<DeliveryChannelStat> deliveryChannels;
  final List<HourlyRevenueStat> hourlyToday;

  double get grossTotal => daily.fold(0, (sum, item) => sum + item.grossAmount);
  double get promoTotal => daily.fold(0, (sum, item) => sum + item.promoAmount);
  double get refundedTotal =>
      daily.fold(0, (sum, item) => sum + item.refundedAmount);
  double get netTotal => daily.fold(0, (sum, item) => sum + item.netAmount);
}
