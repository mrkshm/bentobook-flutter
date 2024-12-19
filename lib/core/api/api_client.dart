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
              } else {
                onRefreshFailed?.call();
              }
            } catch (e) {
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

  Future<ApiResponse<User>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'user': {
            'email': email,
            'password': password,
          }
        },
      );
      
      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.meta?.token != null) {
        setToken(apiResponse.meta!.token);
      }

      return apiResponse;
    } on DioException catch (e) {
      throw _handleError(e);
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
        setToken(apiResponse.meta!.token);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      final apiResponse = ApiResponse<User>.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        return apiResponse.data!;
      }
      throw Exception('Failed to get user profile');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout(String token) async {
    try {
      await _dio.delete(
        ApiEndpoints.logout,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  ApiException _handleError(DioException error) {
    if (error.response != null) {
      return ApiException(
        message: error.response?.data?['message'] ?? 'Unknown error occurred',
        statusCode: error.response?.statusCode,
        error: error,
      );
    }
    return ApiException(
      message: error.message ?? 'Network error occurred',
      error: error,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(envConfigProvider);
  return ApiClient(config: config);
});