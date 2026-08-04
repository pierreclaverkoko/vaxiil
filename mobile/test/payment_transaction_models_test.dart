import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/payments/data/payment_transaction_models.dart';

void main() {
  test('parses payment transaction with choice enums', () {
    final row = PaymentTransactionItem.fromJson({
      'id': 't1',
      'booking': 'b1',
      'provider_code': 'mm_aggregator',
      'amount': '50.00',
      'currency_code': 'USD',
      'kind': {'value': 'P', 'title': 'Payment', 'css': 'primary'},
      'status': {'value': 'S', 'title': 'Succeeded', 'css': 'success'},
      'purpose': {'value': 'B', 'title': 'Booking payment', 'css': 'primary'},
      'client_reference': 'ref1',
      'created_at': '2026-08-01T12:00:00Z',
      'payment_method': {
        'id': 'm1',
        'code': 'MOMO_TEST',
        'name': 'Test MoMo',
        'logo_url': 'https://cdn.example/momo.png',
        'method_type': {'value': 'M', 'title': 'Mobile money', 'css': 'info'},
      },
      'account_identifier': '+25•••5678',
    });
    expect(row.id, 't1');
    expect(row.bookingId, 'b1');
    expect(row.amountLabel, '50.00 USD');
    expect(row.status?.css, 'success');
    expect(row.purpose?.value, 'B');
    expect(row.createdAt, isNotNull);
    expect(row.paymentMethod?.name, 'Test MoMo');
    expect(row.paymentMethod?.logoUrl, 'https://cdn.example/momo.png');
    expect(row.paymentMethod?.methodType?.value, 'M');
    expect(row.accountIdentifier, '+25•••5678');
    expect(row.canRefreshStatus, isTrue);
  });

  test('parses can_refresh_status false for wallet refunds', () {
    final row = PaymentTransactionItem.fromJson({
      'id': 't3',
      'amount': '75.00',
      'currency_code': 'USD',
      'kind': {'value': 'R', 'title': 'Refund', 'css': 'warning'},
      'status': {'value': 'U', 'title': 'Refunded', 'css': 'warning'},
      'can_refresh_status': false,
    });
    expect(row.canRefreshStatus, isFalse);
  });

  test('allows null booking for wallet top-up', () {
    final row = PaymentTransactionItem.fromJson({
      'id': 't2',
      'booking': null,
      'amount': '25.00',
      'currency_code': 'USD',
      'purpose': {
        'value': 'W',
        'title': 'Store credit top-up',
        'css': 'success',
      },
      'status': {'value': 'N', 'title': 'Pending', 'css': 'warning'},
    });
    expect(row.bookingId, isNull);
    expect(row.purpose?.value, 'W');
    expect(row.paymentMethod, isNull);
    expect(row.accountIdentifier, '');
  });
}
