# BorneoGIS Navigator

<p align="center">
  <img src="https://img.shields.io/github/v/release/lamri-gis/borneo-gis?label=Download%20APK&color=00C853" alt="Download APK"/>
  <img src="https://img.shields.io/badge/Platform-Android-green" alt="Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.29-blue" alt="Flutter"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"/>
  <img src="https://img.shields.io/badge/Offline-100%25-brightgreen" alt="Offline"/>
</p>

[🇬🇧 English](README.md) | 🇮🇩 Bahasa Indonesia

---

**BorneoGIS Navigator** adalah aplikasi pemetaan lapangan untuk Android yang dirancang khusus untuk kebutuhan survei dan pengumpulan data spasial di lapangan. Dibangun dengan Flutter, aplikasi ini bekerja sepenuhnya **offline** tanpa membutuhkan koneksi internet.

Dikembangkan oleh [Lamri, S.P.](https://lamri.vercel.app) — GIS Analyst & WebGIS Developer, Desa Susuk Dalam, Kec. Sandaran, Kab. Kutai Timur, Kalimantan Timur.

---

## Tujuan & Manfaat

Alternatif ringan dan gratis untuk aplikasi GIS lapangan komersial, ditujukan bagi petugas desa, surveyor lapangan, dan pengelola lahan yang membutuhkan alat pemetaan andal tanpa bergantung pada koneksi internet atau perangkat GPS khusus.

**Cocok digunakan untuk:**
- Survey batas desa dan pemetaan lahan
- Pencatatan waypoint dan koordinat di lapangan
- Rekam jalur patroli, transek, dan perjalanan lapangan
- Verifikasi koordinat lokasi secara langsung
- Pengumpulan data spasial dasar tanpa GIS desktop

---

## Fitur

### GPS & Navigasi
- Koordinat GPS real-time dalam format **Lat/Lon** dan **UTM WGS84**
- Tampilan elevasi, heading, kecepatan, dan akurasi sinyal GPS
- Kompas digital terintegrasi

### Peta Interaktif
- Kanvas peta dengan gesture **pan & zoom**
- Grid jarak otomatis menyesuaikan skala
- Crosshair tengah layar untuk presisi

### Marking & Anotasi
- Pasang **pin** di posisi GPS saat ini atau input koordinat manual
- Input koordinat dalam format **Lat/Lon** atau **UTM** dengan konversi otomatis
- **Lingkaran radius** multi-ring dari titik manapun (meter atau kilometer)
- Label nama untuk setiap pin dan radius

### Rekam Track
- Rekam **jalur perjalanan** lapangan secara real-time
- Tampilan jumlah titik dan total jarak selama perekaman
- Simpan otomatis ke file **GPX**

### Import & Export

| Format | Import | Export |
|--------|--------|--------|
| GPX | ✅ | ✅ |
| KML | ✅ | ✅ |
| GeoJSON | — | ✅ |

---

## Download

**[⬇ Download APK Terbaru](../../releases/latest)**

### Cara Install di Android
1. Download file `.apk` dari link di atas
2. Buka file di HP Android
3. Izinkan install dari sumber tidak dikenal jika diminta
4. Buka aplikasi dan izinkan akses lokasi

> Diuji pada Android 10+. Membutuhkan izin akses lokasi (GPS).

---

## Stack Teknologi

| Package | Fungsi |
|---------|--------|
| Flutter 3.29 | Framework (Android only) |
| provider | State management |
| location | GPS stream |
| flutter_compass | Sensor kompas |
| file_picker | Import KML/GPX |
| path_provider | Penyimpanan file |
| xml | Parsing KML/GPX |
| shared_preferences | Persistensi pin & radius |
| uuid | ID objek unik |

---

## Build dari Source

```bash
git clone https://github.com/lamri-gis/borneo-gis.git
cd borneo-gis
flutter pub get
flutter build apk --release
```

Untuk build signed APK, lihat konfigurasi di `.github/workflows/build.yml`.

---

## Lisensi

MIT License — © [Lamri, S.P.](https://lamri.vercel.app)
