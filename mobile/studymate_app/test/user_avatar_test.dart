import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/profile/user_avatar.dart';

void main() {
  test('initiales à partir du nom ou de l’e-mail', () {
    expect(UserAvatar.initials('Chayma Ben Ali'), 'CB');
    expect(UserAvatar.initials('amine.karray@example.com'), 'AK');
    expect(UserAvatar.initials('  '), '');
    expect(UserAvatar.initials(null), '');
  });

  testWidgets('sans photo, l’avatar affiche les initiales', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(photoUrl: null, name: 'Sara Trabelsi', ring: true)),
      ),
    );
    expect(find.text('ST'), findsOneWidget);
  });
}
