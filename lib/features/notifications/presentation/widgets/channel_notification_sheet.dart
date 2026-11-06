import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/notifications/domain/entities/channel_notification_preference.dart';
import 'package:zedu/features/notifications/presentation/providers/channel_notification_provider.dart';

/// Opens the per-channel notification picker for [channelName].
///
/// The picker applies each choice immediately; there is no Save button, so
/// closing it can never lose a selection.
Future<void> showChannelNotificationSheet(
  BuildContext context, {
  required String channelId,
  required String channelName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChannelNotificationSheet(
      channelId: channelId,
      channelName: channelName,
    ),
  );
}

/// Lets a person pick how this one channel notifies them.
///
/// "Use workspace default" is listed first and is the state every channel
/// starts in, so it is always clear which channels are overridden and which
/// simply follow the workspace setting.
class ChannelNotificationSheet extends ConsumerWidget {
  const ChannelNotificationSheet({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(channelNotificationOverridesProvider);
    final current = preferences.levelFor(channelId);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Notifications for #$channelName'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose when Zedu should notify you about this channel. '
                'Every other channel keeps its own setting.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final level in ChannelNotificationLevel.values)
                ListTile(
                  key: ValueKey('channel-notification-${level.name}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    current == level
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(level.label),
                  subtitle: Text(level.description),
                  onTap: () => unawaited(
                    ref
                        .read(channelNotificationOverridesProvider.notifier)
                        .setLevel(channelId, level),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
