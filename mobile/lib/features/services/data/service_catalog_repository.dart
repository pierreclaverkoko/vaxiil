import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';

/// Paginated catalog page (`count` / `next` / `results` from DRF).
class ServiceCatalogPageResult {
  const ServiceCatalogPageResult({
    required this.items,
    required this.hasMore,
  });

  final List<ServiceListItemModel> items;
  final bool hasMore;
}

class ServiceCatalogRepository {
  ServiceCatalogRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<ServiceCategoryModel>> listCategories() async {
    try {
      final response = await _dio.get<dynamic>(AppConstants.serviceCategoriesPath);
      return parseJsonList(response.data, ServiceCategoryModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Catalog services (paginated; first page by default).
  /// Single service with variants, media, features (`GET services/{id}/`).
  Future<ServiceDetailModel> getService(String serviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.serviceCatalogPath}$serviceId/',
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Open slots for [date] (`YYYY-MM-DD` calendar day in local time).
  Future<OpenSlotsResult> listOpenSlots(
    String serviceId,
    DateTime date, {
    int? durationMinutes,
    String? excludeBookingId,
  }) async {
    try {
      final qp = <String, dynamic>{
        'date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      };
      if (durationMinutes != null) {
        qp['duration_minutes'] = durationMinutes;
      }
      if (excludeBookingId != null && excludeBookingId.isNotEmpty) {
        qp['exclude_booking'] = excludeBookingId;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.serviceOpenSlotsPath(serviceId),
        queryParameters: qp,
      );
      return OpenSlotsResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<ServiceListItemModel>> listServices({
    String? search,
    bool? featured,
    String? categoryId,
    String? subCategoryId,
    String? countryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (featured != null) {
        query['featured'] = featured;
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query['category'] = categoryId;
      }
      if (subCategoryId != null && subCategoryId.isNotEmpty) {
        query['sub_category'] = subCategoryId;
      }
      if (countryId != null && countryId.isNotEmpty) {
        query['country'] = countryId;
      }
      final response = await _dio.get<dynamic>(
        AppConstants.serviceCatalogPath,
        queryParameters: query,
      );
      return parseJsonList(response.data, ServiceListItemModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Same filters as [listServices], but returns pagination via API `next`.
  Future<ServiceCatalogPageResult> listServicesPage({
    String? search,
    bool? featured,
    String? categoryId,
    String? subCategoryId,
    String? countryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (featured != null) {
        query['featured'] = featured;
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query['category'] = categoryId;
      }
      if (subCategoryId != null && subCategoryId.isNotEmpty) {
        query['sub_category'] = subCategoryId;
      }
      if (countryId != null && countryId.isNotEmpty) {
        query['country'] = countryId;
      }
      final response = await _dio.get<dynamic>(
        AppConstants.serviceCatalogPath,
        queryParameters: query,
      );
      final data = response.data;
      final items = parseJsonList(data, ServiceListItemModel.fromJson);
      var hasMore = false;
      if (data is Map) {
        final next = data['next'];
        hasMore = next != null && next.toString().trim().isNotEmpty;
      }
      return ServiceCatalogPageResult(items: items, hasMore: hasMore);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}
