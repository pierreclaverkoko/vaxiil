import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_metadata_models.dart';
import 'package:vaxiil_mobile/features/auth/data/legal_document_models.dart';

class LegalRepository {
  LegalRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<AuthMetadata> fetchMetadata() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.authMetadataPath,
      );
      return AuthMetadata.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<LegalDocumentContent> fetchDocument({
    required String documentType,
    required String languageCode,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.legalDocumentPath(documentType),
        queryParameters: {'lang': languageCode},
      );
      return LegalDocumentContent.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) {
        return NetworkFailure.badRequest(message: detail);
      }
    }
    return NetworkFailure.unknown(message: e.message ?? 'Network error');
  }
}
