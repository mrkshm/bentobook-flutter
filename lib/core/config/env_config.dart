import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final bool enableLogging;

  EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.connectionTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableLogging = false,
  });

  factory EnvConfig.development() {
    return EnvConfig(
      environment: Environment.dev,
      apiBaseUrl: 'http://localhost:5100/api/v1',
      enableLogging: true,
    );
  }

  factory EnvConfig.production() {
    return EnvConfig(
      environment: Environment.prod,
      apiBaseUrl: 'https://bentobook.app/api/v1',
      enableLogging: false,
    );
  }

  bool get isDevelopment => environment == Environment.dev;
  bool get isProduction => environment == Environment.prod;
}

final envConfigProvider = Provider<EnvConfig>((ref) {
  // Default to development
  return EnvConfig.development();
});