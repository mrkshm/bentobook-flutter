import 'dart:io';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
  final String? imagePath;
  final double radius;
  final Color backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.imagePath,
    this.radius = 50,
    required this.backgroundColor,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  ImageProvider? _imageProvider;

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath) {
      _updateImageProvider();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateImageProvider();
  }

  void _updateImageProvider() {
    if (widget.imagePath != null) {
      final cleanPath = widget.imagePath!.split('?').first;
      _imageProvider = FileImage(File(cleanPath));
      imageCache.clear();
      imageCache.clearLiveImages();
    } else {
      _imageProvider = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: _imageProvider,
      child: _imageProvider == null
          ? Icon(Icons.person_outline,
              size: widget.radius,
              color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
    );
  }
}
