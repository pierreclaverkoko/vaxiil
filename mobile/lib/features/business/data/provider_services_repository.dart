import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';

/// Verified-organization service CRUD (`/organizations/{id}/services/`).
class ProviderServicesRepository {
  ProviderServicesRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<ServiceListItemModel>> listServices(
    String organizationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.organizationServicesPath(organizationId),
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return parseJsonList(response.data, ServiceListItemModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ServiceDetailModel> getService(
    String organizationId,
    String serviceId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.organizationServicesPath(organizationId)}$serviceId/',
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ServiceDetailModel> createService(
    String organizationId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.organizationServicesPath(organizationId),
        data: body,
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ServiceDetailModel> updateService(
    String organizationId,
    String serviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${AppConstants.organizationServicesPath(organizationId)}$serviceId/',
        data: body,
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ServiceDetailModel> uploadPrimaryImage(
    String organizationId,
    String serviceId,
    String filePath,
  ) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.organizationServiceMediaPath(organizationId, serviceId),
        data: form,
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> deleteService(String organizationId, String serviceId) async {
    try {
      await _dio.delete<void>(
        '${AppConstants.organizationServicesPath(organizationId)}$serviceId/',
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<ServiceSubCategoryBrief>> listSubcategories() async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.serviceSubcategoriesPath,
      );
      return parseJsonList(response.data, ServiceSubCategoryBrief.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<ServiceFeatureItemModel>> listFeatures() async {
    try {
      final response = await _dio.get<dynamic>(AppConstants.serviceFeaturesPath);
      return parseJsonList(response.data, ServiceFeatureItemModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}
