import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/core/utils/client_location.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';

class BookingsRepository {
  BookingsRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<BookingListItemModel>> listMine({
    int page = 1,
    String? organizationId,
  }) async {
    try {
      final qp = <String, dynamic>{'page': page};
      if (organizationId != null && organizationId.isNotEmpty) {
        qp['organization'] = organizationId;
      }
      final response = await _dio.get<dynamic>(
        AppConstants.bookingsPath,
        queryParameters: qp,
      );
      return parseJsonList(response.data, BookingListItemModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<BookingDetailModel> get(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.bookingsPath}$id/',
      );
      return BookingDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.bookingsPath,
        data: body,
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<BookingDetailModel> confirm(String id) => _staffAction(
        AppConstants.bookingConfirmPath(id),
      );

  Future<BookingDetailModel> reject(String id, {String reason = ''}) =>
      _staffAction(
        AppConstants.bookingRejectPath(id),
        data: {'reason': reason},
      );

  Future<BookingDetailModel> complete(String id) => _staffAction(
        AppConstants.bookingCompletePath(id),
      );

  Future<BookingDetailModel> _staffAction(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final body = await withOptionalClientLocation(data ?? {});
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body.isEmpty ? null : body,
      );
      return BookingDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Response may include `booking` and `refund` (server refund orchestration).
  Future<Map<String, dynamic>> cancel(String id, {String reason = ''}) async {
    try {
      final body = await withOptionalClientLocation({'reason': reason});
      final response = await _dio.post<Map<String, dynamic>>(
        '${AppConstants.bookingsPath}$id/cancel/',
        data: body,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Propose a new schedule (client or business).
  Future<void> reschedule(
    String id,
    List<Map<String, dynamic>> timeSlots,
  ) async {
    try {
      final body = await withOptionalClientLocation({
        'time_slots': timeSlots,
      });
      await _dio.post<dynamic>(
        '${AppConstants.bookingsPath}$id/reschedule/',
        data: body,
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<BookingDetailModel> acceptReschedule(String bookingId) => _staffAction(
        '${AppConstants.bookingsPath}$bookingId/reschedule/accept/',
      );

  Future<BookingDetailModel> declineReschedule(String bookingId) =>
      _staffAction(
        '${AppConstants.bookingsPath}$bookingId/reschedule/decline/',
      );

  /// Start collection (MM Aggregator deposit) for [bookingId].
  Future<PaymentLinkResult> createPaymentLink(
    String bookingId, {
    bool applyWallet = false,
    String? walletAmount,
    String? paymentMethodId,
    String? accountIdentifier,
    String? accountName,
    Map<String, String>? details,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (applyWallet) {
        body['apply_wallet'] = true;
      }
      if (walletAmount != null && walletAmount.isNotEmpty) {
        body['wallet_amount'] = walletAmount;
      }
      if (paymentMethodId != null && paymentMethodId.isNotEmpty) {
        body['payment_method_id'] = paymentMethodId;
      }
      if (accountIdentifier != null && accountIdentifier.isNotEmpty) {
        body['account_identifier'] = accountIdentifier;
      }
      if (accountName != null && accountName.isNotEmpty) {
        body['account_name'] = accountName;
      }
      if (details != null && details.isNotEmpty) {
        body['details'] = details;
      }
      final payload = await withOptionalClientLocation(body);
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.bookingPaymentLinkPath(bookingId),
        data: payload.isEmpty ? null : payload,
      );
      return PaymentLinkResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<RefundWalletSummary> getWallet() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.paymentWalletPath,
      );
      return RefundWalletSummary.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<WalletTopUpResult> createWalletTopUp({
    required String amount,
    required String currencyCode,
    required String paymentMethodId,
    required String accountIdentifier,
    String? accountName,
    Map<String, String>? details,
  }) async {
    try {
      final body = await withOptionalClientLocation({
        'amount': amount,
        'currency_code': currencyCode,
        'payment_method_id': paymentMethodId,
        'account_identifier': accountIdentifier,
        if (accountName != null && accountName.isNotEmpty)
          'account_name': accountName,
        if (details != null && details.isNotEmpty) 'details': details,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.paymentWalletTopUpPath,
        data: body,
      );
      return WalletTopUpResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return NetworkFailure.unknown(message: detail);
      }
      // Flatten first field error if present.
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          return NetworkFailure.unknown(message: v.first.toString());
        }
        if (v is String && v.isNotEmpty) {
          return NetworkFailure.unknown(message: v);
        }
      }
    }
    final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}

class PaymentLinkResult {
  const PaymentLinkResult({
    this.url,
    required this.merchantReference,
    required this.transactionId,
    required this.amountCharged,
    required this.walletApplied,
    required this.fullyPaid,
    this.status,
    this.message,
  });

  factory PaymentLinkResult.fromJson(Map<String, dynamic> json) {
    return PaymentLinkResult(
      url: json['url']?.toString(),
      merchantReference: json['merchant_reference']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      amountCharged: json['amount_charged']?.toString() ?? '',
      walletApplied: json['wallet_applied']?.toString() ?? '0',
      fullyPaid: json['fully_paid'] == true,
      status: json['status']?.toString(),
      message: json['message']?.toString(),
    );
  }

  final String? url;
  final String? merchantReference;
  final String? transactionId;
  final String amountCharged;
  final String walletApplied;
  final bool fullyPaid;
  final String? status;
  final String? message;
}

class RefundWalletBalance {
  const RefundWalletBalance({
    required this.currencyCode,
    required this.balance,
  });

  final String currencyCode;
  final String balance;
}

class RefundWalletSummary {
  const RefundWalletSummary({
    required this.balances,
    required this.totalCredited,
  });

  factory RefundWalletSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['balances'];
    final balances = <RefundWalletBalance>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          balances.add(
            RefundWalletBalance(
              currencyCode: row['currency_code']?.toString() ?? '',
              balance: row['balance']?.toString() ?? '0',
            ),
          );
        }
      }
    }
    return RefundWalletSummary(
      balances: balances,
      totalCredited: json['total_credited']?.toString() ?? '0',
    );
  }

  final List<RefundWalletBalance> balances;
  final String totalCredited;
}

class WalletTopUpResult {
  const WalletTopUpResult({
    this.url,
    required this.merchantReference,
    required this.transactionId,
    required this.amount,
    this.status,
    this.message,
  });

  factory WalletTopUpResult.fromJson(Map<String, dynamic> json) {
    return WalletTopUpResult(
      url: json['url']?.toString(),
      merchantReference: json['merchant_reference']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      amount: json['amount']?.toString() ?? '',
      status: json['status']?.toString(),
      message: json['message']?.toString(),
    );
  }

  final String? url;
  final String? merchantReference;
  final String? transactionId;
  final String amount;
  final String? status;
  final String? message;
}
