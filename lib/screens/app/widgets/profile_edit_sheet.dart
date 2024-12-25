import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/auth/auth_service.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  static const _minUsernameLength = 3;
  static const _maxUsernameLength = 20;
  Timer? _debounceTimer;
  String? _usernameError;
  bool _isUsernameFocused = false;
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  late TextEditingController _usernameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _aboutController;
  final _usernameFocusNode = FocusNode();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _aboutFocusNode = FocusNode();
  bool _hasUnsavedChanges = false;

  String? _validateUsername(String value) {
    if (value.isEmpty) return 'Username is required';
    if (value.length < _minUsernameLength) {
      return 'Username must be at least $_minUsernameLength characters';
    }
    if (value.length > _maxUsernameLength) {
      return 'Username must be less than $_maxUsernameLength characters';
    }
    if (!_usernameRegex.hasMatch(value)) {
      return 'Username can only contain letters, numbers and underscores';
    }
    return null;
  }

  void _onUsernameChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _usernameError = _validateUsername(_usernameController.text);
        });
        _onFieldChanged();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).maybeMap(
          authenticated: (state) => state.user,
          orElse: () => null,
        );

    _usernameController = TextEditingController(text: user?.attributes.username);
    _firstNameController = TextEditingController(text: user?.attributes.firstName);
    _lastNameController = TextEditingController(text: user?.attributes.lastName);
    _aboutController = TextEditingController(text: user?.attributes.profile?.about);

    // Add listeners
    _usernameController.addListener(_onUsernameChanged);
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _aboutController.addListener(_onFieldChanged);

    _usernameFocusNode.addListener(() {
      setState(() {
        _isUsernameFocused = _usernameFocusNode.hasFocus;
        if (!_usernameFocusNode.hasFocus) {
          _usernameError = _validateUsername(_usernameController.text);
        }
      });
    });
  }

  @override
  void dispose() {
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

  void _onFieldChanged() {
    final user = ref.read(authServiceProvider).maybeMap(
          authenticated: (state) => state.user,
          orElse: () => null,
        );
    
    if (user == null) return;

    final hasChanges = 
      (_usernameController.text != (user.attributes.username ?? '')) ||
      (_firstNameController.text != (user.attributes.firstName ?? '')) ||
      (_lastNameController.text != (user.attributes.lastName ?? '')) ||
      (_aboutController.text != (user.attributes.profile?.about ?? ''));

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authServiceProvider).maybeMap(
          authenticated: (state) => state.user,
          orElse: () => null,
        );

    if (user == null) {
      return const SizedBox.shrink();
    }

    final connectivityResult = Connectivity().checkConnectivity();
    final isOnline = (connectivityResult != ConnectivityResult.none);

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
            content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
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
        ) ?? false;

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
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _usernameError,
                      helperText: _usernameError == null 
                          ? 'Your unique username'
                          : null,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _usernameError = _validateUsername(value);
                      });
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    focusNode: _firstNameFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    focusNode: _lastNameFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _aboutController,
                    focusNode: _aboutFocusNode,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'About',
                      helperText: 'Tell us about yourself',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _hasUnsavedChanges
                        ? () {
                            // TODO: Implement save functionality
                          }
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}