import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';

class BookingsRepository {
  BookingsRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<BookingListItemModel>> listMine({int page = 1}) async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.bookingsPath,
        queryParameters: {'page': page},
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

  Future<Map<String, dynamic>> cancel(String id, {String reason = ''}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${AppConstants.bookingsPath}$id/cancel/',
        data: {'reason': reason},
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}
