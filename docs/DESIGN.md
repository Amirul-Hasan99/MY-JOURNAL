# Design — My Journal

## Arah visual
Antarmuka tenang, personal, minimal, dan berorientasi portrait. Material 3, kartu dan isian membulat, jarak kelipatan 8, ruang kosong cukup, bayangan halus, dan kontras teks yang jelas. Gunakan Bahasa Indonesia alami untuk teks aplikasi.

## Token warna
| Peran | HEX |
|---|---|
| Sage utama | `#73A88F` |
| Hijau tua | `#477B64` |
| Sage pucat | `#E7F1E9` |
| Krem latar | `#FAF8F3` |
| Permukaan | `#FFFFFF` |
| Biru lembut | `#E7EFFB` |
| Persik | `#F8E5DC` |
| Lavender | `#EEE8F7` |
| Kuning | `#FAF0D9` |
| Teks utama | `#29352F` |
| Teks sekunder | `#788078` |
| Border | `#E9E7E0` |
| Error | `#C65D5D` |

Token saat ini didefinisikan dalam `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart`, dan `app_theme.dart`. Pakai widget bersama dari `lib/core/widgets` daripada membuat ulang kontrol.

## Komponen dan status
Tombol, field, kartu, chip, empty state, loading, error, dan navigasi bawah tersedia sebagian. Semua formulir harus memiliki label, hint, validasi, fokus, disabled, loading, dan error state yang terbaca. Teks dan ikon pada tombol berwarna harus memenuhi kontras.

## Responsif dan aksesibilitas
Form panjang menggunakan scroll, safe area, dan resize saat keyboard terbuka. Uji lebar 320–430 dp dan skala teks besar. Jangan mengandalkan warna saja untuk status. Semua halaman harus menghindari overflow dan teks terpotong.

## Referensi ikon
Ikon jurnal yang diberikan pengguna adalah sumber ilustrasi aplikasi. Gunakan ikon itu untuk launcher Android/iOS dan favicon web jika target web diaktifkan; jangan menggantinya dengan emoji atau ikon generik.
