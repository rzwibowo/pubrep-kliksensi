class MdlKaryawan {
  int fid;
  String nama;
  String jabatan;
  String namaunit;

  MdlKaryawan({this.fid, this.nama, this.jabatan, this.namaunit});

  factory MdlKaryawan.fromJson(Map<String, dynamic> json) => MdlKaryawan(
      fid: json["fid"],
      nama: json["nama"],
      jabatan: json["jabatan"],
      namaunit: json["namaunit"]);

  Map<String, dynamic> toJson() =>
      {"fid": fid, "nama": nama, "jabatan": jabatan, "namaunit": namaunit};
}
