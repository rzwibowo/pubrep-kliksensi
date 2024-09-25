import 'dart:io';
import 'mdl_karyawan.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AccessDatabase {
  static Database _database;
  static final AccessDatabase db = AccessDatabase._();

  AccessDatabase._();

  Future<Database> get database async {
    if (_database != null) return _database;

    _database = await initDb();

    return _database;
  }

  initDb() async {
    Directory directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'rsi_absen.db');
    return await openDatabase(path,
        version: 1, onOpen: (db) {}, onCreate: _createDb);
  }

  void _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE karyawan (
        fid INTEGER PRIMARY KEY,
        nama TEXT,
        jabatan TEXT,
        namaunit TEXT
      )
    ''');
  }

  createKaryawan(MdlKaryawan data) async {
    await hapusSemuaKaryawan();
    final db = await database;
    final res = await db.insert('karyawan', data.toJson());

    return res;
  }

  updateKaryawan(MdlKaryawan data) async {
    var _fid = data.fid;
    final db = await database;
    final res = await db
        .update('karyawan', data.toJson(), where: 'fid = ?', whereArgs: [_fid]);

    return res;
  }

  Future<List<MdlKaryawan>> getKaryawan() async {
    final db = await database;
    final res = await db.rawQuery("SELECT * FROM karyawan");

    List<MdlKaryawan> list =
        res.isNotEmpty ? res.map((c) => MdlKaryawan.fromJson(c)).toList() : [];

    return list;
  }

  Future<int> hapusSemuaKaryawan() async {
    final db = await database;
    final res = await db.rawDelete('DELETE FROM karyawan');

    return res;
  }
}
