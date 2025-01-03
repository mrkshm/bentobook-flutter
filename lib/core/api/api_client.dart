import 'package:dio/dio.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'api_exception.dart';
import 'models/api_response.dart';
import 'models/user.dart';
import 'api_endpoints.dart';
import 'dart:developer' as dev;
import 'dart:convert';
import 'profile_api.dart';

class ApiClient {
  late final Dio _dio;
  late final ProfileApi profileApi;
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
    profileApi = ProfileApi(_dio);
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

  ApiException _handleError(DioException error) {
    return ApiException.fromDioError(error);
  }

  Dio get dio => _dio;
}
