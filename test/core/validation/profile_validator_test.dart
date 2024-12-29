import 'package:flutter_test/flutter_test.dart';
import 'package:bentobook/core/validation/profile_validator.dart';

void main() {
  group('ProfileValidator.validateUsername', () {
    test('returns error when empty', () {
      expect(ProfileValidator.validateUsername(''), 'Username is required');
    });

    test('returns error when too short', () {
      expect(
        ProfileValidator.validateUsername('ab'),
        'Username must be at least ${ProfileValidator.minUsernameLength} characters',
      );
    });

    test('returns error when too long', () {
      expect(
        ProfileValidator.validateUsername('a' * 21),
        'Username must be less than ${ProfileValidator.maxUsernameLength} characters',
      );
    });

    test('returns error with invalid characters', () {
      expect(
        ProfileValidator.validateUsername('user@name'),
        'Username can only contain letters, numbers and underscores',
      );
      expect(
        ProfileValidator.validateUsername('user-name'),
        'Username can only contain letters, numbers and underscores',
      );
      expect(
        ProfileValidator.validateUsername('user name'),
        'Username can only contain letters, numbers and underscores',
      );
    });

    test('returns null for valid usernames', () {
      expect(ProfileValidator.validateUsername('user123'), null);
      expect(ProfileValidator.validateUsername('user_name'), null);
      expect(ProfileValidator.validateUsername('USERNAME'), null);
    });
  });

  group('ProfileValidator.validateName', () {
    test('returns null when empty', () {
      expect(ProfileValidator.validateName('', 'First name'), null);
      expect(ProfileValidator.validateName(null, 'First name'), null);
    });

    test('returns error when too long', () {
      expect(
        ProfileValidator.validateName('a' * 51, 'First name'),
        'First name must be less than ${ProfileValidator.maxNameLength} characters',
      );
    });

    test('returns error with invalid characters', () {
      expect(
        ProfileValidator.validateName('John123', 'First name'),
        'First name can only contain letters, spaces, hyphens, and apostrophes',
      );
      expect(
        ProfileValidator.validateName('John@Doe', 'First name'),
        'First name can only contain letters, spaces, hyphens, and apostrophes',
      );
    });

    test('returns null for valid names', () {
      expect(ProfileValidator.validateName('John', 'First name'), null);
      expect(ProfileValidator.validateName('Mary Jane', 'First name'), null);
      expect(ProfileValidator.validateName('O\'Connor', 'Last name'), null);
      expect(ProfileValidator.validateName('Jean-Pierre', 'First name'), null);
    });
  });

  group('ProfileValidator.validateAbout', () {
    test('returns null when empty', () {
      expect(ProfileValidator.validateAbout(''), null);
      expect(ProfileValidator.validateAbout(null), null);
    });

    test('returns error when too long', () {
      expect(
        ProfileValidator.validateAbout('a' * 501),
        'About must be less than ${ProfileValidator.maxAboutLength} characters',
      );
    });

    test('returns null for valid about text', () {
      expect(ProfileValidator.validateAbout('Hello, this is my bio!'), null);
      expect(
        ProfileValidator.validateAbout('a' * ProfileValidator.maxAboutLength),
        null,
      );
    });
  });
}
