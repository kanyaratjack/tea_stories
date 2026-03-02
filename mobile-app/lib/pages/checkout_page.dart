import 'package:flutter/material.dart';

import '../l10n/app_i18n.dart';
import '../state/pos_controller.dart';

const _blue = Color(0xFF1976D2);
const _blueBorder = Color(0xFF90CAF9);

class CheckoutSubmitData {
  const CheckoutSubmitData({
    required this.method,
    required this.orderType,
    required this.orderChannel,
    required this.platformOrderId,
    required this.deliveryPlatformDiscount,
    this.cashReceived,
  });

  final PaymentMethod method;
  final OrderType orderType;
  final String orderChannel;
  final String platformOrderId;
  final double deliveryPlatformDiscount;
  final double? cashReceived;
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.i18n,
    required this.inStoreTotal,
    required this.deliveryTotal,
    required this.initialMethod,
    required this.deliveryChannels,
    this.initialCashReceived,
  });

  final AppI18n i18n;
  final double inStoreTotal;
  final double deliveryTotal;
  final PaymentMethod initialMethod;
  final List<String> deliveryChannels;
  final double? initialCashReceived;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late PaymentMethod method = widget.initialMethod == PaymentMethod.deliveryApp
      ? PaymentMethod.cash
      : widget.initialMethod;
  OrderType orderType = OrderType.inStore;
  late String _deliveryChannel = widget.deliveryChannels.isEmpty
      ? 'Other'
      : widget.deliveryChannels.first;
  late double? cashReceived = widget.initialCashReceived;
  final TextEditingController _platformOrderIdController =
      TextEditingController();
  final TextEditingController _deliveryDiscountController =
      TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  double _deliveryPlatformDiscount = 0;

  @override
  void initState() {
    super.initState();
    final value = cashReceived;
    _cashController.text = value == null ? '' : value.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _platformOrderIdController.dispose();
    _deliveryDiscountController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final isDelivery = orderType == OrderType.delivery;
    final baseTotal = isDelivery
        ? widget.deliveryTotal
        : widget.inStoreTotal;
    final appliedDeliveryDiscount = isDelivery
        ? _deliveryPlatformDiscount.clamp(0, baseTotal).toDouble()
        : 0.0;
    final currentTotal =
        (baseTotal - appliedDeliveryDiscount).clamp(0, double.infinity);
    final isCash = method == PaymentMethod.cash;
    final canConfirm = isDelivery
        ? (_deliveryChannel.trim().isNotEmpty &&
              _platformOrderIdController.text.trim().isNotEmpty)
        : (!isCash ||
              (cashReceived != null && (cashReceived ?? 0) >= currentTotal));
    final change = isCash && cashReceived != null
        ? (cashReceived! - currentTotal).clamp(0, double.infinity)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.checkoutPanelTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i18n.total,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          i18n.formatMoney(currentTotal),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.orderType,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: OrderType.values
                              .map(
                                (item) => ChoiceChip(
                                  label: Text(
                                    i18n.orderTypeLabelByCode(item.name),
                                  ),
                                  selected: orderType == item,
                                  labelStyle: TextStyle(
                                    color: orderType == item
                                        ? Colors.white
                                        : const Color(0xFF1565C0),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedColor: _blue,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: _blueBorder,
                                    width: 1.2,
                                  ),
                                  checkmarkColor: Colors.white,
                                  onSelected: (_) => setState(() {
                                    orderType = item;
                                    if (orderType == OrderType.delivery) {
                                      method = PaymentMethod.deliveryApp;
                                      cashReceived = null;
                                    } else if (method ==
                                        PaymentMethod.deliveryApp) {
                                      method = PaymentMethod.cash;
                                    }
                                  }),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 12),
                        if (isDelivery) ...[
                          Text(
                            i18n.orderChannel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.deliveryChannels
                                .map(
                                  (channel) => ChoiceChip(
                                    label: Text(channel),
                                    selected: _deliveryChannel == channel,
                                    labelStyle: TextStyle(
                                      color: _deliveryChannel == channel
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) => setState(
                                      () => _deliveryChannel = channel,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            i18n.platformOrderId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _platformOrderIdController,
                            decoration: InputDecoration(
                              labelText: i18n.platformOrderId,
                              hintText: i18n.platformOrderIdHint,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            i18n.deliveryPlatformDiscount,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _deliveryDiscountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: i18n.deliveryPlatformDiscount,
                              hintText: i18n.deliveryPlatformDiscountHint,
                              prefixText: '฿ ',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                final parsed = double.tryParse(value.trim());
                                _deliveryPlatformDiscount =
                                    parsed == null || parsed <= 0 ? 0 : parsed;
                              });
                            },
                          ),
                          if (appliedDeliveryDiscount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${i18n.activityDiscount}: -${i18n.formatMoney(appliedDeliveryDiscount)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            i18n.paymentMethod,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PaymentMethod.values
                                .where(
                                  (item) => item != PaymentMethod.deliveryApp,
                                )
                                .map(
                                  (item) => ChoiceChip(
                                    label: Text(i18n.paymentLabel(item)),
                                    selected: method == item,
                                    labelStyle: TextStyle(
                                      color: method == item
                                          ? Colors.white
                                          : const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    selectedColor: _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: _blueBorder,
                                      width: 1.2,
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (_) =>
                                        setState(() => method = item),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isDelivery && isCash) ...[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.cashReceived,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                            decoration: InputDecoration(
                              labelText: i18n.cashReceived,
                              prefixText: '฿ ',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                cashReceived = double.tryParse(value.trim());
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [20, 30, 50, 100, 200, 500, 1000]
                                .map(
                                  (amount) => ActionChip(
                                    label: Text('฿$amount'),
                                    onPressed: () => setState(() {
                                      cashReceived = amount.toDouble();
                                      _cashController.text = amount.toString();
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  i18n.change,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                i18n.formatMoney(change),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                ),
                              ),
                            ],
                          ),
                          if (!canConfirm)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                i18n.paymentTip,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else if (!isDelivery) ...[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.scanToPay,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _blueBorder),
                            ),
                            child: Text(
                              i18n.offlineQrHint,
                              style: const TextStyle(color: Color(0xFF1565C0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(i18n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: FilledButton(
                      onPressed: canConfirm
                          ? () {
                              Navigator.pop(
                                context,
                                CheckoutSubmitData(
                                  method: method,
                                  orderType: orderType,
                                  orderChannel: isDelivery
                                      ? _deliveryChannel
                                      : '',
                                  platformOrderId: isDelivery
                                      ? _platformOrderIdController.text.trim()
                                      : '',
                                  deliveryPlatformDiscount: isDelivery
                                      ? appliedDeliveryDiscount
                                      : 0,
                                  cashReceived: cashReceived,
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        isDelivery
                            ? i18n.confirm
                            : (isCash ? i18n.checkout : i18n.markPaid),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3EEF9)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
