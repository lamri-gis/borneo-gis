# BorneoGIS Navigator

<p align="center">
  <img src="https://img.shields.io/github/v/release/lamri-gis/borneo-gis?label=Download%20APK&color=00C853" alt="Download APK"/>
  <img src="https://img.shields.io/badge/Platform-Android-green" alt="Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.29-blue" alt="Flutter"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"/>
  <img src="https://img.shields.io/badge/Offline-100%25-brightgreen" alt="Offline"/>
</p>

**BorneoGIS Navigator** adalah aplikasi pemetaan lapangan untuk Android yang dirancang khusus untuk kebutuhan survei dan pemetaan di lapangan. Dibangun dengan Flutter, aplikasi ini bekerja sepenuhnya **offline** tanpa membutuhkan koneksi internet.

Dikembangkan oleh [Lamri, S.P.](https://lamri.vercel.app) — GIS Analyst & WebGIS Developer, Desa Susuk Dalam, Kec. Sandaran, Kab. Kutai Timur, Kalimantan Timur.

---

## Tujuan & Manfaat

Aplikasi ini hadir sebagai solusi ringan dan gratis untuk petugas lapangan, surveyor, dan pengelola wilayah desa yang membutuhkan alat pemetaan sederhana namun andal tanpa bergantung pada koneksi internet atau perangkat GPS khusus.

**Cocok digunakan untuk:**
- Survey dan pemetaan lapangan kawasan desa
- Pencatatan koordinat titik batas lahan
- Rekam jalur patroli, transek, atau perjalanan lapangan
- Verifikasi koordinat lokasi di lapangan
- Pengelolaan data spasial sederhana tanpa GIS desktop

---

## Fitur

### GPS & Navigasi
- Tampilan koordinat GPS real-time dalam format **Lat/Lon** dan **UTM WGS84**
- Informasi elevasi, heading, kecepatan, dan akurasi sinyal GPS
- Kompas digital terintegrasi

### Peta Interaktif
- Kanvas peta dengan gesture **pan & zoom**
- Grid jarak otomatis menyesuaikan skala
- Crosshair tengah layar untuk presisi

### Marking & Anotasi
- Pasang **pin** di posisi GPS saat ini atau input koordinat manual
- Input koordinat dalam format **Lat/Lon** maupun **UTM** (dengan konversi otomatis)
- Buat **lingkaran radius** multi-ring dari titik manapun (satuan meter atau kilometer)
- Label nama untuk setiap pin dan radius

### Track Recording
- Rekam **jalur perjalanan** lapangan secara real-time
- Tampilan jumlah titik dan total jarak selama perekaman
- Simpan otomatis ke file **GPX**

### Import & Export
| Format | Import | Export |
|--------|--------|--------|
| GPX | ✅ | ✅ |
| KML | ✅ | ✅ |
| GeoJSON | — | ✅ |

- Import file KML/GPX sebagai overlay di peta
- Export pin ke GPX, KML, atau GeoJSON
- Export track ke GPX atau KML

---

## Download

**[⬇ Download APK Terbaru](../../releases/latest)**

Install langsung di Android:
1. Download file `.apk` dari link di atas
2. Buka file di HP Android
3. Izinkan install dari sumber tidak dikenal jika diminta
4. Buka aplikasi dan izinkan akses lokasi

> Diuji pada Android 10+. Membutuhkan izin akses lokasi (GPS).

---

## Stack Teknologi

- **Flutter** 3.29 — Android only
- **Provider** — state management
- **Location** — GPS stream
- **Flutter Compass** — sensor kompas
- **File Picker** — import KML/GPX
- **Path Provider** — penyimpanan file
- **XML** — parsing KML/GPX
- **Shared Preferences** — persistensi data pin & radius
- **UUID** — identifikasi objek unik

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
