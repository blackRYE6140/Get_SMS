import 'package:flutter_test/flutter_test.dart';
import 'package:get_smm/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Affiche l ecran auto Airtel NetMlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Auto SMS Airtel/NetMlay'), findsOneWidget);
    expect(find.textContaining('Total:'), findsOneWidget);
  });
}
