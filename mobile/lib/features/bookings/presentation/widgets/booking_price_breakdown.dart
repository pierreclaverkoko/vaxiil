import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/shared/utils/platform_fee_utils.dart';

class BookingPriceBreakdown extends StatelessWidget {
  const BookingPriceBreakdown({
    required this.currencyCode,
    required this.basePrice,
    required this.feeAmount,
    required this.totalPrice,
    required this.showFeeBreakdown,
    this.feeRate,
    this.feePayerTitle,
    this.compact = false,
    super.key,
  });

  factory BookingPriceBreakdown.fromComputed({
    required String currencyCode,
    required ComputedBookingPrice computed,
    String? feePayerTitle,
    bool compact = false,
  }) {
    return BookingPriceBreakdown(
      currencyCode: currencyCode,
      basePrice: computed.basePrice,
      feeAmount: computed.feeAmount,
      totalPrice: computed.totalPrice,
      showFeeBreakdown: computed.clientPaysFee,
      feeRate: computed.feeRate,
      feePayerTitle: feePayerTitle,
      compact: compact,
    );
  }

  final String currencyCode;
  final double basePrice;
  final double feeAmount;
  final double totalPrice;
  final bool showFeeBreakdown;
  final double? feeRate;
  final String? feePayerTitle;
  final bool compact;

  String _money(double amount) => NumberFormat.simpleCurrency(
        name: currencyCode,
        decimalDigits: 2,
      ).format(amount);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalStyle = compact
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            )
        : Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
            );

    if (!showFeeBreakdown) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(_money(totalPrice), style: totalStyle),
        ],
      );
    }

    final rateLabel = feeRate != null ? ' (${feeRate!.toStringAsFixed(2)}%)' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(label: 'Service price', value: _money(basePrice)),
        const SizedBox(height: 8),
        _Row(
          label: 'Platform fee$rateLabel',
          value: _money(feeAmount),
          subtitle: feePayerTitle,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total due',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(_money(totalPrice), style: totalStyle),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

/// Payment summary for persisted booking payloads.
class BookingPaymentSummaryPanel extends StatelessWidget {
  const BookingPaymentSummaryPanel({
    required this.currencyCode,
    required this.basePrice,
    required this.feeAmount,
    required this.totalPrice,
    required this.showFeeBreakdown,
    this.feeRate,
    this.variantName,
    this.variantPrice,
    super.key,
  });

  factory BookingPaymentSummaryPanel.fromBooking({
    required String currencyCode,
    required String totalPrice,
    String? basePrice,
    String? platformFeeAmount,
    String? platformFeeRate,
    String? platformFeePayerValue,
    String? variantName,
    String? variantPrice,
  }) {
    final total = double.tryParse(totalPrice) ?? 0;
    final base = double.tryParse(basePrice ?? totalPrice) ?? total;
    final fee = double.tryParse(platformFeeAmount ?? '0') ?? 0;
    final rate = double.tryParse(platformFeeRate ?? '');
    return BookingPaymentSummaryPanel(
      currencyCode: currencyCode,
      basePrice: base,
      feeAmount: fee,
      totalPrice: total,
      showFeeBreakdown: bookingShowsFeeBreakdown(payerValue: platformFeePayerValue),
      feeRate: rate,
      variantName: variantName,
      variantPrice: variantPrice,
    );
  }

  final String currencyCode;
  final double basePrice;
  final double feeAmount;
  final double totalPrice;
  final bool showFeeBreakdown;
  final double? feeRate;
  final String? variantName;
  final String? variantPrice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          BookingPriceBreakdown(
            currencyCode: currencyCode,
            basePrice: basePrice,
            feeAmount: feeAmount,
            totalPrice: totalPrice,
            showFeeBreakdown: showFeeBreakdown,
            feeRate: feeRate,
            compact: true,
          ),
        ],
      ),
    );
  }
}
