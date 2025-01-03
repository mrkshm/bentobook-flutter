import 'dart:io';

import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/screens/app/widgets/image_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvatarPickerSheet extends ConsumerStatefulWidget {
  final Function(String) onImagePicked;
  final Function onDelete;
  final int userId;

  const AvatarPickerSheet({
    super.key,
    required this.onImagePicked,
    required this.onDelete,
    required this.userId,
  });

  static void show(BuildContext context, int userId,
      Function(String) onImagePicked, Function onDelete) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => AvatarPickerSheet(
        onImagePicked: onImagePicked,
        onDelete: onDelete,
        userId: userId,
      ),
    );
  }

  @override
  ConsumerState<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends ConsumerState<AvatarPickerSheet> {
  bool _isLoading = false;
  String? _error;
  Timer? _loadingTimer;

  void _setLoading(bool loading) {
    _loadingTimer?.cancel();
    if (loading) {
      // Only show loading indicator if operation takes longer than 300ms
      _loadingTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _isLoading = true);
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      _setLoading(true);
      _error = null;

      final imageManager = ref.read(imageManagerProvider);
      final profileRepository = ref.read(profileRepositoryProvider);

      // Pick image
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null || !mounted) return;

      // Crop image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null || !mounted) return;

      // Generate a temporary file name
      final tempPath =
          imageManager.generateTempFileName(widget.userId, 'avatar_temp');

      // Compress and save to temp location
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        croppedFile.path,
        tempPath,
        quality: 85,
        format: CompressFormat.jpeg,
        minWidth: 1000,
        minHeight: 1000,
      );

      if (!mounted) return;

      final fileSize = await compressedFile!.length();

      if (!mounted) return;
      // Show preview sheet with file info
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => ImagePreviewSheet(
          imagePath: compressedFile.path,
          fileSize: fileSize,
        ),
      );

      if (confirmed == true && mounted) {
        try {
          // Upload the image
          await profileRepository.uploadAvatar(
              widget.userId, File(compressedFile.path));
          if (mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = 'Failed to upload image: $e';
            });
          }
        } finally {
          // Clean up temporary file
          await imageManager.deleteImage(compressedFile.path);
        }
      } else {
        // Clean up temporary file if not confirmed
        await imageManager.deleteImage(compressedFile.path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to process image: $e';
      });
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Take Photo'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Choose from Gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Avatar'),
              onTap: () {
                widget.onDelete();
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}
