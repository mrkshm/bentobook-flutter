import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'api_exception.dart';
import 'models/api_response.dart';
import 'models/user.dart';
import "api_endpoints.dart";

class ApiClient {
  late final Dio _dio;
  final EnvConfig config;
  String? _token;
  void Function()? onRefreshFailed;

  ApiClient({
    required this.config,
    this.onRefreshFailed,
  }) : _dio = Dio(
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
              // Token refresh failed
              onRefreshFailed?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) {
    _token = token;
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
      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.meta?.token != null) {
        _token = apiResponse.meta?.token;
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
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
      rethrow;
    }
  }

  Future<ApiResponse<User>> updateProfile({String? preferredTheme}) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.updateProfile,
        data: {
          'profile': {
            if (preferredTheme != null) 'preferred_theme': preferredTheme,
          },
        },
      );

      return ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException error) {
    return ApiException.fromDioError(error);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(envConfigProvider);
  return ApiClient(config: config);
});