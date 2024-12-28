import 'package:bentobook/core/api/models/profile.dart';
import 'package:dio/dio.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'api_exception.dart';
import 'models/api_response.dart';
import 'models/user.dart';
import 'api_endpoints.dart';
import 'dart:developer' as dev;
import 'dart:convert';

class ApiClient {
  final Dio _dio;
  final EnvConfig config;
  String? _token;
  void Function()? onRefreshFailed;

  ApiClient({
    required this.config,
    this.onRefreshFailed,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout: config.connectionTimeout,
                receiveTimeout: config.receiveTimeout,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    if (config.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && _token != null) {
            try {
              final refreshed = await refreshToken();
              if (refreshed) {
                // Retry the original request
                return handler.resolve(await _dio.fetch(error.requestOptions));
              }
            } catch (e) {
              dev.log('Failed to refresh token', error: e);
              if (onRefreshFailed != null) {
                onRefreshFailed!();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) {
    _token = token;
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  String? getUserIdFromToken() {
    if (_token == null) return null;

    try {
      // Get payload part of JWT (second part between dots)
      final parts = _token!.split('.');
      if (parts.length != 3) return null;

      // Decode base64
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(decoded);

      // Get sub claim which contains user ID
      return data['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Auth endpoints
  Future<ApiResponse<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'user': {
            'email': email,
            'password': password,
          },
        },
      );
      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.meta?.token != null) {
        _token = apiResponse.meta?.token;
      }
      return apiResponse;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ApiResponse<User>> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'user': {
            'email': email,
            'password': password,
          },
        },
      );
      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.meta?.token != null) {
        _token = apiResponse.meta?.token;
      }
      return apiResponse;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ApiResponse<User>> registerOld({
    required String email,
    required String password,
    String? passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'user': {
            'email': email,
            'password': password,
            'password_confirmation': passwordConfirmation ?? password,
          },
        },
      );

      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.meta?.token != null) {
        _token = apiResponse.meta?.token;
      }
      return apiResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    if (_token == null) return;

    try {
      await _dio.delete(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw _handleError(e);
    } finally {
      _token = null;
    }
  }

  Future<bool> refreshToken() async {
    try {
      final response = await _dio.post(ApiEndpoints.refreshToken);
      final jsonData = response.data as Map<String, dynamic>;

      if (jsonData['status'] == 'success' && jsonData['data'] != null) {
        final token = jsonData['data']['attributes']['token'] as String;
        _token = token;
        return true;
      }
      return false;
    } catch (e) {
      dev.log('ApiClient: Error refreshing token', error: e);
      return false;
    }
  }

  Future<ApiResponse<User>> getMe() async {
    try {
      final response = await get(ApiEndpoints.profile);
      return ApiResponse<User>.fromJson(
        response as Map<String, dynamic>,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      dev.log('Failed to get current user', error: e);
      rethrow;
    }
  }

  Future<ApiResponse<Profile>> getProfile(String userId) async {
    try {
      final response = await get(ApiEndpoints.profile);
      return ApiResponse<Profile>.fromJson(
        response as Map<String, dynamic>,
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
            statusCode: e.response?.statusCode);
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw ApiNetworkException(
            message: 'Network error: ${e.message}',
            statusCode: e.response?.statusCode);
      }
      throw ApiException.fromDioError(e);
    } catch (e) {
      dev.log('Unexpected error while updating profile', error: e);
      throw ApiException(message: 'Failed to update profile: $e');
    }
  }

  ApiException _handleError(DioException error) {
    return ApiException.fromDioError(error);
  }
}
