import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

/// A member row exactly as `/organisations/{orgId}/users` sends it.
Map<String, dynamic> _orgUser({
  String id = 'user-1',
  String email = 'member@zedu.chat',
  String? status,
  Object? isActive,
  String? name,
  String? username,
  String created = '2026-02-04T10:15:00Z',
}) {
  return {
    'id': id,
    'email': email,
    'role': 'Manager',
    'created_at': created,
    'status': status,
    'is_active': isActive,
    'name': name,
    'username': username,
    'avatar_url': 'https://cdn.example/avatar.png',
  };
}

void main() {
  group('TeamMemberModel.parseStatus', () {
    test('reads pending from every spelling the API uses', () {
      for (final value in <String>[
        'pending',
        'Pending',
        'PENDING',
        ' invited ',
        'awaiting',
        'awaiting_acceptance',
      ]) {
        expect(
          TeamMemberModel.parseStatus(value),
          TeamMemberStatus.pending,
          reason: 'expected "$value" to be pending',
        );
      }
    });

    test('reads inactive from every spelling the API uses', () {
      for (final value in <String>[
        'inactive',
        'Inactive',
        'deactivated',
        'disabled',
        'suspended',
        'removed',
      ]) {
        expect(
          TeamMemberModel.parseStatus(value),
          TeamMemberStatus.inactive,
          reason: 'expected "$value" to be inactive',
        );
      }
    });

    test('falls back to active only when nothing says otherwise', () {
      expect(TeamMemberModel.parseStatus(null), TeamMemberStatus.active);
      expect(TeamMemberModel.parseStatus(''), TeamMemberStatus.active);
      expect(TeamMemberModel.parseStatus('active'), TeamMemberStatus.active);
      expect(TeamMemberModel.parseStatus('member'), TeamMemberStatus.active);
      expect(TeamMemberModel.parseStatus(42), TeamMemberStatus.active);
    });

    test('an explicit is_active false wins over any status string', () {
      expect(
        TeamMemberModel.parseStatus('active', active: false),
        TeamMemberStatus.inactive,
      );
      expect(
        TeamMemberModel.parseStatus('pending', active: false),
        TeamMemberStatus.inactive,
      );
      expect(
        TeamMemberModel.parseStatus('pending', active: true),
        TeamMemberStatus.pending,
      );
    });
  });

  group('TeamMemberModel.fromOrganisationUser', () {
    test('carries the status the endpoint reports instead of active', () {
      final member = TeamMemberModel.fromOrganisationUser(
        _orgUser(status: 'pending'),
      );

      expect(member.status, TeamMemberStatus.pending);
      expect(member.id, 'user-1');
      expect(member.email, 'member@zedu.chat');
      expect(member.role, 'Manager');
    });

    test('maps created_at to dateJoined', () {
      final member = TeamMemberModel.fromOrganisationUser(
        _orgUser(status: 'active'),
      );

      expect(member.dateJoined, '2026-02-04T10:15:00Z');
      expect(member.avatarUrl, 'https://cdn.example/avatar.png');
    });

    test('shows a deactivated member as inactive from is_active alone', () {
      final member = TeamMemberModel.fromOrganisationUser(
        _orgUser(status: 'active', isActive: false),
      );

      expect(member.status, TeamMemberStatus.inactive);
    });

    test('falls back from name to username to Unknown', () {
      expect(
        TeamMemberModel.fromOrganisationUser(_orgUser(name: 'Ada')).name,
        'Ada',
      );
      expect(
        TeamMemberModel.fromOrganisationUser(
          _orgUser(username: 'ada.l'),
        ).name,
        'ada.l',
      );
      expect(
        TeamMemberModel.fromOrganisationUser(_orgUser()).name,
        'Unknown',
      );
    });

    test('does not invent values the endpoint did not send', () {
      final member = TeamMemberModel.fromOrganisationUser(const {});

      expect(member.id, isEmpty);
      expect(member.email, isEmpty);
      expect(member.dateJoined, isEmpty);
      expect(member.role, 'User');
      expect(member.avatarUrl, isNull);
    });
  });

  group('TeamMemberModel.fromJson', () {
    test('keeps date_joined when present', () {
      final member = TeamMemberModel.fromJson(const {
        'id': 'member-2',
        'email': 'invitee@zedu.chat',
        'role': 'Manager',
        'date_joined': 'Pending',
        'status': 'pending',
      });

      expect(member.dateJoined, 'Pending');
      expect(member.status, TeamMemberStatus.pending);
    });

    test('accepts created_at when date_joined is absent', () {
      final member = TeamMemberModel.fromJson(const {
        'id': 'member-3',
        'created_at': '2026-03-01T00:00:00Z',
        'status': 'inactive',
      });

      expect(member.dateJoined, '2026-03-01T00:00:00Z');
      expect(member.status, TeamMemberStatus.inactive);
    });

    test('no longer reads a capitalised Pending as active', () {
      final member = TeamMemberModel.fromJson(const {
        'id': 'member-4',
        'status': 'Pending',
      });

      expect(member.status, TeamMemberStatus.pending);
    });
  });

  group('roster to Invites', () {
    // The Invites tab is `members.where(status == pending)`, so the mapping is
    // what decides whether that tab can ever show anything.
    test('pending rows reach the invites list and others do not', () {
      final members = [
        TeamMemberModel.fromOrganisationUser(_orgUser(id: 'u-1')),
        TeamMemberModel.fromOrganisationUser(
          _orgUser(id: 'u-2', email: 'invitee@zedu.chat', status: 'pending'),
        ),
        TeamMemberModel.fromOrganisationUser(
          _orgUser(id: 'u-3', email: 'gone@zedu.chat', isActive: false),
        ),
      ];

      final invites = members
          .where((m) => m.status == TeamMemberStatus.pending)
          .toList();
      final active = members
          .where((m) => m.status == TeamMemberStatus.active)
          .toList();

      expect(invites.map((m) => m.id), ['u-2']);
      expect(active.map((m) => m.id), ['u-1']);
    });

    test('a roster of pending rows is no longer reported as all active', () {
      final members = List.generate(
        3,
        (i) => TeamMemberModel.fromOrganisationUser(
          _orgUser(id: 'u-$i', email: 'invitee$i@zedu.chat', status: 'Pending'),
        ),
      );

      expect(
        members.where((m) => m.status == TeamMemberStatus.active),
        isEmpty,
      );
      expect(
        members.where((m) => m.status == TeamMemberStatus.pending).length,
        3,
      );
    });
  });
}
