import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class ImageManager {
  final Dio _dio;
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  ImageManager({required Dio dio}) : _dio = dio;

  Future<String> getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/profile_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  Future<String> downloadImage(String url, String fileName) async {
    final imageDir = await getImageDirectory();
    final filePath = path.join(imageDir, fileName);

    // Check if file already exists
    if (await File(filePath).exists()) {
      return filePath;
    }

    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = File(filePath);
      await file.writeAsBytes(response.data);
      return filePath;
    } catch (e) {
      throw ImageDownloadException('Failed to download image: $e');
    }
  }

  Future<void> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw ImageDeleteException('Failed to delete image: $e');
    }
  }

  String generateImageFileName(int userId, String size) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'profile_${userId}_${size}_$timestamp.webp';
  }

  Future<void> cleanupOldImages(int userId) async {
    final directory = await getImageDirectory();
    final dir = Directory(directory);
    final files = dir.listSync();

    // Keep track of current profile images
    final currentImages = <String>[];

    // Find current profile images
    for (var file in files) {
      if (file.path.contains('profile_${userId}_')) {
        currentImages.add(file.path);
      }
    }

    // Keep only the most recent versions
    if (currentImages.length > 4) {
      // Keep last 2 sets (thumbnail & medium)
      currentImages.sort((a, b) =>
          File(b).lastModifiedSync().compareTo(File(a).lastModifiedSync()));

      // Delete older files
      for (var i = 4; i < currentImages.length; i++) {
        await File(currentImages[i]).delete();
      }
    }
  }

  Future<void> deleteUserImages(int userId) async {
    final directory = await getImageDirectory();
    final dir = Directory(directory);
    final files = dir.listSync();

    for (var file in files) {
      if (file.path.contains('profile_${userId}_')) {
        await File(file.path).delete();
      }
    }
  }

  Future<String?> getImagePath(int userId, {String variant = 'medium'}) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/profiles/$userId/$variant.jpg';
  }

  Future<void> downloadAndSaveProfileImages({
    required String userId,
    required String thumbnailUrl,
    required String mediumUrl,
  }) async {
    try {
      // Quick fix: replace localhost with localhost:5100
      // TODO: remove this once we have a proper backend
      final fixedThumbnailUrl = thumbnailUrl.replaceFirst(
          'http://localhost/', 'http://localhost:5100/');
      final fixedMediumUrl =
          mediumUrl.replaceFirst('http://localhost/', 'http://localhost:5100/');

      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${directory.path}/profiles/$userId');
      await profileDir.create(recursive: true);

      await _retryWithBackoff(() async {
        // Download thumbnail
        final thumbnailResponse = await _dio.get(
          fixedThumbnailUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final thumbnailFile = File('${profileDir.path}/thumbnail.jpg');
        await thumbnailFile.writeAsBytes(thumbnailResponse.data);

        // Download medium
        final mediumResponse = await _dio.get(
          fixedMediumUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final mediumFile = File('${profileDir.path}/medium.jpg');
        await mediumFile.writeAsBytes(mediumResponse.data);
      });
    } catch (e) {
      throw ImageDownloadException('Failed to download profile images: $e');
    }
  }

  Future<T> _retryWithBackoff<T>(Future<T> Function() operation) async {
    for (var i = 0; i < _maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == _maxRetries - 1) rethrow;
        await Future.delayed(_retryDelays[i]);
      }
    }
    throw Exception('Retry failed after $_maxRetries attempts');
  }
}

class ImageDownloadException implements Exception {
  final String message;
  ImageDownloadException(this.message);
  @override
  String toString() => message;
}

class ImageDeleteException implements Exception {
  final String message;
  ImageDeleteException(this.message);
  @override
  String toString() => message;
}
