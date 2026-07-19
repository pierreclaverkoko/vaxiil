import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';
import 'package:vaxiil_mobile/shared/utils/platform_fee_utils.dart';

void main() {
  test('computeBookingPrice adds fee when client pays', () {
    final fees = OrganizationPlatformFeesModel(
      platformFeeRate: '1.00',
      platformFeePayer: const ChoiceEnumData(
        value: 'C',
        title: 'Client',
        css: 'info',
      ),
    );
    final computed = computeBookingPrice(basePrice: 100, fees: fees);
    expect(computed.basePrice, 100);
    expect(computed.feeAmount, 1);
    expect(computed.totalPrice, 101);
    expect(computed.clientPaysFee, isTrue);
  });

  test('computeBookingPrice keeps total equal to base when business pays', () {
    final fees = OrganizationPlatformFeesModel(
      platformFeeRate: '2.50',
      platformFeePayer: const ChoiceEnumData(
        value: 'B',
        title: 'Business',
        css: 'warning',
      ),
    );
    final computed = computeBookingPrice(basePrice: 80, fees: fees);
    expect(computed.feeAmount, 2);
    expect(computed.totalPrice, 80);
    expect(computed.clientPaysFee, isFalse);
  });

  test('bookingShowsFeeBreakdown only for client payer', () {
    expect(bookingShowsFeeBreakdown(payerValue: 'C'), isTrue);
    expect(bookingShowsFeeBreakdown(payerValue: 'B'), isFalse);
  });
}
