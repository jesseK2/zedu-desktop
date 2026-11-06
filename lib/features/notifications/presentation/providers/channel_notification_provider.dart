import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/auth/auth.dart';
import 'package:zedu/features/notifications/data/datasources/channel_notification_store.dart';
import 'package:zedu/features/notifications/domain/entities/channel_notification_preference.dart';
import 'package:zedu/features/workspaces/workspaces.dart';

/// The signed-in user's per-channel notification levels.
///
/// Rebuilt when the user or the selected workspace changes, so the sidebar of
/// one workspace never shows another workspace's overrides. Changes are written
/// straight back to [ChannelNotificationStore]; when there is no secure storage
/// (widget tests, signed-out) the overrides still work in memory for the
/// lifetime of the session.
final channelNotificationOverridesProvider =
    NotifierProvider<
      ChannelNotificationOverridesNotifier,
      ChannelNotificationPreferences
    >(ChannelNotificationOverridesNotifier.new);

class ChannelNotificationOverridesNotifier
    extends Notifier<ChannelNotificationPreferences> {
  ChannelNotificationStore? _store;
  String? _scopeKey;

  @override
  ChannelNotificationPreferences build() {
    final String? userId = _signedInUserId(ref);
    final String orgId = _selectedOrganisationId(ref);

    // Signed out: no storage and no scope, so overrides last only for this
    // session. Signed in: keyed to the user and workspace being looked at.
    String? scopeKey;
    ChannelNotificationStore? store;
    if (userId != null && userId.isNotEmpty) {
      scopeKey = ChannelNotificationStore.key(userId: userId, orgId: orgId);
      store = _storeFor(userId: userId, orgId: orgId);
    }
    _scopeKey = scopeKey;
    _store = store;

    if (store != null && scopeKey != null) {
      unawaited(_restore(store, scopeKey));
    }
    return ChannelNotificationPreferences.empty;
  }

  /// Loads what was saved for this user, keeping anything changed while the
  /// read was in flight.
  Future<void> _restore(ChannelNotificationStore store, String scopeKey) async {
    final saved = await store.read();
    if (!ref.mounted || _scopeKey != scopeKey || saved.isEmpty) return;
    state = ChannelNotificationPreferences(
      byChannel: Map<String, ChannelNotificationLevel>.unmodifiable({
        ...saved.byChannel,
        ...state.byChannel,
      }),
    );
  }

  /// The level in force for [channelId], override or inherited.
  ChannelNotificationLevel levelFor(String channelId) =>
      state.levelFor(channelId);

  /// Sets [channelId] to [level] and remembers it.
  ///
  /// Choosing [ChannelNotificationLevel.workspaceDefault] clears the override,
  /// so the channel follows the workspace setting again.
  Future<void> setLevel(
    String channelId,
    ChannelNotificationLevel level,
  ) async {
    final next = state.withLevel(channelId, level);
    if (next == state) return;
    state = next;
    final ChannelNotificationStore? store = _store;
    if (store != null) await store.write(next);
  }

  /// Puts every channel back on the workspace default.
  Future<void> resetAll() async {
    if (state.isEmpty) return;
    state = ChannelNotificationPreferences.empty;
    final ChannelNotificationStore? store = _store;
    if (store != null) await store.clear();
  }
}

String? _signedInUserId(Ref ref) {
  try {
    return ref.watch(authNotifierProvider.select((s) => s.user?.id));
  } catch (_) {
    return null;
  }
}

String _selectedOrganisationId(Ref ref) {
  try {
    return ref.watch(workspaceProvider.select((s) => s.selectedWorkspace?.id)) ??
        '';
  } catch (_) {
    return '';
  }
}

ChannelNotificationStore? _storeFor({
  required String userId,
  required String orgId,
}) {
  if (!locator.isRegistered<SecureStorageService>()) return null;
  return ChannelNotificationStore(
    locator<SecureStorageService>(),
    userId: userId,
    orgId: orgId,
  );
}
