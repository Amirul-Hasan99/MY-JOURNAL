# Architecture — My Journal

## Kondisi saat ini
Klien Flutter berada di `lib/` dengan pemisahan `core`, `features`, dan `shared`. State memakai Riverpod; route ada di `lib/app/router.dart`; tema berada di `lib/core/theme`; layar mengonsumsi repository/controller per fitur. API client Dio memakai URL kosong secara default dan mengirim sesi Bearer ke API Node di `backend/`. Repository Planner, Journal, Tracker, dan profil memakai API saat mode normal; mode demo tetap menggunakan SharedPreferences.

## Arsitektur target
`Flutter → HTTPS API → autentikasi sesi terverifikasi → Node.js/Hono → PostgreSQL Neon`.
Rahasia database hanya tersedia pada runtime backend. Backend mendapatkan identitas pemilik dari sesi tervalidasi, bukan parameter `userId` klien, lalu memakai SQL berparameter dan pembatasan kepemilikan. Pilih satu pola CRUD; jangan menggabungkan akses database istimewa dari aplikasi mobile.

## Autentikasi Neon
API menerbitkan sesi opaque acak; database menyimpan hanya hash token dengan kedaluwarsa. Kata sandi di-hash memakai bcrypt. API mengambil pemilik dari sesi terverifikasi dan mengabaikan `userId` yang dikirim klien. Pemulihan kata sandi melalui email belum diaktifkan.

## Data dan alur fitur
Target model: profil, tasks, journals, mood entries, habits/logs, goals/milestones, preferences, dan notification metadata. Agenda Beranda harus berasal dari Planner; Tracker dan Insight harus menghitung entitas yang sama; PDF dan widget harus memakai data akun aktif.

## Keamanan dan privasi
Tidak ada connection string dalam app. Gunakan HTTPS, validasi schema request, validasi sesi pada API, query parameterized, ownership checks untuk setiap CRUD/berkas, log tanpa konten jurnal, dan hapus cache privat saat logout. RLS diterapkan hanya jika jalur koneksi membawa identitas pengguna secara aman.

## Platform
Flutter package tersedia untuk foto, audio, notifikasi, PDF, grafik, dan home widget. Keberadaan dependency bukan bukti integrasi native aktif. Periksa izin dan kode native Android/iOS sebelum mengklaim fitur siap.

## Keputusan dan pekerjaan tersisa
1. Ganti kredensial Neon yang dibagikan di chat dan set rahasia baru hanya di runtime backend.
2. Deploy API lewat HTTPS, tetapkan CORS origin, dan batasi akses database.
3. Uji sesi serta isolasi akun pada branch Neon staging terpisah.
4. Implementasikan object storage privat, notifikasi native, PDF, dan widget.
5. Jalankan end-to-end pada Android/iOS target serta catat keterbatasan.
