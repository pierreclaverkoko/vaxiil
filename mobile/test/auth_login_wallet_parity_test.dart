import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/auth/data/login_result.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';

void main() {
  group('LoginResult', () {
    test('OTP challenge is distinct from session', () {
      const challenge = LoginOtpChallengeResult(
        challengeId: 'chal-1',
        emailHint: 'a***@example.com',
      );
      expect(challenge, isA<LoginResult>());
      expect(challenge.challengeId, 'chal-1');
      expect(challenge.emailHint, 'a***@example.com');
    });

    test('session wraps AuthUser', () {
      final user = AuthUser.fromJson({
        'id': 'u1',
        'email': 'ada@example.com',
        'verification_status': {
          'value': 'V',
          'title': 'Verified',
          'css': 'success',
        },
      });
      final session = LoginSessionResult(user);
      expect(session.user.isVerified, isTrue);
    });
  });

  test('AuthUser.isVerified requires V status', () {
    final pending = AuthUser.fromJson({
      'id': 'u1',
      'email': 'a@b.c',
      'verification_status': {
        'value': 'P',
        'title': 'Pending',
        'css': 'warning',
      },
    });
    expect(pending.isVerified, isFalse);

    final none = AuthUser.fromJson({'id': 'u2', 'email': 'a@b.c'});
    expect(none.isVerified, isFalse);
  });

  test('PaymentLinkResult parses escrow apply fields', () {
    final r = PaymentLinkResult.fromJson({
      'url': 'https://pay.example/l/x',
      'merchant_reference': 'bk_1',
      'transaction_id': 'txn-1',
      'amount_charged': '40.00',
      'wallet_applied': '10.00',
      'fully_paid': false,
    });
    expect(r.amountCharged, '40.00');
    expect(r.walletApplied, '10.00');
    expect(r.fullyPaid, isFalse);
  });

  test('PaymentLinkResult fully paid by escrow', () {
    final r = PaymentLinkResult.fromJson({
      'url': null,
      'merchant_reference': null,
      'transaction_id': null,
      'amount_charged': '0',
      'wallet_applied': '50.00',
      'fully_paid': true,
    });
    expect(r.fullyPaid, isTrue);
    expect(r.url, isNull);
    expect(r.walletApplied, '50.00');
  });

  test('WalletTopUpResult parses top-up response', () {
    final r = WalletTopUpResult.fromJson({
      'url': 'https://pay.example/topup',
      'merchant_reference': 'wu_1',
      'transaction_id': 'txn-top',
      'amount': '25.00',
    });
    expect(r.url, 'https://pay.example/topup');
    expect(r.merchantReference, 'wu_1');
    expect(r.amount, '25.00');
  });

  test('RefundWalletSummary parses zero balances', () {
    final w = RefundWalletSummary.fromJson({
      'balances': [
        {'currency_code': 'USD', 'balance': '0.00'},
      ],
      'total_credited': '0',
    });
    expect(w.balances, hasLength(1));
    expect(w.balances.first.balance, '0.00');
    expect(w.balances.first.currencyCode, 'USD');
  });
}
