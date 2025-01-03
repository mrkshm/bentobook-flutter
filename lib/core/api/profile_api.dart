import 'package:dio/dio.dart';
import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/api/models/api_response.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/api/api_endpoints.dart';
import 'dart:io';
import 'dart:developer' as dev;

class ProfileApi {
  final Dio _dio;

  ProfileApi(this._dio);

  Future<ApiResponse<Profile>> getProfile(String userId) async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      return ApiResponse<Profile>.fromJson(
        response.data as Map<String, dynamic>,
        (json) => Profile.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      dev.log('Failed to get profile', error: e);
      rethrow;
    }
  }

  Future<ApiResponse<Profile>> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
    String? username,
  }) async {
    try {
      dev.log('Updating profile');
      final response = await _dio.put(
        ApiEndpoints.updateProfile,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'about': about,
          'display_name': displayName,
          'preferred_theme': preferredTheme,
          'preferred_language': preferredLanguage,
          'username': username,
        },
      );

      return ApiResponse<Profile>.fromJson(
        response.data as Map<String, dynamic>,
        (json) => Profile.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      dev.log('Failed to update profile', error: e);
      if (e.response?.statusCode == 422) {
        throw ApiValidationException(
          message: 'Validation error: ${e.response?.data['errors']}',
          statusCode: e.response?.statusCode,
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  Future<ApiResponse<Profile>> uploadAvatar(String userId, File imageFile,
      {String? filename}) async {
    try {
      final formData = FormData.fromMap({
        'profile[avatar]': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.patch(
        ApiEndpoints.updateAvatar,
        data: formData,
        onSendProgress: (sent, total) {
          if (total != -1) {
            final progress = (sent / total * 100).toStringAsFixed(2);
            dev.log('Upload progress: $progress%');
          }
        },
      );

      return ApiResponse<Profile>.fromJson(
        response.data,
        (json) => Profile.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      dev.log('Failed to upload avatar', error: e);
      rethrow;
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      dev.log('Checking username availability');
      final response = await _dio.post(
        ApiEndpoints.verifyUsername,
        data: {
          'username': username,
        },
      );

      if (response.data['status'] == 'success' &&
          response.data['data'] != null &&
          response.data['data']['attributes'] != null) {
        return response.data['data']['attributes']['available'] as bool;
      }

      throw ApiException(message: 'Invalid response format from server');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ApiResponse<Profile>> deleteAvatar(String userId) async {
    try {
      final response = await _dio.delete(ApiEndpoints.deleteAvatar);
      return ApiResponse<Profile>.fromJson(
        response.data,
        (json) => Profile.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
