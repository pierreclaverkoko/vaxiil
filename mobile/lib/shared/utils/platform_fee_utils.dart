import 'dart:math' as math;

import 'package:vaxiil_mobile/features/business/data/organization_models.dart';

/// Client-side estimate aligned with backend `compute_platform_fee`.
class ComputedBookingPrice {
  const ComputedBookingPrice({
    required this.basePrice,
    required this.feeRate,
    required this.feeAmount,
    required this.totalPrice,
    required this.clientPaysFee,
  });

  final double basePrice;
  final double feeRate;
  final double feeAmount;
  final double totalPrice;
  final bool clientPaysFee;
}

double _roundHalfUp(double value, {int places = 2}) {
  final mod = math.pow(10, places).toDouble();
  return (value * mod).roundToDouble() / mod;
}

/// Pre-booking estimate from org fee summary and service base price.
ComputedBookingPrice computeBookingPrice({
  required num basePrice,
  OrganizationPlatformFeesModel? fees,
}) {
  final base = _roundHalfUp(basePrice.toDouble());
  final rate = double.tryParse(fees?.platformFeeRate ?? '') ?? 0;
  final feeAmount = _roundHalfUp(base * rate / 100);
  final clientPays = fees?.platformFeePayer?.value != 'B';
  final total = clientPays ? _roundHalfUp(base + feeAmount) : base;
  return ComputedBookingPrice(
    basePrice: base,
    feeRate: rate,
    feeAmount: feeAmount,
    totalPrice: total,
    clientPaysFee: clientPays,
  );
}

bool bookingShowsFeeBreakdown({String? payerValue}) => payerValue == 'C';
