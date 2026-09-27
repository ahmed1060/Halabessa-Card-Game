import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/data/repositories/profile_update.dart';

void main() {
  test('first username writes only editable fields and normalizes search', () {
    final current = <String, dynamic>{'points': 120, 'friends': ['friend'], 'isAdmin': true};
    expect(profileUpdate(current: current, username: '  Guest_Name  '),
        {'username': 'Guest_Name', 'searchName': 'guest_name'});
    expect(current['points'], 120);
  });
  test('rename consumes one ticket and preserves unrelated inventory', () {
    final inventory = {'username_change_ticket': 2, 'table_skin': 1};
    final current = <String, dynamic>{'username': 'old_name', 'inventory': inventory};
    final result = profileUpdate(current: current, username: 'new_name');
    expect(result['inventory'], {'username_change_ticket': 1, 'table_skin': 1});
    expect(inventory['username_change_ticket'], 2);
    expect(profileUpdate(current: current, username: 'old_name').containsKey('inventory'), false);
  });
  test('rename needs a ticket unless explicitly authorized', () {
    final current = <String, dynamic>{'username': 'old_name', 'isAdmin': true};
    expect(() => profileUpdate(current: current, username: 'new_name'), throwsStateError);
    expect(profileUpdate(current: current, username: 'new_name', canRenameWithoutTicket: true),
        {'username': 'new_name', 'searchName': 'new_name'});
  });
  test('invalid usernames never produce writes', () {
    for (final value in ['ab', 'two words', 'name/path', 'a' * 21]) {
      expect(() => profileUpdate(current: {}, username: value), throwsStateError);
    }
  });
  test('display name fallback supports profiles with no username', () {
    expect(profileUpdate(current: {'username': ''}, displayName: 'Guest'),
        {'displayName': 'Guest', 'searchName': 'guest'});
    expect(profileUpdate(current: {'username': 'Player'}, displayName: 'Guest')['searchName'], 'player');
    expect(profileUpdate(current: {}, avatarUrl: 'avatar'), {'avatarUrl': 'avatar'});
  });
}
