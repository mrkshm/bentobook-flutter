import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/app/widgets/profile_edit_sheet.dart';
import 'package:bentobook/screens/app/widgets/language_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/l10n/locale_provider.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:bentobook/screens/app/widgets/avatar_picker_sheet.dart';
import 'package:bentobook/screens/app/widgets/profile_avatar.dart';
import 'package:page_transition/page_transition.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'fr':
        return 'Français';
      default:
        return languageCode;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canEdit = ref.watch(canEditAvatarProvider);
    final theme = Theme.of(context);
    final colorScheme = ref.watch(colorSchemeProvider);
    final authState = ref.watch(authServiceProvider);
    final profileState = ref.watch(profileProvider);
    final profileWithEmailAsync = ref.watch(profileWithEmailProvider);
    final currentTheme = ref.watch(themeProvider);
    final userId = authState.maybeMap(
      authenticated: (state) => state.userId,
      orElse: () => null,
    );

    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = profileState.profile;
    if (profileState.isLoading || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/app/dashboard');
            PageTransition(
              type: PageTransitionType.leftToRight,
              child: const DashboardScreen(),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Theme Selection
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                          l10n.appearance,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.themeMode),
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
                          selected: {currentTheme},
                          onSelectionChanged: (Set<ThemeMode> selection) {
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(selection.first);
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.colorScheme),
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
              // Profile Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Stack(
                            children: [
                              ProfileAvatar(
                                imagePath: profile.localThumbnailPath,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                              if (canEdit)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: IconButton.filledTonal(
                                    icon: const Icon(Icons.camera_alt),
                                    onPressed: () {
                                      AvatarPickerSheet.show(
                                        context,
                                        int.parse(userId),
                                        (String imagePath) async {
                                          try {
                                            await ref
                                                .read(profileProvider.notifier)
                                                .updateAvatar(
                                                  int.parse(userId),
                                                  File(imagePath),
                                                );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to update avatar: $e')),
                                              );
                                            }
                                          }
                                        },
                                        () async {
                                          // Handle delete avatar
                                          // TODO: Implement avatar deletion
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Avatar deletion coming soon!')),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.personalInformation,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useRootNavigator: true,
                                  builder: (context) =>
                                      const ProfileEditSheet(),
                                );
                              },
                              tooltip: l10n.edit,
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.username),
                        subtitle:
                            Text(profile.attributes.username ?? l10n.notSet),
                      ),
                      ListTile(
                        title: Text(l10n.firstName),
                        subtitle:
                            Text(profile.attributes.firstName ?? l10n.notSet),
                      ),
                      ListTile(
                        title: Text(l10n.lastName),
                        subtitle:
                            Text(profile.attributes.lastName ?? l10n.notSet),
                      ),
                      ListTile(
                        title: Text(l10n.email),
                        subtitle: profileWithEmailAsync.when(
                          data: (profileWithEmail) => Text(
                            profileWithEmail?.attributes.email.isNotEmpty ==
                                    true
                                ? profileWithEmail!.attributes.email
                                : l10n.notSet,
                          ),
                          loading: () => Text(l10n.loading),
                          error: (_, __) => Text(
                            l10n.errorLoading(l10n.email.toLowerCase()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // About Card
              if (profile.attributes.about?.isNotEmpty ?? false)
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
                            l10n.about,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            profile.attributes.about!,
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
                          l10n.preferences,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.language),
                        subtitle: Text(_getLanguageName(
                            ref.watch(localeProvider).languageCode)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useRootNavigator: true,
                            builder: (context) => const LanguageSelectorSheet(),
                          );
                        },
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
                      l10n.logout,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.logout),
                          content: Text(l10n.logoutConfirmation),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.logout),
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
        ),
      ),
    );
  }
}
