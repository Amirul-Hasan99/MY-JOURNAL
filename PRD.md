# Product Requirements Document — My Journal

## Tujuan
Aplikasi Flutter pribadi berbahasa Indonesia untuk merencanakan kegiatan, menyimpan jurnal, melacak suasana hati dan kebiasaan, mengelola tujuan, serta melihat ringkasan produktivitas.

## Pengguna dan nilai
Pengguna utama adalah individu yang ingin mengatur hari dan merefleksikan perkembangan dirinya dalam satu aplikasi. Data jurnal, suasana hati, dan rekaman suara bersifat pribadi.

## Navigasi utama
Tab bawah harus berlabel persis: **Beranda**, **Planner**, **Journal**, **Tracker**, **Insight**. Desain memakai Material 3 dan token warna sage/krem pada `lib/core/theme`.

## Fitur produk yang dituju
- Autentikasi, registrasi, pemulihan kata sandi, profil, pengaturan, dan logout.
- Tugas terjadwal dan agenda harian.
- Entri jurnal, pencarian, lampiran foto, rekaman dan pemutaran suara.
- Mood, habit dan streak, goal dan milestone.
- Insight yang dihitung dari data tersimpan.
- Pengingat lokal, ekspor PDF, dan widget native.

## Status implementasi saat audit
Aplikasi Flutter berisi layar untuk sebagian besar alur dan repositori demo/local. Backend Neon, migrasi, kebijakan otorisasi, integrasi autentikasi terverifikasi, dan object storage belum ada dalam checkout ini. Beberapa operasi UI belum terbukti persisten. Fitur yang bergantung pada layanan tersebut adalah target, bukan fitur produksi yang sudah selesai.

## Kriteria penerimaan sebelum rilis
1. Navigasi lima tab serta seluruh alur form bekerja pada perangkat target.
2. Login, registrasi, pemulihan sesi, reset kata sandi, dan logout memakai layanan yang benar-benar terkonfigurasi.
3. CRUD tersimpan ke Neon dan semua akses dibatasi ke pengguna terverifikasi.
4. Lampiran dan voice note dapat diunggah/diunduh secara privat.
5. Insight, pengingat, PDF, dan widget memakai data aktual.
6. Unit, widget, integrasi backend, dan pengujian end-to-end lulus.
7. Tidak ada rahasia server dalam source Flutter.

## Mode demo
Demo harus diaktifkan dengan `--dart-define=DEMO_MODE=true`, diberi label, memakai identitas contoh Dania Sella, dan tidak menyatakan bahwa data tersimpan di Neon. Pemulihan email tidak boleh menyatakan email telah dikirim bila layanan tidak aktif.
