import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as dev;

class ImagePaths {
  final String thumbnailPath;
  final String mediumPath;

  ImagePaths({required this.thumbnailPath, required this.mediumPath});
}

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

  String generateImageFileName(int userId, String size) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'profile_${userId}_${size}_$timestamp.webp';
  }

  Future<void> cleanupOldImages(int userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final baseDir = Directory('${directory.path}/profiles/$userId');
    if (!await baseDir.exists()) return;

    for (var variant in ['thumbnail', 'medium']) {
      final variantDir = Directory('${baseDir.path}/$variant');
      if (!await variantDir.exists()) continue;

      final files = variantDir.listSync();
      if (files.length > 2) {
        // Keep only the most recent file
        files.sort((a, b) => File(b.path)
            .lastModifiedSync()
            .compareTo(File(a.path).lastModifiedSync()));

        // Delete older files
        for (var i = 1; i < files.length; i++) {
          await File(files[i].path).delete();
        }
      }
    }
  }

  Future<void> deleteUserImages(int userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final userDir = Directory('${directory.path}/profiles/$userId');
    if (await userDir.exists()) {
      await userDir.delete(recursive: true);
    }
  }

  Future<String?> getImagePath(int userId, {String variant = 'medium'}) async {
    final directory = await getApplicationDocumentsDirectory();
    final variantDir = Directory('${directory.path}/profiles/$userId/$variant');
    if (!await variantDir.exists()) return null;

    final files = variantDir.listSync();
    if (files.isEmpty) return null;

    // Get most recent file
    files.sort((a, b) => File(b.path)
        .lastModifiedSync()
        .compareTo(File(a.path).lastModifiedSync()));
    return files.first.path;
  }

  Future<ImagePaths> downloadAndSaveProfileImages({
    required int userId,
    required String thumbnailUrl,
    required String mediumUrl,
  }) async {
    try {
      dev.log('ImageManager: Starting image download');

      final directory = await getApplicationDocumentsDirectory();
      final baseDir = Directory('${directory.path}/profiles/$userId');
      final thumbnailDir = Directory('${baseDir.path}/thumbnail');
      final mediumDir = Directory('${baseDir.path}/medium');

      // Create directories if they don't exist
      await thumbnailDir.create(recursive: true);
      await mediumDir.create(recursive: true);

      // Extract filenames from URLs
      final thumbnailFilename = thumbnailUrl.split('/').last;
      final mediumFilename = mediumUrl.split('/').last;

      final thumbnailPath = '${thumbnailDir.path}/$thumbnailFilename';
      final mediumPath = '${mediumDir.path}/$mediumFilename';

      // Download and save files
      await _downloadFile(thumbnailUrl, thumbnailPath);
      await _downloadFile(mediumUrl, mediumPath);

      return ImagePaths(
        thumbnailPath: thumbnailPath,
        mediumPath: mediumPath,
      );
    } catch (e) {
      dev.log('ImageManager: Failed to download and save profile images',
          error: e);
      rethrow;
    }
  }

  Future<void> cleanupTemporaryFiles(int userId) async {
    final directory = await getTemporaryDirectory();
    final dir = Directory(directory.path);
    final files = dir.listSync();

    for (var file in files) {
      if (file.path.contains('avatar_temp_$userId')) {
        try {
          await File(file.path).delete();
        } catch (e) {
          dev.log('Failed to delete temporary file: ${file.path}', error: e);
        }
      }
    }
  }

  Future<String> generateTempFileName(int userId, String prefix) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${prefix}_${userId}_$timestamp.jpg';
    return '${directory.path}/$fileName';
  }

  Future<void> _downloadFile(String url, String filePath) async {
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final file = File(filePath);
    await file.writeAsBytes(response.data);
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

  Future<void> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      dev.log('Failed to delete image: $e');
      rethrow;
    }
  }
}
