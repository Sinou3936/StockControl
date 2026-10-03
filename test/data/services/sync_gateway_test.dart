import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/services/sync_gateway.dart';

void main() {
  test('cursorToIso sends the cursor as UTC with an explicit Z so the server '
      'does not read local wall-clock time as UTC', () {
    final localCursor = DateTime(2026, 10, 4, 9, 30);

    final iso = cursorToIso(localCursor);

    expect(iso.endsWith('Z'), isTrue);
    expect(DateTime.parse(iso).isAtSameMomentAs(localCursor), isTrue);
  });
}
