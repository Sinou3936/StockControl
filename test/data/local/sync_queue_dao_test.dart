import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('oldest returns entries in FIFO order and remove deletes them',
      () async {
    await db.syncQueueDao.enqueue('suppliers', 1);
    await db.syncQueueDao.enqueue('ingredients', 2);

    final first = await db.syncQueueDao.oldest();
    expect(first!.targetTable, 'suppliers');
    expect(first.recordId, 1);

    await db.syncQueueDao.remove(first.id);

    final second = await db.syncQueueDao.oldest();
    expect(second!.targetTable, 'ingredients');

    await db.syncQueueDao.remove(second.id);

    expect(await db.syncQueueDao.oldest(), isNull);
  });
}
