import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:loading_overlay/loading_overlay.dart';
import 'konstanta.dart';
import 'access_db.dart';
import 'karyawan.dart';
import 'mdl_karyawan.dart';
import 'tentang.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kliksensi',
      theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Rubik'),
      home: MyHomePage(title: 'Kliksensi'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  bool _loading = false;
  bool _loadingData = false;

  int _fid;
  String _nama = '';
  String _jabatan = '';
  String _unit = '';

  String _tanggal = '';
  String _jam = '';
  Timer _timer;

  GoogleMapController _mapController;
  Location _location = new Location();
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;
  LocationData _locationData;
  Set<Polygon> _areaRsi = HashSet<Polygon>();
  final _pointPolygon = [
    LatLng(-7.36885, 109.9274),
    LatLng(-7.36929, 109.92756),
    LatLng(-7.36946, 109.92753),
    LatLng(-7.36945, 109.92734),
    LatLng(-7.36993, 109.92719),
    LatLng(-7.37027, 109.92694),
    LatLng(-7.37041, 109.92663),
    LatLng(-7.37037, 109.92653),
    LatLng(-7.37005, 109.92628),
    LatLng(-7.36941, 109.92616),
    LatLng(-7.36891, 109.92625),
    LatLng(-7.36862, 109.92668),
    LatLng(-7.36874, 109.92704),
    LatLng(-7.36885, 109.9274)
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      _getTime();
    });
    _getDataKaryawan();
    _checkLocationPermission();
    _createPolygon();
  }

  @protected
  @mustCallSuper
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  void _checkLocationPermission() async {
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    _locationData = await _location.getLocation();
  }

  void _onMapCreated(GoogleMapController ctrl) {
    _mapController = ctrl;
    _location.onLocationChanged.listen((event) {
      _mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
              target: LatLng(event.latitude, event.longitude), zoom: 17)));
    });
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String fmtTanggal = _formatterTanggal(now);
    final String fmtJam = _formatterJam(now);

    setState(() {
      _tanggal = fmtTanggal;
      _jam = fmtJam;
    });
  }

  // https://stackoverflow.com/a/31813714/10769031
  Future<bool> _cekLokasi() async {
    final currentLocation = await _location.getLocation();
    final x = currentLocation.latitude, y = currentLocation.longitude;

    var inside = false;
    for (var i = 0, j = _pointPolygon.length - 1;
        i < _pointPolygon.length;
        j = i++) {
      var xi = _pointPolygon[i].latitude, yi = _pointPolygon[i].longitude;
      var xj = _pointPolygon[j].latitude, yj = _pointPolygon[j].longitude;

      var intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// @param tipe
  /// tipe == 0 --> absen masuk
  /// tipe == 1 --> absen pulang

  Future<void> _absen(int tipe) async {
    var url = 'absenapi/presensi.php';
    final Map data = {"fid": _fid, "tipe": tipe};
    final bodyData = json.encode(data);

    setState(() {
      _loading = true;
    });

    final onLoc = await _cekLokasi();
    if (!onLoc) {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Anda tidak berada di area RSI'),
        backgroundColor: Colors.red,
      ));
    } else {
      try {
        var response = await http
            .post(Uri.encodeFull(baseUrl + url),
                headers: {"Accept": "application/json"}, body: bodyData)
            .timeout(Duration(seconds: 15));
        var result = json.decode(response.body);

        if (result['metadata']['code'] == 200) {
          _scaffoldKey.currentState.removeCurrentSnackBar();
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content:
                Text('Berhasil presensi ${tipe == 0 ? 'masuk' : 'pulang'}'),
            backgroundColor: Colors.blue,
          ));
        } else {
          _scaffoldKey.currentState.removeCurrentSnackBar();
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text(result['metadata']['message']),
            backgroundColor: Colors.red,
          ));
        }
      } on TimeoutException catch (_) {
        _scaffoldKey.currentState.removeCurrentSnackBar();
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content:
              Text('Terjadi kesalahan, mohon periksa jaringan dan coba lagi'),
          backgroundColor: Colors.red,
        ));
      } on SocketException catch (_) {
        _scaffoldKey.currentState.removeCurrentSnackBar();
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Terjadi kesalahan, pastikan jaringan aktif'),
          backgroundColor: Colors.red,
        ));
      }
    }

    setState(() {
      _loading = false;
    });
  }

  String _formatterTanggal(DateTime timeObj) {
    final hari = DateFormat('E').format(timeObj);
    final tanggal = DateFormat('dd').format(timeObj);
    final bulan = int.parse(DateFormat('M').format(timeObj));
    final tahun = DateFormat('yyyy').format(timeObj);

    String namaHari;
    switch (hari) {
      case 'Mon':
        namaHari = 'Sen';
        break;
      case 'Tue':
        namaHari = 'Sel';
        break;
      case 'Wed':
        namaHari = 'Rab';
        break;
      case 'Thu':
        namaHari = 'Kam';
        break;
      case 'Fri':
        namaHari = 'Jum';
        break;
      case 'Sat':
        namaHari = 'Sab';
        break;
      case 'Sun':
        namaHari = 'Min';
        break;
      default:
        namaHari = '-';
        break;
    }

    List namaBulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '$namaHari, $tanggal ${namaBulan[bulan - 1]} $tahun';
  }

  String _formatterJam(DateTime timeObj) {
    return DateFormat('HH:mm:ss').format(timeObj);
  }

  void _goToUser() {
    Navigator.of(context).pop();
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => Karyawan()));
  }

  void _goToAbout() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Tentang()));
  }

  Future<void> _updateKaryawan() async {
    final Map data = {"fid": _fid};
    final bodyData = json.encode(data);

    setState(() {
      _loadingData = true;
    });

    try {
      var response = await http
          .post(Uri.encodeFull(baseUrl + "absenapi/getkaryawan.php"),
              headers: {"Accept": "application/json"}, body: bodyData)
          .timeout(Duration(seconds: 15));
      var result = json.decode(response.body);

      if (result['metadata']['code'] == 200) {
        var karyawanSave = {
          "fid": _fid,
          "nama": result['data']['nama'],
          "jabatan": result['data']['jabatan'] == null ||
                  result['data']['jabatan'] == ''
              ? '-'
              : result['data']['jabatan'],
          "namaunit": result['data']['namaunit'] == null ||
                  result['data']['namaunit'] == ''
              ? '-'
              : result['data']['namaunit'],
        };

        var simpan = await AccessDatabase.db
            .updateKaryawan(MdlKaryawan.fromJson(karyawanSave));
        if (simpan != 0 || simpan != null) {
          setState(() {
            _nama = karyawanSave['nama'];
            _jabatan = karyawanSave['jabatan'];
            _unit = karyawanSave['namaunit'];
          });
          _scaffoldKey.currentState.removeCurrentSnackBar();
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text('Berhasil perbarui data'),
            backgroundColor: Colors.blue,
          ));
        } else {
          _scaffoldKey.currentState.removeCurrentSnackBar();
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text('Terjadi kesalahan saat perbarui data'),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        _scaffoldKey.currentState.removeCurrentSnackBar();
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text(result['metadata']['message']),
          backgroundColor: Colors.red,
        ));
      }
    } on TimeoutException catch (_) {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            Text('Terjadi kesalahan, mohon periksa jaringan dan coba lagi'),
        backgroundColor: Colors.red,
      ));
    } on SocketException catch (_) {
      _scaffoldKey.currentState.removeCurrentSnackBar();
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Terjadi kesalahan, pastikan jaringan aktif'),
        backgroundColor: Colors.red,
      ));
    }

    setState(() {
      _loadingData = false;
    });
  }

  void _getDataKaryawan() async {
    final karyawan = await AccessDatabase.db.getKaryawan();
    if (karyawan.length > 0) {
      setState(() {
        _fid = karyawan[0].fid;
        _nama = karyawan[0].nama;
        _jabatan = karyawan[0].jabatan;
        _unit = karyawan[0].namaunit;
      });
    } else {
      _goToUser();
    }
  }

  void _createPolygon() {
    setState(() {
      _areaRsi.add(Polygon(
          polygonId: PolygonId('polygon_id_1'),
          points: _pointPolygon,
          strokeWidth: 2,
          strokeColor: Colors.yellow,
          fillColor: Colors.yellow.withOpacity(0.15)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 1,
        actions: <Widget>[
          _loadingData
              ? Container(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.refresh),
                  tooltip: 'Perbarui data diri',
                  onPressed: () {
                    _updateKaryawan();
                  },
                ),
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: 'Tentang aplikasi',
            onPressed: () {
              _goToAbout();
            },
          ),
        ],
      ),
      body: _nama != ''
          ? LoadingOverlay(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20))),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _nama,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          Divider(
                            color: Colors.white54,
                            height: 10,
                            thickness: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          Text('$_jabatan ($_unit)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16))
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 10, right: 10, left: 10),
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20)),
                          border: Border.all(color: Colors.black12, width: 1)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_tanggal),
                          Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              _jam,
                              style: TextStyle(
                                  fontFamily: 'Digital7',
                                  fontSize: 30,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.green),
                            ),
                          )
                        ],
                      ),
                    ),
                    Container(
                        height: 220,
                        margin: EdgeInsets.only(right: 10, left: 10),
                        decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.black12, width: 1)),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                              target: _locationData == null
                                  ? LatLng(-7.3691902, 109.9248576)
                                  : LatLng(_locationData.latitude,
                                      _locationData.longitude),
                              zoom: 17),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onMapCreated: _onMapCreated,
                          polygons: _areaRsi,
                        )),
                    // RaisedButton(
                    //     onPressed: () {
                    //       goToUser();
                    //     },
                    //     child: Text('Cek halaman karyawan'))
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 120,
                            child: RaisedButton(
                              onPressed: () {
                                _absen(0);
                              },
                              child: Padding(
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.login,
                                      color: Colors.white,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        'Masuk',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20))),
                              color: Colors.green,
                              elevation: 1,
                            ),
                          ),
                          Container(
                            width: 120,
                            child: RaisedButton(
                              onPressed: () {
                                _absen(1);
                              },
                              child: Padding(
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.logout,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        'Pulang',
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(20)),
                                  side: BorderSide(
                                      width: 1, color: Colors.black26)),
                              color: Colors.white,
                              elevation: 1,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              isLoading: _loading,
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
