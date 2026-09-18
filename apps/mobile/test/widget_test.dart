import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/main.dart';
import 'package:provider/provider.dart';
import 'package:ibd_mobile/core/identity/local_identity.dart';

void main() {
  testWidgets('IBDers app builds', (tester) async {
    final identity = LocalIdentity();
    await identity.load();
    await tester.pumpWidget(
      Provider<LocalIdentity>.value(
        value: identity,
        child: const IbdApp(),
      ),
    );
    expect(find.text('IBDers'), findsWidgets);
  });
}
