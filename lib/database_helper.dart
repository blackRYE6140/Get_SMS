import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    final databasePath = join(path, 'airtel_netmlay_messages.db');

    return await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            address TEXT NOT NULL,
            body TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Créer un index pour accélérer les recherches
        await db.execute('''
          CREATE INDEX idx_address ON messages(address)
        ''');

        await db.execute('''
          CREATE INDEX idx_date ON messages(date)
        ''');
      },
    );
  }

  Future<int> saveMessage({
    required String address,
    required String body,
    required String date,
  }) async {
    final db = await database;

    // Vérifier si le message existe déjà pour éviter les doublons
    final existing = await db.query(
      'messages',
      where: 'address = ? AND body = ? AND date = ?',
      whereArgs: [address, body, date],
    );

    if (existing.isEmpty) {
      return await db.insert('messages', {
        'address': address,
        'body': body,
        'date': date,
      });
    }

    return existing.first['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    final db = await database;
    return await db.query('messages', orderBy: 'date DESC');
  }

  Future<int> deleteMessage(int id) async {
    final db = await database;
    return await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllMessages() async {
    final db = await database;
    return await db.delete('messages');
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
