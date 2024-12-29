import 'package:bentobook/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/config/env_config.dart';

class MockDio extends Mock implements Dio {
  final _interceptors = Interceptors();

  @override
  Interceptors get interceptors => _interceptors;
}

void main() {
  late ApiClient apiClient;
  late MockDio mockDio;
  late EnvConfig config;

  setUp(() {
    mockDio = MockDio();
    config = EnvConfig(
      environment: Environment.dev,
      apiBaseUrl: 'http://test.com',
      connectionTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      enableLogging: true,
    );
    apiClient = ApiClient(config: config, dio: mockDio);

    // Register fallback values for Dio
    registerFallbackValue(RequestOptions());
  });

  group('checkUsernameAvailability', () {
    test('returns true when username is available', () async {
      // Arrange
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            data: {
              'status': 'success',
              'data': {'available': true}
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ));

      // Act
      final result = await apiClient.checkUsernameAvailability('testuser');

      // Assert
      expect(result, true);
      verify(() => mockDio.post(
            '/usernames/verify',
            data: {'username': 'testuser'},
          )).called(1);
    });

    test('returns false when username is taken', () async {
      // Arrange
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            data: {
              'status': 'success',
              'data': {'available': false}
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ));

      // Act
      final result = await apiClient.checkUsernameAvailability('testuser');

      // Assert
      expect(result, false);
      verify(() => mockDio.post(
            '/usernames/verify',
            data: {'username': 'testuser'},
          )).called(1);
    });

    test('throws ApiException when response format is invalid', () async {
      // Arrange
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            data: {'invalid': 'format'},
            statusCode: 200,
            requestOptions: RequestOptions(),
          ));

      // Act & Assert
      expect(
        () => apiClient.checkUsernameAvailability('testuser'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
