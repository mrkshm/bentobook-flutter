import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_endpoints.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInterceptors extends Mock implements Interceptors {}
class MockDio extends Mock implements Dio {
  final interceptors = Interceptors();
}
class MockResponse extends Mock implements Response {}
class MockEnvConfig extends Mock implements EnvConfig {}

void main() {
  late ApiClient apiClient;
  late MockDio mockDio;
  late MockEnvConfig mockConfig;

  setUp(() {
    mockDio = MockDio();
    mockConfig = MockEnvConfig();
    
    when(() => mockConfig.apiBaseUrl).thenReturn('https://api.example.com');
    when(() => mockConfig.connectionTimeout).thenReturn(const Duration(seconds: 30));
    when(() => mockConfig.receiveTimeout).thenReturn(const Duration(seconds: 30));
    when(() => mockConfig.enableLogging).thenReturn(false);
    
    apiClient = ApiClient(
      config: mockConfig,
      dio: mockDio,
    );
  });

  group('Profile Update Tests', () {
    final testProfile = Profile(
      username: 'testuser',
      firstName: 'Test',
      lastName: 'User',
      about: 'Test bio',
      fullName: 'Test User',
      displayName: 'Test',
      preferredTheme: 'light',
      preferredLanguage: 'en',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      email: 'test@example.com',
      avatarUrls: const AvatarUrls(
        thumbnail: 'thumb.jpg',
        small: 'small.jpg',
        medium: 'medium.jpg',
        large: 'large.jpg',
        original: 'original.jpg',
      ),
    );

    test('updateProfile success', () async {
      final updateRequest = ProfileUpdateRequest(
        displayName: 'New Name',
        about: 'New bio',
      );

      final successResponse = {
        'status': 'success',
        'data': {
          'username': 'testuser',
          'first_name': 'Test',
          'last_name': 'User',
          'about': 'Test bio',
          'full_name': 'Test User',
          'display_name': 'Test',
          'preferred_theme': 'light',
          'preferred_language': 'en',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'email': 'test@example.com',
          'avatar_urls': {
            'thumbnail': 'thumb.jpg',
            'small': 'small.jpg',
            'medium': 'medium.jpg',
            'large': 'large.jpg',
            'original': 'original.jpg',
          },
        },
      };

      when(() => mockDio.put(
            ApiEndpoints.updateProfile,
            data: updateRequest.toJson(),
          )).thenAnswer((_) async => Response(
            data: successResponse,
            statusCode: 200,
            requestOptions: RequestOptions(),
          ));

      final response = await apiClient.updateProfile(request: updateRequest);

      expect(response.isSuccess, true);
      expect(response.data, isA<Profile>());
      verify(() => mockDio.put(
            ApiEndpoints.updateProfile,
            data: updateRequest.toJson(),
          )).called(1);
    });

    test('updateProfile failure', () async {
      final updateRequest = ProfileUpdateRequest(
        displayName: 'New Name',
        about: 'New bio',
      );

      when(() => mockDio.put(
            ApiEndpoints.updateProfile,
            data: updateRequest.toJson(),
          )).thenThrow(DioException(
            response: Response(
              data: {
                'status': 'error',
                'errors': [
                  {'code': 'invalid_request', 'detail': 'Invalid profile data'}
                ],
              },
              statusCode: 400,
              requestOptions: RequestOptions(),
            ),
            requestOptions: RequestOptions(),
          ));

      expect(
        () => apiClient.updateProfile(request: updateRequest),
        throwsA(isA<ApiException>()),
      );
    });

    test('updateProfile with validation errors', () async {
      final updateRequest = ProfileUpdateRequest(
        displayName: '', // Invalid empty name
      );

      when(() => mockDio.put(
            ApiEndpoints.updateProfile,
            data: updateRequest.toJson(),
          )).thenThrow(DioException(
            response: Response(
              data: {
                'status': 'error',
                'errors': [
                  {'code': 'validation_error', 'detail': 'Display name cannot be empty'}
                ],
              },
              statusCode: 422,
              requestOptions: RequestOptions(),
            ),
            requestOptions: RequestOptions(),
          ));

      expect(
        () => apiClient.updateProfile(request: updateRequest),
        throwsA(isA<ApiValidationException>()),
      );
    });

    test('updateProfile with network error', () async {
      final updateRequest = ProfileUpdateRequest(
        displayName: 'New Name',
      );

      when(() => mockDio.put(
            ApiEndpoints.updateProfile,
            data: updateRequest.toJson(),
          )).thenThrow(DioException(
            type: DioExceptionType.connectionTimeout,
            requestOptions: RequestOptions(),
          ));

      expect(
        () => apiClient.updateProfile(request: updateRequest),
        throwsA(isA<ApiNetworkException>()),
      );
    });
  });
}
