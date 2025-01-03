import 'dart:async';

import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/validation/profile_validator.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  Timer? _debounceTimer;
  String? _usernameError;
  String? _firstNameError;
  String? _lastNameError;
  String? _aboutError;
  bool _isUsernameFocused = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSaving = false;

  late TextEditingController _usernameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _aboutController;
  final _usernameFocusNode = FocusNode();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _aboutFocusNode = FocusNode();
  bool _hasUnsavedChanges = false;

  void _onUsernameChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      final currentUsername =
          ref.read(profileProvider).profile?.attributes.username;
      final newUsername = _usernameController.text;

      if (currentUsername == newUsername) {
        setState(() {
          _usernameError = null;
        });
        _onFieldChanged();
        return;
      }

      final validationError = ProfileValidator.validateUsername(newUsername);

      setState(() {
        _usernameError = validationError;
      });

      if (validationError == null && _isOnline) {
        try {
          final isAvailable = await ref
              .read(apiClientProvider)
              .profileApi
              .checkUsernameAvailability(newUsername);

          if (mounted) {
            setState(() {
              _usernameError = isAvailable ? null : 'Username is already taken';
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _usernameError = 'Unable to verify username availability';
            });
          }
        }
      }

      _onFieldChanged();
    });
  }

  void _onFieldChanged() {
    final profile = ref.read(profileProvider).profile;

    if (profile == null) return;

    final hasChanges = (_usernameController.text !=
            (profile.attributes.username)) ||
        (_firstNameController.text != (profile.attributes.firstName ?? '')) ||
        (_lastNameController.text != (profile.attributes.lastName ?? '')) ||
        (_aboutController.text != (profile.attributes.about ?? ''));

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<void> _saveChanges() async {
    final firstNameError =
        ProfileValidator.validateName(_firstNameController.text, 'First name');
    final lastNameError =
        ProfileValidator.validateName(_lastNameController.text, 'Last name');
    final aboutError = ProfileValidator.validateAbout(_aboutController.text);

    setState(() {
      _firstNameError = firstNameError;
      _lastNameError = lastNameError;
      _aboutError = aboutError;
    });

    if (_usernameError != null ||
        firstNameError != null ||
        lastNameError != null ||
        aboutError != null) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final repository = ref.read(profileRepositoryProvider);

      final userId = ref.read(authServiceProvider).maybeMap(
            authenticated: (state) => state.userId,
            orElse: () => throw Exception('Not authenticated'),
          );

      final intId = int.parse(userId);
      await repository.updateProfile(
        userId: intId,
        username: _usernameController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        about: _aboutController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save changes: ${e.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  void initState() {
    super.initState();

    final profile = ref.read(profileProvider).profile;

    _usernameController = TextEditingController(
      text: profile?.attributes.username ?? '',
    );
    _firstNameController = TextEditingController(
      text: profile?.attributes.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: profile?.attributes.lastName ?? '',
    );
    _aboutController = TextEditingController(
      text: profile?.attributes.about ?? '',
    );

    _usernameController.addListener(_onUsernameChanged);
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _aboutController.addListener(_onFieldChanged);

    _usernameFocusNode.addListener(() {
      setState(() {
        _isUsernameFocused = _usernameFocusNode.hasFocus;
      });
    });

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .distinct()
        .listen((List<ConnectivityResult> result) {
      setState(() {
        _isOnline = result.isNotEmpty &&
            result.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _aboutController.dispose();
    _usernameFocusNode.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _aboutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).profile;

    if (profile == null) {
      return const SizedBox.shrink();
    }

    return PopScope<bool>(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, bool? result) async {
        if (didPop) {
          return;
        }

        if (!_hasUnsavedChanges) {
          Navigator.pop(context, true);
          return;
        }

        final bool shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard changes?'),
                content: const Text(
                    'You have unsaved changes. Are you sure you want to discard them?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ??
            false;

        if (context.mounted && shouldPop) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit Profile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    if (!_hasUnsavedChanges) {
                      Navigator.pop(context);
                      return;
                    }
                    final shouldPop = await _onWillPop();
                    if (shouldPop && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Form(
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    enabled: _isOnline,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _usernameError,
                      helperText: !_isOnline
                          ? 'Internet connection required to change username'
                          : _usernameError == null && _isUsernameFocused
                              ? 'Your unique username'
                              : null,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _usernameError =
                            ProfileValidator.validateUsername(value);
                      });
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    focusNode: _firstNameFocusNode,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      errorText: _firstNameError,
                      helperText: 'Optional',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _firstNameError =
                            ProfileValidator.validateName(value, 'First name');
                      });
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    focusNode: _lastNameFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      errorText: _lastNameError,
                      helperText: 'Optional',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _lastNameError =
                            ProfileValidator.validateName(value, 'Last name');
                      });
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _aboutController,
                    focusNode: _aboutFocusNode,
                    maxLines: 3,
                    maxLength: ProfileValidator.maxAboutLength,
                    decoration: InputDecoration(
                      labelText: 'About',
                      errorText: _aboutError,
                      helperText: 'Optional - Tell us about yourself',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _aboutError = ProfileValidator.validateAbout(value);
                      });
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed:
                        _hasUnsavedChanges && !_isSaving ? _saveChanges : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
