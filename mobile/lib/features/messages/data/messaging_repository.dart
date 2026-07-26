import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/api_list_response.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_models.dart';

class MessagingRepository {
  MessagingRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<List<ConversationSummary>> listConversations({
    int page = 1,
    int pageSize = 50,
    String? organizationId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.messagingConversationsPath,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (organizationId != null) 'organization_id': organizationId,
        },
      );
      return parseJsonList(response.data, ConversationSummary.fromJson);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationSummary> getConversation(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.messagingConversationPath(id),
      );
      return ConversationSummary.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<ConversationMessageModel>> listMessages(
    String conversationId, {
    String? since,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.messagingMessagesPath(conversationId),
        queryParameters: {
          if (since != null) 'since': since,
        },
      );
      final results = response.data?['results'];
      if (results is! List) return [];
      return results
          .whereType<Map>()
          .map((e) => ConversationMessageModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationMessageModel> sendMessage(
    String conversationId,
    String body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingMessagesPath(conversationId),
        data: {'body': body},
      );
      return ConversationMessageModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post(AppConstants.messagingReadPath(conversationId));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationSummary> block(String conversationId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingBlockPath(conversationId),
      );
      return ConversationSummary.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationSummary> unblock(String conversationId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingUnblockPath(conversationId),
      );
      return ConversationSummary.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<String> submitInvite({
    String? email,
    String? phone,
    String? trustAlias,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingInvitesPath,
        data: {
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (trustAlias != null) 'trust_alias': trustAlias,
        },
      );
      return response.data?['detail'] as String? ?? '';
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<ConversationInviteModel>> listIncomingInvites() async {
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.messagingInvitesIncomingPath,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map(
            (e) => ConversationInviteModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationSummary> acceptInvite(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingInviteAcceptPath(id),
      );
      return ConversationSummary.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> declineInvite(String id, {bool block = false}) async {
    try {
      await _dio.post(
        AppConstants.messagingInviteDeclinePath(id),
        data: {'block': block},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<ConversationSummary> openPlatformSupport({String? userId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.messagingPlatformSupportPath,
        data: {
          if (userId != null) 'user_id': userId,
        },
      );
      return ConversationSummary.fromJson(response.data ?? {});
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
