# Storage Setup

Lampiran foto dan voice note belum tersambung ke object storage pada checkout ini. Neon Object Storage bersifat S3-compatible dan branch-aware; bucket dan objek ikut branch. Jangan simpan secret S3 atau kredensial database di aplikasi.

Sebelum mengaktifkan unggah: buat bucket privat pada branch yang benar, simpan kredensial di Function, validasi MIME type/ukuran pada server, kaitkan object key dengan user ID yang berasal dari sesi, dan berikan URL berumur singkat atau proxy yang memeriksa kepemilikan saat unduh. Hapus metadata dan objek orphan melalui job terkontrol.

Batas aplikasi yang didefinisikan: foto 5 MB dan audio 50 MB (`AppConstants`). Validasi server tetap wajib.

Referensi: [Neon Object Storage](https://neon.com/blog/building-neon-object-storage).
