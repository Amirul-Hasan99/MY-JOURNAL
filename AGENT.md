# Agent Guide — My Journal

## Aturan kerja
- Pertahankan struktur feature-first yang ada di `lib/`.
- Gunakan Flutter/Dart stable dari toolchain proyek; jangan melakukan upgrade mayor tanpa kebutuhan.
- Gunakan Riverpod untuk state, GoRouter untuk routing, Dio untuk HTTP, dan Flutter Secure Storage untuk sesi.
- Semua teks UI Bahasa Indonesia. Tab utama wajib persis: Beranda, Planner, Journal, Tracker, Insight.
- Gunakan token pada `lib/core/theme`; jangan menambahkan nilai warna/spacing yang menggandakan sistem desain.
- Jangan menyimpan password, connection string, token privileged, atau rahasia storage di Flutter, docs, asset, ataupun commit.
- Backend dipanggil melalui HTTPS yang memverifikasi sesi dan membatasi setiap query pada identitas terautentikasi. Jangan percaya `userId` dari klien.
- Demo hanya ketika `DEMO_MODE=true`; jangan mengaku login, reset email, sync, atau upload ke server sungguhan.
- Jangan menghapus data produksi atau menjalankan migrasi destruktif tanpa rencana migrasi.

## Pemeriksaan
Jalankan `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, dan build Android debug bila toolchain tersedia. Jalankan pemeriksaan backend dari `backend/package.json` setelah backend benar-benar ditambahkan. Catat hasil yang diamati dalam `docs/TESTING.md`.

## Batas status
Layar atau repository lokal bukan bukti integrasi Neon. Jangan menandai fitur sebagai siap produksi sebelum ada endpoint, migrasi, pemeriksaan otorisasi, dan pengujian pada branch database terisolasi.
