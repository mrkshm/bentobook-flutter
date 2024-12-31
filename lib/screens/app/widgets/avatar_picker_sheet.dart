import 'package:bentobook/screens/app/widgets/image_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:image_cropper/image_cropper.dart';

class AvatarPickerSheet extends StatefulWidget {
  final Function(String) onImagePicked;
  final Function onDelete;

  const AvatarPickerSheet({
    super.key,
    required this.onImagePicked,
    required this.onDelete,
  });

  static void show(
      BuildContext context, Function(String) onImagePicked, Function onDelete) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => AvatarPickerSheet(
        onImagePicked: onImagePicked,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
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

      // Show preview sheet
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => ImagePreviewSheet(
          imagePath: croppedFile.path,
        ),
      );

      if (confirmed == true && mounted) {
        widget.onImagePicked(croppedFile.path);
        Navigator.pop(context);
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
