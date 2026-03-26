import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    final databasePath = join(path, 'messages.db');

    return openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSchema(db);
        if (oldVersion < 2) {
          await db.execute('''
            DELETE FROM messages
            WHERE id NOT IN (
              SELECT MIN(id) FROM messages GROUP BY address, body, date
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_message
            ON messages(address, body, date)
          ''');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        body TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_address ON messages(address)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_date ON messages(date)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_message
      ON messages(address, body, date)
    ''');
  }

  Future<int> saveMessage({
    required String address,
    required String body,
    required String date,
  }) async {
    final db = await database;
    final insertedId = await db.insert('messages', {
      'address': address,
      'body': body,
      'date': date,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    if (insertedId > 0) return insertedId;

    final existing = await db.query(
      'messages',
      columns: ['id'],
      where: 'address = ? AND body = ? AND date = ?',
      whereArgs: [address, body, date],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return insertedId;
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    final db = await database;
    return db.query('messages', orderBy: 'date DESC');
  }

  Future<int> deleteMessage(int id) async {
    final db = await database;
    return db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllMessages() async {
    final db = await database;
    return db.delete('messages');
  }

  Future<int> getMessageCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    return result.first['count'] as int;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
