import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';

class OrganizationRepository {
  OrganizationRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<OrganizationModel>> listMine() async {
    try {
      final response = await _dio.get<dynamic>(AppConstants.organizationsPath);
      return parseJsonList(response.data, OrganizationModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<OrganizationMineSummaryModel> mineSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.organizationsMineSummaryPath,
      );
      return OrganizationMineSummaryModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Verified organizations for client home (not limited to memberships).
  Future<List<OrganizationDiscoveryModel>> listDiscovery() async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.organizationsDiscoveryPath,
      );
      return parseJsonList(response.data, OrganizationDiscoveryModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<OrganizationModel> getById(String id) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('organizations/$id/');
      return OrganizationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<OrganizationModel> create({
    required String typeId,
    required String name,
    required String email,
    required String address,
    required String city,
    required String postalCode,
    required String countryId,
    required Uint8List logoBytes,
    required String logoFilename,
    String? phone,
    String? description,
    String? website,
    bool? requireClientName,
  }) async {
    try {
      final form = FormData.fromMap({
        'type': typeId,
        'name': name,
        'email': email,
        'address': address,
        'city': city,
        'postal_code': postalCode,
        'country': countryId,
        'logo': MultipartFile.fromBytes(logoBytes, filename: logoFilename),
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (website != null && website.isNotEmpty) 'website': website,
        if (requireClientName != null) 'require_client_name': requireClientName,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.organizationsPath,
        data: form,
      );
      return OrganizationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<OrganizationModel> update(
    String id, {
    String? name,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? countryId,
    String? defaultCurrencyId,
    String? primaryAddress,
    String? primaryCity,
    String? primaryPostalCode,
    String? primaryCountryText,
    String? primaryCountryId,
    double? primaryLatitude,
    double? primaryLongitude,
    Uint8List? logoBytes,
    String? logoFilename,
    bool? requireClientName,
  }) async {
    try {
      final logo = logoBytes;
      final hasLogo = logo != null && logo.isNotEmpty;

      if (hasLogo) {
        final form = FormData.fromMap({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (website != null) 'website': website,
          if (requireClientName != null)
            'require_client_name': requireClientName,
          if (countryId != null) 'country': countryId,
          if (defaultCurrencyId != null) 'default_currency': defaultCurrencyId,
          if (primaryAddress != null) 'primary_address': primaryAddress,
          if (primaryCity != null) 'primary_city': primaryCity,
          if (primaryPostalCode != null)
            'primary_postal_code': primaryPostalCode,
          if (primaryCountryText != null)
            'primary_country_text': primaryCountryText,
          if (primaryCountryId != null) 'primary_country': primaryCountryId,
          if (primaryLatitude != null)
            'primary_latitude': primaryLatitude.toString(),
          if (primaryLongitude != null)
            'primary_longitude': primaryLongitude.toString(),
          'logo': MultipartFile.fromBytes(
            logo,
            filename: logoFilename ?? 'logo.jpg',
          ),
        });
        final response = await _dio.patch<Map<String, dynamic>>(
          'organizations/$id/',
          data: form,
        );
        return OrganizationModel.fromJson(response.data!);
      }

      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (website != null) 'website': website,
        if (requireClientName != null) 'require_client_name': requireClientName,
        if (countryId != null) 'country': countryId,
        if (defaultCurrencyId != null) 'default_currency': defaultCurrencyId,
        if (primaryAddress != null) 'primary_address': primaryAddress,
        if (primaryCity != null) 'primary_city': primaryCity,
        if (primaryPostalCode != null) 'primary_postal_code': primaryPostalCode,
        if (primaryCountryText != null)
          'primary_country_text': primaryCountryText,
        if (primaryCountryId != null) 'primary_country': primaryCountryId,
        if (primaryLatitude != null) 'primary_latitude': primaryLatitude,
        if (primaryLongitude != null) 'primary_longitude': primaryLongitude,
      };
      final response = await _dio.patch<Map<String, dynamic>>(
        'organizations/$id/',
        data: data,
      );
      return OrganizationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<CountryBriefModel>> listCountries() async {
    try {
      final response =
          await _dio.get<dynamic>(AppConstants.organizationCountriesPath);
      return parseJsonList(response.data, CountryBriefModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<OrganizationTypeOption>> listTypes() async {
    try {
      final response =
          await _dio.get<dynamic>(AppConstants.organizationTypesPath);
      return parseJsonList(response.data, OrganizationTypeOption.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<TeamMemberModel>> team(String organizationId) async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.organizationTeamPath(organizationId),
      );
      return parseJsonList(response.data, TeamMemberModel.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> inviteTeamMember(
    String organizationId, {
    required String email,
    required String role,
  }) async {
    try {
      await _dio.post<dynamic>(
        AppConstants.organizationTeamInvitePath(organizationId),
        data: {'email': email, 'role': role},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> updateTeamMemberRole(
    String organizationId,
    String membershipId, {
    required String role,
  }) async {
    try {
      await _dio.patch<dynamic>(
        AppConstants.organizationTeamMembershipPath(
            organizationId, membershipId),
        data: {'role': role},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> removeTeamMember(
    String organizationId,
    String membershipId,
  ) async {
    try {
      await _dio.delete<dynamic>(
        AppConstants.organizationTeamMembershipPath(
            organizationId, membershipId),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// KYB document submission (multipart). Requires both document files.
  Future<OrganizationModel> submitVerification({
    required String organizationId,
    required String businessLicensePath,
    required String idDocumentPath,
    String? businessLicenseNumber,
    String? taxId,
  }) async {
    if (kIsWeb) {
      throw const NetworkFailure(
        message: 'KYB upload is not supported on web in this build',
        code: 'NOT_SUPPORTED',
      );
    }
    try {
      final form = FormData.fromMap({
        'business_license_document':
            await MultipartFile.fromFile(businessLicensePath),
        'id_document': await MultipartFile.fromFile(idDocumentPath),
        if (businessLicenseNumber != null && businessLicenseNumber.isNotEmpty)
          'business_license_number': businessLicenseNumber,
        if (taxId != null && taxId.isNotEmpty) 'tax_id': taxId,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.organizationSubmitVerificationPath(organizationId),
        data: form,
      );
      return OrganizationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<OrganizationAnalyticsModel> analytics(String organizationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'organizations/$organizationId/analytics/',
      );
      return OrganizationAnalyticsModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Failure _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return NetworkFailure.badRequest(message: nonField.first.toString());
      }
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return NetworkFailure.badRequest(message: value.first.toString());
        }
        if (value is String && value.isNotEmpty) {
          return NetworkFailure.badRequest(message: value);
        }
      }
    }
    final msg = e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}
