import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'dart:developer' as dev;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ref.read(authServiceProvider);
      final email = authState.maybeMap(
        authenticated: (state) => state.user.attributes.email,
        orElse: () => null,
      );

      if (email != null) {
        final userRepository = ref.read(userRepositoryProvider);
        final user = await userRepository.getUserByEmail(email);
        setState(() {
          _userData = user;
        });
      }
    } catch (e) {
      dev.log('ProfileScreen: Error loading user data', error: e);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load profile: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfileItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not set',
              style: TextStyle(
                fontSize: 15,
                color: value != null 
                  ? CupertinoColors.label 
                  : CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profile'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            dev.log('Profile: Going back to dashboard');
            ref.read(navigationProvider.notifier).startTransition('/dashboard');
          },
          child: const Icon(CupertinoIcons.back),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadUserData,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _userData == null
            ? const Center(child: Text('No profile data available'))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: Text(
                              (_userData!.displayName ?? _userData!.username ?? _userData!.email)
                                .substring(0, 1)
                                .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _userData!.displayName ?? _userData!.username ?? _userData!.email,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileItem('Email', _userData!.email),
                      _buildProfileItem('Username', _userData!.username),
                      _buildProfileItem('Display Name', _userData!.displayName),
                      _buildProfileItem('First Name', _userData!.firstName),
                      _buildProfileItem('Last Name', _userData!.lastName),
                      _buildProfileItem('About', _userData!.about),
                      _buildProfileItem('Theme', _userData!.preferredTheme),
                      _buildProfileItem('Language', _userData!.preferredLanguage),
                      const SizedBox(height: 24),
                      if (_userData!.avatarUrls != null) ...[
                        const Text(
                          'Avatar URLs',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (var entry in _userData!.avatarUrls!.entries)
                          _buildProfileItem(entry.key, entry.value),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}