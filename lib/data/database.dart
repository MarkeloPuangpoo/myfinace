import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  IntColumn get type => integer()(); // 0: income, 1: expense
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get rawBody => text()();
  TextColumn get title => text().nullable()();
}

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertTransaction(TransactionsCompanion entry) {
    return into(transactions).insert(entry);
  }

  Future<List<Transaction>> getAllTransactions() {
    return (select(
      transactions,
    )..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
  }

  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return (select(transactions)
          ..where(
            (t) =>
                t.timestamp.isBiggerOrEqualValue(start) &
                t.timestamp.isSmallerOrEqualValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  Future<double> getTotalIncome() async {
    final result =
        await (selectOnly(transactions)
              ..addColumns([transactions.amount.sum()])
              ..where(transactions.type.equals(0)))
            .getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalExpense() async {
    final result =
        await (selectOnly(transactions)
              ..addColumns([transactions.amount.sum()])
              ..where(transactions.type.equals(1)))
            .getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<int> getTransactionCount() async {
    return (selectOnly(transactions)..addColumns([transactions.id.count()]))
        .getSingle()
        .then((row) => row.read(transactions.id.count()) ?? 0);
  }

  Future<void> clearAllTransactions() {
    return delete(transactions).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      logStatements: true,
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL;');
      },
    );
  });
}
