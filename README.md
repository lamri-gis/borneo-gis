# BorneoGIS Navigator

<p align="center">
  <img src="https://img.shields.io/github/v/release/lamri-gis/borneo-gis?label=Download%20APK&color=00C853" alt="Download APK"/>
  <img src="https://img.shields.io/badge/Platform-Android-green" alt="Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.29-blue" alt="Flutter"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"/>
  <img src="https://img.shields.io/badge/Offline-100%25-brightgreen" alt="Offline"/>
</p>

🇬🇧 English | [🇮🇩 Bahasa Indonesia](README.id.md)

---

**BorneoGIS Navigator** is an Android field mapping application designed for survey and spatial data collection in the field. Built with Flutter, it works entirely **offline** — no internet connection required.

Developed by [Lamri, S.P.](https://lamri.vercel.app) — GIS Analyst & WebGIS Developer, Susuk Dalam Village, Sandaran, East Kutai, East Kalimantan, Indonesia.

---

## Purpose & Use Cases

A lightweight, free alternative to commercial field GIS apps for village officers, field surveyors, and land managers who need reliable mapping tools without internet dependency or specialized GPS hardware.

**Ideal for:**
- Village boundary and land parcel surveys
- Field waypoint and coordinate recording
- Patrol route, transect, and trail tracking
- On-site coordinate verification
- Basic spatial data collection without a GIS desktop

---

## Features

### GPS & Navigation
- Real-time GPS coordinates in **Lat/Lon** and **UTM WGS84**
- Elevation, heading, speed, and accuracy display
- Integrated digital compass

### Interactive Map
- Touch-based **pan & zoom** map canvas
- Auto-scaling distance grid
- Center crosshair for precision

### Marking & Annotation
- Drop a **pin** at current GPS position or enter coordinates manually
- Coordinate input in **Lat/Lon** or **UTM** format with automatic conversion
- Multi-ring **radius circles** from any point (meters or kilometers)
- Custom labels for pins and radius circles

### Track Recording
- Real-time **track recording** of field routes
- Live display of point count and total distance
- Auto-save to **GPX** file

### Import & Export

| Format | Import | Export |
|--------|--------|--------|
| GPX | ✅ | ✅ |
| KML | ✅ | ✅ |
| GeoJSON | — | ✅ |

---

## Download

**[⬇ Download Latest APK](../../releases/latest)**

### Install on Android
1. Download the `.apk` file from the link above
2. Open the file on your Android device
3. Allow installation from unknown sources if prompted
4. Open the app and grant location permission

> Tested on Android 10+. Requires location (GPS) permission.

---

## Tech Stack

| Package | Purpose |
|---------|---------|
| Flutter 3.29 | Framework (Android only) |
| provider | State management |
| location | GPS stream |
| flutter_compass | Compass sensor |
| file_picker | KML/GPX import |
| path_provider | File storage |
| xml | KML/GPX parsing |
| shared_preferences | Pin & radius persistence |
| uuid | Unique object IDs |

---

## Build from Source

```bash
git clone https://github.com/lamri-gis/borneo-gis.git
cd borneo-gis
flutter pub get
flutter build apk --release
```

For signed APK build, see `.github/workflows/build.yml`.

---

## License

MIT License — © [Lamri, S.P.](https://lamri.vercel.app)
