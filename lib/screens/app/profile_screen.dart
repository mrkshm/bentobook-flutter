import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:bentobook/screens/app/widgets/profile_edit_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final authState = ref.watch(authServiceProvider);
    final user = authState.maybeMap(
      authenticated: (state) => state.user,
      orElse: () => null,
    );

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/dashboard', extra: true),
        ),
      ),
      body: ListView(
        children: [
          // Theme Settings Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Appearance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Theme Mode'),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        ref
                            .read(themeProvider.notifier)
                            .setTheme(selection.first);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Color Scheme'),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.palette_outlined,
                          color: theme.colorScheme.primary),
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) => AppTheme.schemes.entries
                          .map(
                            (scheme) => PopupMenuItem(
                              value: scheme.key,
                              child: Text(scheme.key),
                            ),
                          )
                          .toList(),
                      onSelected: (String schemeName) {
                        ref
                            .read(colorSchemeProvider.notifier)
                            .setSchemeByName(schemeName);
                      },
                    ),
                    subtitle: Text(
                      AppTheme.schemeToString(colorScheme),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User Info Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'User Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, 
                            color: theme.colorScheme.primary),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              useRootNavigator: true,
                              isScrollControlled: true,
                              builder: (context) => const ProfileEditSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text('Email'),
                    subtitle: Text(user.attributes.email),
                  ),
                  if (user.attributes.username?.isNotEmpty ?? false)
                    ListTile(
                      title: const Text('Username'),
                      subtitle: Text(user.attributes.username!),
                    ),
                  if (user.attributes.firstName?.isNotEmpty ?? false)
                    ListTile(
                      title: const Text('First Name'),
                      subtitle: Text(user.attributes.firstName!),
                    ),
                  if (user.attributes.lastName?.isNotEmpty ?? false)
                    ListTile(
                      title: const Text('Last Name'),
                      subtitle: Text(user.attributes.lastName!),
                    ),
                ],
              ),
            ),
          ),

          // Additional Info Card
          if (user.attributes.profile?.about?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'About',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        user.attributes.profile!.about!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Preferences Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Preferences',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (user.attributes.profile?.preferredLanguage != null)
                    ListTile(
                      title: const Text('Language'),
                      subtitle:
                          Text(user.attributes.profile!.preferredLanguage!),
                    ),
                ],
              ),
            ),
          ),

          // Logout Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                title: Text(
                  'Logout',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref.read(authServiceProvider.notifier).logout();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
