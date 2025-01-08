import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ベントブック';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get appearance => '外観';

  @override
  String get themeMode => 'テーマモード';

  @override
  String get colorScheme => 'カラースキーム';

  @override
  String get personalInformation => '個人情報';

  @override
  String get username => 'ユーザー名';

  @override
  String get firstName => '名';

  @override
  String get lastName => '姓';

  @override
  String get email => 'メールアドレス';

  @override
  String get about => '自己紹介';

  @override
  String get preferences => '設定';

  @override
  String get language => '言語';

  @override
  String get notSet => '未設定';

  @override
  String get loading => '読み込み中...';

  @override
  String errorLoading(String field) {
    return '$fieldの読み込みエラー';
  }

  @override
  String get logout => 'ログアウト';

  @override
  String get logoutConfirmation => 'ログアウトしてもよろしいですか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get edit => '編集';
}
