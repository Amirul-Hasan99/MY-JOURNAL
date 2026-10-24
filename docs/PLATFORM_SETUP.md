# Platform Setup

## Android/iOS
Flutter plugin untuk audio recording/playback, notifikasi lokal, PDF/printing, dan home widget tercantum di `pubspec.yaml`. Keberadaan package saja belum membuktikan izin native, widget extension, atau penjadwalan sudah berjalan.

Periksa izin mikrofon dan notifikasi pada Android manifest, iOS `Info.plist`, request izin saat runtime, dan pengujian perangkat nyata. iOS widget memerlukan WidgetKit extension native; Android memerlukan AppWidgetProvider. Kode extension khusus belum ada dalam checkout ini.

## Web
Flutter Web platform telah dibuat. Gunakan ikon yang sama untuk favicon dan manifest web. Audio recording/notifikasi/widget memiliki dukungan browser dan batasan platform berbeda; tampilkan fallback yang jelas.

## Toolchain
Android build memerlukan Android SDK/JDK yang kompatibel. iOS build memerlukan Xcode di macOS. Perangkat/izin nyata dibutuhkan untuk memverifikasi audio dan notifikasi.
