import 'package:dio/dio.dart';
import 'models/api_response.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiException({
    required this.message,
    this.statusCode,
    this.error,
  });

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out',
          statusCode: error.response?.statusCode,
          error: error,
        );

      case DioExceptionType.badResponse:
        try {
          final data = error.response?.data;
          if (data != null && data is Map<String, dynamic>) {
            // Check for Rails-style errors
            if (data.containsKey('errors')) {
              final errors = data['errors'];
              if (errors is Map<String, dynamic>) {
                // Handle field-specific errors
                final messages = errors.entries
                    .map((e) => '${e.key} ${e.value.join(', ')}')
                    .join('. ');
                return ApiException(
                  message: messages,
                  statusCode: error.response?.statusCode,
                  error: error,
                );
              } else if (errors is List) {
                // Handle general errors
                return ApiException(
                  message: errors.join('. '),
                  statusCode: error.response?.statusCode,
                  error: error,
                );
              }
            }
          }

          // Fallback to API response format
          final response = ApiResponse<dynamic>.fromJson(
            data ?? {},
            (json) => json,
          );

          return ApiException(
            message: response.errors.isNotEmpty
                ? response.errors.first.detail
                : 'Server error',
            statusCode: error.response?.statusCode,
            error: error,
          );
        } catch (_) {
          return ApiException(
            message: error.response?.statusMessage ?? 'Server error',
            statusCode: error.response?.statusCode,
            error: error,
          );
        }

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request cancelled',
          statusCode: error.response?.statusCode,
          error: error,
        );

      case DioExceptionType.connectionError:
        return ApiNetworkException(
          message: 'No internet connection',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'Invalid certificate',
          statusCode: error.response?.statusCode,
          error: error,
        );

      case DioExceptionType.unknown:
        return ApiException(
          message: error.message ?? 'Unknown error occurred',
          statusCode: error.response?.statusCode,
          error: error,
        );
    }
  }

  @override
  String toString() {
    return 'ApiException{message: $message, statusCode: $statusCode, error: $error}';
  }
}

class ApiValidationException extends ApiException {
  ApiValidationException({required String message, int? statusCode})
      : super(message: message, statusCode: statusCode);
}

class ApiNetworkException extends ApiException {
  ApiNetworkException({required String message, int? statusCode})
      : super(message: message, statusCode: statusCode);
}
