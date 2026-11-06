import 'package:zedu/features/user_profile/domain/entities/notification_preferences.dart';

/// What push notifications do for one channel.
///
/// A channel starts at [workspaceDefault], which means "follow the workspace
/// setting". Every other value is an override that applies to this channel
/// only, so muting one noisy channel no longer means muting all of them.
enum ChannelNotificationLevel {
  workspaceDefault,
  allMessages,
  mentionsOnly,
  muted;

  /// Whether this channel is pinned to its own rule rather than inheriting.
  bool get isOverride => this != ChannelNotificationLevel.workspaceDefault;

  /// Whether the channel is silenced outright.
  bool get silences => this == ChannelNotificationLevel.muted;

  String get label => switch (this) {
    ChannelNotificationLevel.workspaceDefault => 'Use workspace default',
    ChannelNotificationLevel.allMessages => 'All messages',
    ChannelNotificationLevel.mentionsOnly => 'Mentions only',
    ChannelNotificationLevel.muted => 'Muted',
  };

  String get description => switch (this) {
    ChannelNotificationLevel.workspaceDefault =>
      'Follow the workspace notification setting.',
    ChannelNotificationLevel.allMessages =>
      'Notify for every message in this channel.',
    ChannelNotificationLevel.mentionsOnly =>
      'Notify only when someone mentions you here.',
    ChannelNotificationLevel.muted => 'Never notify for this channel.',
  };

  /// The stored level named [value], or [workspaceDefault] for anything
  /// unrecognised.
  ///
  /// Falling back to the inherited level rather than to [muted] matters: a
  /// value written by a newer build must never silence a channel by accident.
  static ChannelNotificationLevel parse(Object? value) {
    if (value is ChannelNotificationLevel) return value;
    final raw = value is String ? value.trim() : '';
    for (final level in ChannelNotificationLevel.values) {
      if (level.name == raw) return level;
    }
    return ChannelNotificationLevel.workspaceDefault;
  }
}

/// The answer to "should this message raise a desktop notification?".
enum ChannelNotificationDecision {
  /// Show it.
  show,

  /// The channel is muted.
  muted,

  /// The channel is mentions-only and this message has no mention.
  mentionsOnly,

  /// The workspace default already turns notifications off.
  workspaceOff,

  /// The workspace is inside its quiet hours.
  quietHours;

  bool get shows => this == ChannelNotificationDecision.show;
}

/// Combines the workspace default, the channel override, mention state and
/// quiet hours into one decision.
///
/// This is the single place the precedence lives, so the push path, the
/// sidebar and anything added later cannot disagree about what a level means:
///
/// 1. a muted channel shows nothing, whatever the workspace says;
/// 2. a workspace default of [NotificationMode.none] shows nothing;
/// 3. quiet hours silence everything that would otherwise show;
/// 4. mentions-only suppresses messages that do not mention the reader;
/// 5. anything else shows, exactly as it did before overrides existed.
ChannelNotificationDecision resolveChannelNotificationDecision({
  required NotificationMode workspaceDefault,
  required ChannelNotificationLevel level,
  required bool isMention,
  bool quietHoursActive = false,
}) {
  if (level == ChannelNotificationLevel.muted) {
    return ChannelNotificationDecision.muted;
  }

  final effective = switch (level) {
    ChannelNotificationLevel.workspaceDefault => workspaceDefault,
    ChannelNotificationLevel.allMessages => NotificationMode.allMessages,
    ChannelNotificationLevel.mentionsOnly => NotificationMode.mentionsOnly,
    ChannelNotificationLevel.muted => NotificationMode.none,
  };

  if (effective == NotificationMode.none) {
    return level == ChannelNotificationLevel.workspaceDefault
        ? ChannelNotificationDecision.workspaceOff
        : ChannelNotificationDecision.muted;
  }

  if (quietHoursActive) return ChannelNotificationDecision.quietHours;

  if (effective == NotificationMode.mentionsOnly && !isMention) {
    return ChannelNotificationDecision.mentionsOnly;
  }

  return ChannelNotificationDecision.show;
}

/// Every channel's notification level for one signed-in user.
///
/// Immutable: [withLevel] and [withoutOverride] return new values, so a
/// provider can replace the whole object and Flutter rebuilds on identity.
class ChannelNotificationPreferences {
  const ChannelNotificationPreferences({
    this.byChannel = const <String, ChannelNotificationLevel>{},
  });

  /// Only channels that carry an override; everything absent inherits.
  final Map<String, ChannelNotificationLevel> byChannel;

  static const empty = ChannelNotificationPreferences();

  bool get isEmpty => byChannel.isEmpty;

  int get overrideCount => byChannel.length;

  /// The level for [channelId]: its override, else [workspaceDefault].
  ChannelNotificationLevel levelFor(String channelId) {
    if (channelId.isEmpty) return ChannelNotificationLevel.workspaceDefault;
    return byChannel[channelId] ?? ChannelNotificationLevel.workspaceDefault;
  }

  bool isMuted(String channelId) =>
      levelFor(channelId) == ChannelNotificationLevel.muted;

  bool hasOverride(String channelId) => byChannel.containsKey(channelId);

  /// A copy where [channelId] uses [level].
  ///
  /// Choosing [workspaceDefault] removes the override instead of storing it,
  /// so "reset" and "never set" are the same state and the stored map stays
  /// small.
  ChannelNotificationPreferences withLevel(
    String channelId,
    ChannelNotificationLevel level,
  ) {
    if (channelId.isEmpty) return this;
    final next = Map<String, ChannelNotificationLevel>.from(byChannel);
    if (level == ChannelNotificationLevel.workspaceDefault) {
      next.remove(channelId);
    } else {
      next[channelId] = level;
    }
    return ChannelNotificationPreferences(
      byChannel: Map<String, ChannelNotificationLevel>.unmodifiable(next),
    );
  }

  /// A copy where [channelId] inherits the workspace default again.
  ChannelNotificationPreferences withoutOverride(String channelId) =>
      withLevel(channelId, ChannelNotificationLevel.workspaceDefault);

  /// The stored form: `{channelId: levelName}`, only overrides.
  Map<String, dynamic> toJson() => {
    for (final entry in byChannel.entries) entry.key: entry.value.name,
  };

  /// Reads [toJson]'s shape, tolerating a missing, malformed or partial map.
  ///
  /// An unknown level name is dropped rather than guessed at, so a corrupt
  /// entry leaves that channel inheriting instead of silencing it.
  factory ChannelNotificationPreferences.fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) {
      return ChannelNotificationPreferences.empty;
    }
    final parsed = <String, ChannelNotificationLevel>{};
    for (final entry in json.entries) {
      final channelId = entry.key.toString();
      if (channelId.isEmpty) continue;
      final level = entry.value is ChannelNotificationLevel
          ? entry.value as ChannelNotificationLevel
          : _parseStored(entry.value);
      if (level == null) continue;
      parsed[channelId] = level;
    }
    return ChannelNotificationPreferences(
      byChannel: Map<String, ChannelNotificationLevel>.unmodifiable(parsed),
    );
  }

  /// Like [ChannelNotificationLevel.parse] but returns null for a value it
  /// does not recognise, so the caller can drop it.
  static ChannelNotificationLevel? _parseStored(Object? value) {
    final raw = value is String ? value.trim() : '';
    for (final level in ChannelNotificationLevel.values) {
      if (level.name == raw) return level;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChannelNotificationPreferences) return false;
    if (other.byChannel.length != byChannel.length) return false;
    for (final entry in byChannel.entries) {
      if (other.byChannel[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    byChannel.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'ChannelNotificationPreferences($byChannel)';
}

/// Whether [text] contains an `@username` mention of [username].
///
/// The character before the `@` must not be part of a word or an address, so
/// `mailto:x@name` and the `@name` inside `word@name` do not count, and the
/// match is case-insensitive because people type their teammates' handles
/// however they like.
bool textMentionsUsername(String text, String username) {
  final handle = username.trim();
  if (handle.isEmpty || text.isEmpty) return false;
  final pattern = RegExp(
    '(^|[^A-Za-z0-9_.])@${RegExp.escape(handle)}(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  return pattern.hasMatch(text);
}

/// Whether the payload mentions [userId] or [username].
///
/// Channels carry mentions in more than one shape depending on the endpoint:
/// an explicit list of ids or user objects, an `is_mention` flag, or nothing
/// but the message text. All three are read here so mentions-only behaves the
/// same however the message arrived.
bool messageMentionsUser(
  Map<String, dynamic> message, {
  required String userId,
  required String username,
}) {
  if (message['is_mention'] == true || message['isMention'] == true) {
    return true;
  }

  final Object? mentions =
      message['mentions'] ?? message['mentioned_users'] ?? message['mention_ids'];
  if (mentions is List<Object?>) {
    for (final Object? mention in mentions) {
      final Object? id = mention is Map<Object?, Object?>
          ? (mention['id'] ?? mention['user_id'] ?? mention['userId'])
          : mention;
      if (id != null && userId.isNotEmpty && id.toString() == userId) {
        return true;
      }
      final Object? name = mention is Map<Object?, Object?>
          ? (mention['username'] ?? mention['name'])
          : null;
      if (name != null && textMentionsUsername('@$name', username)) {
        return true;
      }
    }
  }

  final content =
      (message['content'] ?? message['text'] ?? message['body'] ?? '')
          .toString();
  return textMentionsUsername(content, username);
}
