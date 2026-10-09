import 'package:flutter_test/flutter_test.dart';
import 'package:pmcc_image/core/constants/app_strings.dart';
import 'package:pmcc_image/main.dart';

void main() {
  testWidgets('home screen shows the open camera button', (tester) async {
    await tester.pumpWidget(const PmccImageApp());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.openCamera), findsOneWidget);
  });
}
