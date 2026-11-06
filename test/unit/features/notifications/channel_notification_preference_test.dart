import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/notifications/domain/entities/channel_notification_preference.dart';
import 'package:zedu/features/user_profile/domain/entities/notification_preferences.dart';

void main() {
  group('ChannelNotificationLevel.parse', () {
    test('reads every stored level name', () {
      expect(
        ChannelNotificationLevel.parse('allMessages'),
        ChannelNotificationLevel.allMessages,
      );
      expect(
        ChannelNotificationLevel.parse('mentionsOnly'),
        ChannelNotificationLevel.mentionsOnly,
      );
      expect(
        ChannelNotificationLevel.parse('muted'),
        ChannelNotificationLevel.muted,
      );
      expect(
        ChannelNotificationLevel.parse('workspaceDefault'),
        ChannelNotificationLevel.workspaceDefault,
      );
    });

    test('falls back to the workspace default, never to muted', () {
      expect(
        ChannelNotificationLevel.parse(null),
        ChannelNotificationLevel.workspaceDefault,
      );
      expect(
        ChannelNotificationLevel.parse('MUTED'),
        ChannelNotificationLevel.workspaceDefault,
      );
      expect(
        ChannelNotificationLevel.parse(42),
        ChannelNotificationLevel.workspaceDefault,
      );
      expect(
        ChannelNotificationLevel.parse('silent'),
        ChannelNotificationLevel.workspaceDefault,
      );
    });

    test('passes an already parsed level through', () {
      expect(
        ChannelNotificationLevel.parse(ChannelNotificationLevel.muted),
        ChannelNotificationLevel.muted,
      );
    });
  });

  group('ChannelNotificationPreferences', () {
    test('a channel with no override inherits the workspace default', () {
      const preferences = ChannelNotificationPreferences();
      expect(preferences.isEmpty, isTrue);
      expect(
        preferences.levelFor('channel-1'),
        ChannelNotificationLevel.workspaceDefault,
      );
      expect(preferences.isMuted('channel-1'), isFalse);
      expect(preferences.hasOverride('channel-1'), isFalse);
    });

    test('withLevel stores an override and leaves the old value untouched', () {
      const original = ChannelNotificationPreferences();
      final updated = original.withLevel(
        'channel-1',
        ChannelNotificationLevel.muted,
      );
      expect(original.isEmpty, isTrue);
      expect(updated.levelFor('channel-1'), ChannelNotificationLevel.muted);
      expect(updated.isMuted('channel-1'), isTrue);
      expect(updated.overrideCount, 1);
    });

    test('choosing the workspace default removes the override', () {
      final updated = ChannelNotificationPreferences.empty
          .withLevel('channel-1', ChannelNotificationLevel.mentionsOnly)
          .withoutOverride('channel-1');
      expect(updated.isEmpty, isTrue);
      expect(updated.hasOverride('channel-1'), isFalse);
    });

    test('an empty channel id is ignored', () {
      final updated = ChannelNotificationPreferences.empty.withLevel(
        '',
        ChannelNotificationLevel.muted,
      );
      expect(identical(updated, ChannelNotificationPreferences.empty), isTrue);
    });

    test('toJson keeps only overrides and round-trips', () {
      final preferences = ChannelNotificationPreferences.empty
          .withLevel('a', ChannelNotificationLevel.muted)
          .withLevel('b', ChannelNotificationLevel.mentionsOnly);

      expect(preferences.toJson(), {
        'a': 'muted',
        'b': 'mentionsOnly',
      });

      final restored = ChannelNotificationPreferences.fromJson(
        preferences.toJson(),
      );
      expect(restored, preferences);
      expect(restored.levelFor('a'), ChannelNotificationLevel.muted);
      expect(restored.levelFor('b'), ChannelNotificationLevel.mentionsOnly);
    });

    test('fromJson tolerates missing, foreign and corrupt values', () {
      expect(
        ChannelNotificationPreferences.fromJson(null).isEmpty,
        isTrue,
      );
      expect(
        ChannelNotificationPreferences.fromJson('nonsense').isEmpty,
        isTrue,
      );

      final partial = ChannelNotificationPreferences.fromJson({
        'good': 'muted',
        'bad': 'on',
        '': 'muted',
        7: 'muted',
      });
      expect(partial.overrideCount, 1);
      expect(partial.levelFor('good'), ChannelNotificationLevel.muted);
      expect(
        partial.levelFor('bad'),
        ChannelNotificationLevel.workspaceDefault,
      );
    });

    test('equality ignores ordering but not the values', () {
      final first = ChannelNotificationPreferences.empty
          .withLevel('a', ChannelNotificationLevel.muted)
          .withLevel('b', ChannelNotificationLevel.allMessages);
      final second = ChannelNotificationPreferences.empty
          .withLevel('b', ChannelNotificationLevel.allMessages)
          .withLevel('a', ChannelNotificationLevel.muted);
      final third = ChannelNotificationPreferences.empty
          .withLevel('a', ChannelNotificationLevel.mentionsOnly)
          .withLevel('b', ChannelNotificationLevel.allMessages);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first == third, isFalse);
    });
  });

  group('resolveChannelNotificationDecision', () {
    ChannelNotificationDecision resolve({
      NotificationMode workspaceDefault = NotificationMode.allMessages,
      ChannelNotificationLevel level = ChannelNotificationLevel.workspaceDefault,
      bool isMention = false,
      bool quietHoursActive = false,
    }) {
      return resolveChannelNotificationDecision(
        workspaceDefault: workspaceDefault,
        level: level,
        isMention: isMention,
        quietHoursActive: quietHoursActive,
      );
    }

    test('a channel on the workspace default behaves as before', () {
      expect(resolve().shows, isTrue);
      expect(
        resolve(workspaceDefault: NotificationMode.mentionsOnly).shows,
        isFalse,
      );
      expect(
        resolve(workspaceDefault: NotificationMode.mentionsOnly, isMention: true)
            .shows,
        isTrue,
      );
      expect(
        resolve(workspaceDefault: NotificationMode.none),
        ChannelNotificationDecision.workspaceOff,
      );
    });

    test('muting one channel beats everything else', () {
      expect(
        resolve(level: ChannelNotificationLevel.muted, isMention: true),
        ChannelNotificationDecision.muted,
      );
      expect(
        resolve(
          level: ChannelNotificationLevel.muted,
          workspaceDefault: NotificationMode.none,
        ),
        ChannelNotificationDecision.muted,
      );
      expect(
        resolve(
          level: ChannelNotificationLevel.muted,
          quietHoursActive: true,
        ),
        ChannelNotificationDecision.muted,
      );
    });

    test('an all-messages override lifts a quiet workspace default', () {
      expect(
        resolve(
          level: ChannelNotificationLevel.allMessages,
          workspaceDefault: NotificationMode.none,
        ).shows,
        isTrue,
      );
      expect(
        resolve(
          level: ChannelNotificationLevel.allMessages,
          workspaceDefault: NotificationMode.mentionsOnly,
        ).shows,
        isTrue,
      );
    });

    test('mentions-only suppresses messages without a mention', () {
      expect(
        resolve(level: ChannelNotificationLevel.mentionsOnly),
        ChannelNotificationDecision.mentionsOnly,
      );
      expect(
        resolve(level: ChannelNotificationLevel.mentionsOnly, isMention: true)
            .shows,
        isTrue,
      );
    });

    test('quiet hours silence anything that would otherwise show', () {
      expect(
        resolve(quietHoursActive: true),
        ChannelNotificationDecision.quietHours,
      );
      expect(
        resolve(
          level: ChannelNotificationLevel.allMessages,
          quietHoursActive: true,
        ),
        ChannelNotificationDecision.quietHours,
      );
    });
  });

  group('textMentionsUsername', () {
    test('matches a handle anywhere in the text', () {
      expect(textMentionsUsername('hey @joy can you look?', 'joy'), isTrue);
      expect(textMentionsUsername('@joy', 'joy'), isTrue);
      expect(textMentionsUsername('ping (@joy).', 'joy'), isTrue);
    });

    test('is case-insensitive', () {
      expect(textMentionsUsername('@Joy hi', 'joy'), isTrue);
      expect(textMentionsUsername('@JOY hi', 'joy'), isTrue);
    });

    test('does not match a longer handle or an email address', () {
      expect(textMentionsUsername('@joyn hi', 'joy'), isFalse);
      expect(textMentionsUsername('@joy_2 hi', 'joy'), isFalse);
      expect(textMentionsUsername('mailto:someone@joy.dev', 'joy'), isFalse);
    });

    test('an empty username never matches', () {
      expect(textMentionsUsername('@joy hi', ''), isFalse);
      expect(textMentionsUsername('@joy hi', '   '), isFalse);
      expect(textMentionsUsername('', 'joy'), isFalse);
    });
  });

  group('messageMentionsUser', () {
    test('reads a mention from the message text', () {
      expect(
        messageMentionsUser(
          <String, dynamic>{'content': 'hi @joy'},
          userId: 'user-1',
          username: 'joy',
        ),
        isTrue,
      );
      expect(
        messageMentionsUser(
          <String, dynamic>{'content': 'hi there'},
          userId: 'user-1',
          username: 'joy',
        ),
        isFalse,
      );
    });

    test('reads a mention from an id list', () {
      expect(
        messageMentionsUser(
          <String, dynamic>{
            'content': 'no handle here',
            'mentions': <dynamic>['user-1'],
          },
          userId: 'user-1',
          username: 'joy',
        ),
        isTrue,
      );
      expect(
        messageMentionsUser(
          <String, dynamic>{
            'content': 'no handle here',
            'mentioned_users': <dynamic>[
              <String, dynamic>{'id': 'user-2', 'username': 'someone'},
            ],
          },
          userId: 'user-1',
          username: 'joy',
        ),
        isFalse,
      );
    });

    test('reads a mention from a user object list', () {
      expect(
        messageMentionsUser(
          <String, dynamic>{
            'mentions': <dynamic>[
              <String, dynamic>{'id': 'user-2', 'username': 'joy'},
            ],
          },
          userId: 'user-1',
          username: 'joy',
        ),
        isTrue,
      );
    });

    test('honours an explicit mention flag', () {
      expect(
        messageMentionsUser(
          <String, dynamic>{'content': 'look', 'is_mention': true},
          userId: 'user-1',
          username: 'joy',
        ),
        isTrue,
      );
    });

    test('a message with no content or mentions is not a mention', () {
      expect(
        messageMentionsUser(
          <String, dynamic>{},
          userId: 'user-1',
          username: 'joy',
        ),
        isFalse,
      );
    });
  });
}
