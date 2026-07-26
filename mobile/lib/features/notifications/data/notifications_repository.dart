import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/notifications/data/notification_models.dart';

class NotificationsRepository {
  NotificationsRepository({required DioClient dioClient})
      : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<NotificationModel>> list({
    int page = 1,
    int pageSize = 50,
    String scope = 'personal',
    String? organizationId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.notificationsPath,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (organizationId != null)
            'organization_id': organizationId
          else
            'scope': scope,
        },
      );
      return parseJsonList(response.data, NotificationModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<NotificationModel> markRead(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.notificationMarkReadPath(id),
      );
      return NotificationModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<int> markAllRead({
    String scope = 'personal',
    String? organizationId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.notificationsMarkAllReadPath,
        queryParameters: {
          if (organizationId != null)
            'organization_id': organizationId
          else
            'scope': scope,
        },
      );
      final updated = response.data?['updated'];
      if (updated is int) return updated;
      if (updated is num) return updated.toInt();
      return 0;
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
