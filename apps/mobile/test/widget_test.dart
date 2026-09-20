import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/identity/local_identity.dart';
import 'package:ibd_mobile/core/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 不泵完整 Shell：Dashboard/Symptom 会打开 SQLCipher，单元测试无原生插件。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IBDers 身份与主题壳可构建', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final identity = LocalIdentity();
    await identity.load();

    await tester.pumpWidget(
      Provider<LocalIdentity>.value(
        value: identity,
        child: MaterialApp(
          title: 'IBDers',
          theme: buildIbdTheme(),
          darkTheme: buildIbdDarkTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('IBDers')),
            body: Center(
              child: Text(identity.isLoaded ? 'UUID ready' : 'no uuid'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('IBDers'), findsOneWidget);
    expect(find.text('UUID ready'), findsOneWidget);
  });
}
