import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/notifications/domain/entities/channel_notification_preference.dart';

/// Remembers each channel's notification level on this computer.
///
/// The backend has no per-channel notification field yet, so the levels live
/// in the app's existing [SecureStorageService] beside the DM mutes and the
/// channel drafts. They are keyed per signed-in user and organisation, so a
/// second account or workspace on the same machine starts from its own levels
/// instead of inheriting someone else's mutes.
class ChannelNotificationStore {
  const ChannelNotificationStore(
    this._storage, {
    required this.userId,
    required this.orgId,
  });

  final SecureStorageService _storage;
  final String userId;
  final String orgId;

  static const _tag = 'ChannelNotificationStore';

  /// The storage key for one user in one organisation.
  ///
  /// Public so the notifier can tell whether a restore still belongs to the
  /// scope that asked for it.
  static String key({required String userId, required String orgId}) =>
      'channel_notification_overrides_${userId}_$orgId';

  String get storageKey => key(userId: userId, orgId: orgId);

  /// The saved levels, or an empty set when nothing is stored.
  ///
  /// Every failure path returns the inherited defaults: a storage problem must
  /// never silence a channel.
  Future<ChannelNotificationPreferences> read() async {
    try {
      final raw = await _storage.readData(storageKey);
      if (raw == null || raw.isEmpty) {
        return ChannelNotificationPreferences.empty;
      }
      return ChannelNotificationPreferences.fromJson(jsonDecode(raw));
    } catch (error) {
      AppLogger.w(
        'Could not read channel notification overrides - $error',
        tag: _tag,
      );
      return ChannelNotificationPreferences.empty;
    }
  }

  /// Saves [preferences], deleting the key when there is nothing to store.
  Future<void> write(ChannelNotificationPreferences preferences) async {
    try {
      if (preferences.isEmpty) {
        await _storage.deleteValue(storageKey);
        return;
      }
      await _storage.writeData(
        storageKey,
        jsonEncode(preferences.toJson()),
      );
    } catch (error) {
      AppLogger.w(
        'Could not save channel notification overrides - $error',
        tag: _tag,
      );
    }
  }

  /// Forgets every override for this user in this organisation.
  Future<void> clear() async {
    try {
      await _storage.deleteValue(storageKey);
    } catch (error) {
      AppLogger.w(
        'Could not clear channel notification overrides - $error',
        tag: _tag,
      );
    }
  }
}
