import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Tentang extends StatefulWidget {
  final String title = "Tentang Kliksensi";

  @override
  _TentangState createState() => _TentangState();
}

class _TentangState extends State<Tentang> {
  String _versi = '1.0.0';
  String _build = '3';
  String _tahun = DateFormat('yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Tentang"),
          elevation: 1,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/app_icon.png',
                width: 150,
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Text(
                  'Kliksensi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Text('Versi $_versi, Build no. $_build'),
              Text(
                  '© 2021 ${_tahun == '2021' ? '' : '- ' + _tahun} RSI Wonosobo'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(5),
                    child: Image.asset('assets/images/dev.png'),
                  ),
                  Padding(
                    padding: EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/images/rsi.png',
                      height: 35,
                    ),
                  )
                ],
              )
            ],
          ),
        ));
  }
}
