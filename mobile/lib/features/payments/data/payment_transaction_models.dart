import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

/// Payment rail shown on a consumer transaction row.
class PaymentTransactionMethod {
  const PaymentTransactionMethod({
    required this.id,
    required this.code,
    required this.name,
    this.logoUrl,
    this.methodType,
  });

  final String id;
  final String code;
  final String name;
  final String? logoUrl;
  final ChoiceEnumData? methodType;

  factory PaymentTransactionMethod.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionMethod(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
      methodType: ChoiceEnumData.parse(json['method_type']),
    );
  }
}

/// Consumer payment history row from `GET /payments/transactions/`.
class PaymentTransactionItem {
  const PaymentTransactionItem({
    required this.id,
    required this.amount,
    required this.currencyCode,
    required this.providerCode,
    required this.clientReference,
    this.bookingId,
    this.kind,
    this.status,
    this.purpose,
    this.createdAt,
    this.paymentMethod,
    this.accountIdentifier = '',
    this.canRefreshStatus = true,
  });

  final String id;
  final String? bookingId;
  final String amount;
  final String currencyCode;
  final String providerCode;
  final String clientReference;
  final ChoiceEnumData? kind;
  final ChoiceEnumData? status;
  final ChoiceEnumData? purpose;
  final DateTime? createdAt;
  final PaymentTransactionMethod? paymentMethod;
  final String accountIdentifier;
  /// False for internal store-credit refunds (no PSP status to poll).
  final bool canRefreshStatus;

  factory PaymentTransactionItem.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final rawCreated = json['created_at'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated);
    }
    PaymentTransactionMethod? method;
    final rawMethod = json['payment_method'];
    if (rawMethod is Map<String, dynamic>) {
      method = PaymentTransactionMethod.fromJson(rawMethod);
    } else if (rawMethod is Map) {
      method = PaymentTransactionMethod.fromJson(
        Map<String, dynamic>.from(rawMethod),
      );
    }
    final bookingRaw = json['booking'] ?? json['booking_id'];
    return PaymentTransactionItem(
      id: json['id']?.toString() ?? '',
      bookingId: bookingRaw?.toString(),
      amount: json['amount']?.toString() ?? '',
      currencyCode: json['currency_code']?.toString() ?? '',
      providerCode: json['provider_code']?.toString() ?? '',
      clientReference: json['client_reference']?.toString() ?? '',
      kind: ChoiceEnumData.parse(json['kind']),
      status: ChoiceEnumData.parse(json['status']),
      purpose: ChoiceEnumData.parse(json['purpose']),
      createdAt: created,
      paymentMethod: method,
      accountIdentifier: json['account_identifier']?.toString() ?? '',
      canRefreshStatus: json['can_refresh_status'] != false,
    );
  }

  String get amountLabel => '$amount $currencyCode'.trim();
}
