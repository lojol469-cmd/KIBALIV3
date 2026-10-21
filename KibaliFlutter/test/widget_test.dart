// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kibali_terminal/main.dart';

void main() {
  test('KibaliTerminalApp instanciable', () {
    const app = KibaliTerminalApp();
    expect(app, isA<KibaliTerminalApp>());
  });

  test('Themes chargés', () {
    expect(themes, isNotEmpty);
    expect(themes.first.name, 'Tokyo Night');
  });
}
