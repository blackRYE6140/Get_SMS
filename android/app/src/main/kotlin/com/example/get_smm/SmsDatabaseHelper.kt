package com.example.get_smm

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal class SmsDatabaseHelper(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        createSchema(db)
        if (oldVersion < 2) {
            db.execSQL(
                """
                DELETE FROM messages
                WHERE id NOT IN (
                    SELECT MIN(id) FROM messages GROUP BY address, body, date
                )
                """.trimIndent(),
            )
            db.execSQL(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_message
                ON messages(address, body, date)
                """.trimIndent(),
            )
        }
    }

    fun saveMessage(address: String, body: String, date: String): Long {
        val values = ContentValues().apply {
            put("address", address)
            put("body", body)
            put("date", date)
        }

        return writableDatabase.insertWithOnConflict(
            TABLE_MESSAGES,
            null,
            values,
            SQLiteDatabase.CONFLICT_IGNORE,
        )
    }

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS messages(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                address TEXT NOT NULL,
                body TEXT NOT NULL,
                date TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """.trimIndent(),
        )

        db.execSQL("CREATE INDEX IF NOT EXISTS idx_address ON messages(address)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_date ON messages(date)")
        db.execSQL(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_message
            ON messages(address, body, date)
            """.trimIndent(),
        )
    }

    private companion object {
        private const val DATABASE_NAME = "messages.db"
        private const val DATABASE_VERSION = 2
        private const val TABLE_MESSAGES = "messages"
    }
}
