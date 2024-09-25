import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mdl_karyawan.dart';
import 'main.dart';
import 'access_db.dart';
import 'konstanta.dart';

class Karyawan extends StatefulWidget {
  final String title = "Pilih Nama Karyawan";

  @override
  _KaryawanState createState() => _KaryawanState();
}

class _KaryawanState extends State<Karyawan> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  List _dataGet = [];
  List _dataCari = [];
  List _ditemukan = [];

  bool _gagal = false;
  bool _loading = false;

  _simpan(karyawan) async {
    var karyawanSave = {
      "fid": karyawan['fid'],
      "nama": karyawan['nama'],
      "jabatan": karyawan['jabatan'] == null || karyawan['jabatan'] == ''
          ? '-'
          : karyawan['jabatan'],
      "namaunit": karyawan['namaunit'] == null || karyawan['namaunit'] == ''
          ? '-'
          : karyawan['namaunit'],
    };

    var simpan = await AccessDatabase.db
        .createKaryawan(MdlKaryawan.fromJson(karyawanSave));
    if (simpan != 0 || simpan != null) {
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) {
        return MyHomePage(title: 'Kliksensi');
      }));
    } else {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Terjadi kesalahan, mohon coba lagi'),
        backgroundColor: Colors.red,
      ));
    }
  }

  _dlgInfoKaryawan(karyawan) {
    Widget rowHead(label) {
      return Padding(
        padding: EdgeInsets.only(top: 10, bottom: 5),
        child: Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Perhatian!'),
        content: SingleChildScrollView(
            child: ListBody(children: <Widget>[
          Container(
            decoration: BoxDecoration(color: Colors.yellow),
            child: Padding(
                padding:
                    EdgeInsets.only(top: 10, bottom: 10, left: 5, right: 5),
                child: RichText(
                    text: TextSpan(
                        style: TextStyle(color: Colors.deepOrange),
                        children: <TextSpan>[
                      TextSpan(text: 'Pastikan data sudah benar, Anda '),
                      TextSpan(
                          text: 'tidak bisa Logout',
                          style: TextStyle(fontWeight: FontWeight.bold))
                    ]))),
          ),
          rowHead("Nama"),
          Text(karyawan['nama']),
          rowHead("Jabatan"),
          Text(karyawan['jabatan'] != null ? karyawan['jabatan'] : '-'),
          rowHead("Unit/Bagian"),
          Text(karyawan['namaunit'] != null ? karyawan['namaunit'] : '-')
        ])),
        actions: <Widget>[
          FlatButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Batal"),
          ),
          FlatButton(
            onPressed: () {
              _simpan(karyawan);
            },
            child: Text("Lanjutkan"),
          ),
        ],
      ),
    );
  }

  _cari(String keyword) {
    setState(() {
      _dataCari.clear();
    });
    if (keyword.isNotEmpty) {
      _ditemukan.clear();
      _dataGet.forEach((element) {
        if (element['nama'].toLowerCase().contains(keyword.toLowerCase())) {
          _ditemukan.add(element);
        }
      });
      setState(() {
        _dataCari.clear();
        _dataCari.addAll(_ditemukan);
      });
    }
  }

  Future<String> _getData() async {
    setState(() {
      _loading = true;
    });
    try {
      var response = await http.post(
          Uri.encodeFull(baseUrl + "absenapi/listkaryawan.php"),
          headers: {
            "Accept": "application/json"
          }).timeout(Duration(seconds: 15));

      setState(() {
        var _data = json.decode(response.body);
        _dataGet = _data['data'];
        _gagal = false;
        _loading = false;
      });
    } on TimeoutException catch (_) {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            Text('Terjadi kesalahan, mohon periksa jaringan dan coba lagi'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        _gagal = true;
        _loading = false;
      });
    } on SocketException catch (_) {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Terjadi kesalahan, pastikan jaringan aktif'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        _gagal = true;
        _loading = false;
      });
    }
    return "Success";
  }

  @override
  void initState() {
    super.initState();
    _getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Login"),
          elevation: 1,
        ),
        body: Column(children: <Widget>[
          Padding(
              padding: EdgeInsets.all(10),
              child: TextField(
                enabled: !_loading && !_gagal,
                onChanged: (val) {
                  _cari(val);
                },
                decoration: InputDecoration(
                    labelText: "Cari",
                    hintText: "Ketikkan nama Anda...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)))),
              )),
          Expanded(
            child: Center(
              child: _getList(),
            ),
          ),
        ]));
  }

  Widget _getList() {
    Widget content;
    if (_loading) {
      content = Container(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      if (_gagal) {
        content = Container(
          child: Center(
            child: RaisedButton(
              onPressed: () {
                _getData();
              },
              child: Text('Coba Lagi'),
            ),
          ),
        );
      } else {
        if (_dataCari == null || _dataCari.length < 1) {
          content = Container(
            child: Center(
              child: Text('Silakan cari nama Anda lebih dulu'),
            ),
          );
        } else {
          content = ListView.separated(
            itemCount: _dataCari.length,
            itemBuilder: (BuildContext context, int index) {
              return _getListItem(index);
            },
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[300],
            ),
          );
        }
      }
    }
    return content;
  }

  Widget _getListItem(int i) {
    return ListTile(
      onTap: () {
        _dlgInfoKaryawan(_dataCari[i]);
      },
      title: Text(
        _dataCari[i]['nama'].toString(),
        style: TextStyle(fontSize: 18),
      ),
      subtitle: Text(
        "${_dataCari[i]['jabatan'] == null ? '-' : _dataCari[i]['jabatan']} " +
            "(${_dataCari[i]['namaunit'] == null ? '-' : _dataCari[i]['namaunit']})",
        style: TextStyle(fontSize: 14),
      ),
    );
  }
}
