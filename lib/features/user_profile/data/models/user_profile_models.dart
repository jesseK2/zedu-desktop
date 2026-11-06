import 'package:zedu/features/features.dart';

class ProfileAccountModel extends ProfileAccount {
  const ProfileAccountModel({
    required super.name,
    required super.email,
    required super.timezone,
    super.avatarUrl,
    super.displayName,
    super.username,
    super.phoneNumber,
    super.title,
    super.namePronunciation,
    super.country,
  });

  factory ProfileAccountModel.fromAccount(ProfileAccount account) {
    return ProfileAccountModel(
      name: account.name,
      email: account.email,
      timezone: account.timezone,
      avatarUrl: account.avatarUrl,
      displayName: account.displayName,
      username: account.username,
      phoneNumber: account.phoneNumber,
      title: account.title,
      namePronunciation: account.namePronunciation,
      country: account.country,
    );
  }

  factory ProfileAccountModel.fromJson(Map<String, dynamic> json) {
    return ProfileAccountModel(
      name:
          json['full_name'] as String? ??
          json['name'] as String? ??
          'Anonymous user',
      email: json['email'] as String? ?? 'anonymoususer@email.com',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      avatarUrl: json['avatar_url'] as String?,
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      phoneNumber:
          json['phone'] as String? ?? json['phone_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      namePronunciation:
          json['name_pronounciation'] as String? ??
          json['name_pronunciation'] as String? ??
          '',
      country: json['country'] as String? ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'timezone': timezone,
    'avatar_url': avatarUrl,
    'display_name': displayName,
    'username': username,
    'phone_number': phoneNumber,
    'title': title,
    'name_pronunciation': namePronunciation,
    'country': country,
  };
}

/// Maps the per-device organisation preferences
/// (`/organisations/{id}/notification-preference`) to the settings screen.
///
/// The backend stores `time_range` as the window in which notifications are
/// delivered, inclusive at both ends. Quiet hours are the rest of the day, so
/// "pause from 10:00 PM, resume at 7:00 AM" is stored as
/// `7:00 AM - 9:59 PM`.
class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.mode,
    required super.quietHoursEnabled,
    required super.pauseFrom,
    required super.resumeAt,
    required super.emailNotifications,
    required super.differentMobileSettings,
    super.timezone,
  });

  /// [mobile] is the mobile device's preferences. Mobile counts as having its
  /// own settings when they differ from the desktop's.
  factory NotificationPreferencesModel.fromDeviceJson(
    Map<String, dynamic> desktop, {
    Map<String, dynamic>? mobile,
    String? timezone,
  }) {
    final window = _parseWindow(desktop['time_range'] as String?);
    final quietHours = window == null ? null : _quietHoursFor(window);
    return NotificationPreferencesModel(
      mode: _modeFromJson(desktop['notify_about'] as String?),
      quietHoursEnabled: quietHours != null,
      pauseFrom: quietHours?.$1 ?? NotificationPreferences.defaultPauseFrom,
      resumeAt: quietHours?.$2 ?? NotificationPreferences.defaultResumeAt,
      emailNotifications: desktop['send_mail'] as bool? ?? false,
      differentMobileSettings:
          mobile != null && !_sameDeviceSettings(desktop, mobile),
      timezone: (timezone?.isEmpty ?? true) ? null : timezone,
    );
  }

  NotificationPreferencesModel copyWithModel({bool? differentMobileSettings}) {
    return NotificationPreferencesModel(
      mode: mode,
      quietHoursEnabled: quietHoursEnabled,
      pauseFrom: pauseFrom,
      resumeAt: resumeAt,
      emailNotifications: emailNotifications,
      differentMobileSettings:
          differentMobileSettings ?? this.differentMobileSettings,
      timezone: timezone,
    );
  }

  /// Delivery window used when quiet hours are off.
  static const allDay = '12:00 AM - 11:59 PM';

  static Map<String, dynamic> toDeviceJson(
    NotificationPreferences preferences, {
    required String deviceType,
  }) {
    return {
      'notify_about': _modeToJson(preferences.mode),
      'send_mail': preferences.emailNotifications,
      'time_range': _timeRangeFor(preferences),
      'device_type': deviceType,
    };
  }

  static String _timeRangeFor(NotificationPreferences preferences) {
    if (!preferences.quietHoursEnabled) return allDay;
    final lastDelivered = preferences.pauseFrom - 1;
    return '${formatMinutesOfDay(preferences.resumeAt)} - '
        '${formatMinutesOfDay(lastDelivered)}';
  }

  static (int, int)? _parseWindow(String? value) {
    final parts = value?.split('-');
    if (parts == null || parts.length != 2) return null;
    final start = parseMinutesOfDay(parts[0]);
    final end = parseMinutesOfDay(parts[1]);
    if (start == null || end == null) return null;
    return (start, end);
  }

  /// Returns (pauseFrom, resumeAt), or null when the window covers the day.
  static (int, int)? _quietHoursFor((int, int) window) {
    final (start, end) = window;
    final pauseFrom = (end + 1) % NotificationPreferences.minutesPerDay;
    if (pauseFrom == start) return null;
    return (pauseFrom, start);
  }

  static bool _sameDeviceSettings(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return _modeFromJson(a['notify_about'] as String?) ==
            _modeFromJson(b['notify_about'] as String?) &&
        (a['send_mail'] as bool? ?? false) ==
            (b['send_mail'] as bool? ?? false) &&
        _effectiveWindow(a['time_range'] as String?) ==
            _effectiveWindow(b['time_range'] as String?);
  }

  /// Null stands for "all day", however it was written.
  static (int, int)? _effectiveWindow(String? value) {
    final window = _parseWindow(value);
    return window == null || _quietHoursFor(window) == null ? null : window;
  }

  static NotificationMode _modeFromJson(String? value) {
    return switch (value) {
      'mentions' || 'direct_messages_mentions' => NotificationMode.mentionsOnly,
      'nothing' => NotificationMode.none,
      _ => NotificationMode.allMessages,
    };
  }

  static String _modeToJson(NotificationMode mode) {
    return switch (mode) {
      NotificationMode.allMessages => 'all_new_messages',
      NotificationMode.mentionsOnly => 'mentions',
      NotificationMode.none => 'nothing',
    };
  }
}

class OrganizationProfileModel extends OrganizationProfile {
  const OrganizationProfileModel({
    required super.id,
    required super.name,
    required super.natureOfBusiness,
    required super.country,
  });

  factory OrganizationProfileModel.fromJson(Map<String, dynamic> json) {
    return OrganizationProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      natureOfBusiness:
          json['nature_of_business'] as String? ??
          json['type'] as String? ??
          '',
      country: json['country'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nature_of_business': natureOfBusiness,
    'country': country,
  };
}

class SecuritySessionModel extends SecuritySession {
  const SecuritySessionModel({
    required super.device,
    required super.location,
    required super.date,
    required super.lastActive,
    required super.status,
  });

  factory SecuritySessionModel.fromJson(Map<String, dynamic> json) {
    return SecuritySessionModel(
      device: json['device'] as String? ?? 'Chrome',
      location: json['location'] as String? ?? 'Lagos',
      date: json['date'] as String? ?? 'May 8, 2026 1:07 PM',
      lastActive: json['last_active'] as String? ?? 'May 8, 2026 3:07 PM',
      status: json['status'] as String? ?? 'Active',
    );
  }
}

class TeamMemberModel extends TeamMember {
  const TeamMemberModel({
    required super.id,
    required super.email,
    required super.role,
    required super.dateJoined,
    required super.status,
    super.name,
    super.avatarUrl,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] as String? ?? 'member-1',
      email: json['email'] as String? ?? 'anonymoususer@gmail.com',
      role: json['role'] as String? ?? 'Administrator',
      dateJoined:
          (json['date_joined'] ?? json['created_at']) as String? ??
          'May 3, 2026',
      status: parseStatus(json['status'], active: json['is_active']),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// A member row as `/organisations/{orgId}/users` returns it.
  ///
  /// That endpoint sends `created_at`, a `status` string and an optional
  /// `is_active` flag. Both are read here so the People grid and the Invites
  /// tab see the state the server actually reports instead of a constant.
  factory TeamMemberModel.fromOrganisationUser(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'User',
      dateJoined:
          (json['created_at'] ?? json['date_joined']) as String? ?? '',
      status: parseStatus(json['status'], active: json['is_active']),
      name:
          json['name'] as String? ??
          json['username'] as String? ??
          'Unknown',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// One status mapping for every payload that describes a member.
  ///
  /// The API is inconsistent about case and vocabulary, and the previous
  /// switch matched only `pending` and `inactive` exactly, so anything else
  /// (a capitalised `Pending`, an `invited`, a `deactivated`, an
  /// `is_active: false`) collapsed to `active`. That is what made every
  /// teammate read as online and left the Invites list always empty.
  /// Matching is case-insensitive and lives in a single place so the two
  /// member endpoints cannot drift apart.
  static TeamMemberStatus parseStatus(Object? value, {Object? active}) {
    if (active is bool && !active) return TeamMemberStatus.inactive;
    final raw = value is String ? value.trim().toLowerCase() : '';
    return switch (raw) {
      'pending' || 'invited' || 'awaiting' || 'awaiting_acceptance' =>
        TeamMemberStatus.pending,
      'inactive' || 'deactivated' || 'disabled' || 'suspended' || 'removed' =>
        TeamMemberStatus.inactive,
      _ => TeamMemberStatus.active,
    };
  }
}

class RolePermissionModel extends RolePermission {
  const RolePermissionModel({
    required super.role,
    required super.description,
    required super.permissions,
  });

  factory RolePermissionModel.fromJson(Map<String, dynamic> json) {
    return RolePermissionModel(
      role: json['role'] as String? ?? 'User',
      description: json['description'] as String? ?? '',
      permissions:
          (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

class BillingInfoModel extends BillingInfo {
  const BillingInfoModel({
    required super.plan,
    required super.description,
    super.paymentHistory,
  });

  factory BillingInfoModel.fromJson(Map<String, dynamic> json) {
    return BillingInfoModel(
      plan: json['plan'] as String? ?? 'Zedu Free',
      description: json['description'] as String? ?? '',
      paymentHistory:
          (json['payment_history'] as List<dynamic>?)
              ?.map(
                (e) => PaymentRecordModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class PaymentRecordModel extends PaymentRecord {
  const PaymentRecordModel({
    required super.id,
    required super.description,
    required super.amount,
    required super.date,
    required super.status,
  });

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json) {
    return PaymentRecordModel(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? 'Subscription Payment',
      amount: json['amount'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
