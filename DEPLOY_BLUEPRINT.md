# Blueprint Deploy — grow-up.my.id via Terminal cPanel

| Item | Nilai |
|---|---|
| Domain | `grow-up.my.id` (domain utama akun cPanel) |
| User cPanel | `growupmy` |
| Document root | `/home/growupmy/public_html/` |
| Folder repo di server | `/home/growupmy/repositories/grow-up/` |
| Repository | `https://github.com/anandanajahudin/grow-up.git` (branch `main`) |
| Tipe situs | Statis (HTML/CSS/JS) + 2 file PHP di `forms/` |
| Metode | Terminal cPanel: `git clone` sekali, lalu `deploy.sh` setiap update |

## Alur

```
Laptop ──git push──▶ GitHub (main)
                         │
                         ▼  Terminal cPanel: bash ~/repositories/grow-up/deploy.sh
              ~/repositories/grow-up   (git pull)
                         │
                         ▼  cp assets, forms, *.html, .htaccess
              ~/public_html            ──▶ https://grow-up.my.id
```

Repo **tidak** di-clone langsung ke `public_html`, supaya folder `.git` tidak terekspos ke publik dan file bawaan hosting (`cgi-bin`, `.well-known`) tidak bentrok.

[deploy.sh](deploy.sh) melakukan dua hal: `git pull` dari GitHub, lalu menyalin `assets/`, `forms/`, semua `*.html`, dan `.htaccess` ke `public_html`.

---

## Fase 0 — Prasyarat

- [ ] DNS `grow-up.my.id` mengarah ke hosting (nameserver hosting, atau A record `@` dan `www` → IP server). Cek: `nslookup grow-up.my.id`.
- [ ] Menu **Terminal** ada di cPanel (bagian *Advanced*). Kalau tidak ada, aktifkan **SSH Access** dan login lewat SSH dari laptop: `ssh growupmy@grow-up.my.id -p <port>`.
- [ ] `git` tersedia di server: jalankan `git --version` di Terminal.

## Fase 1 — Akses repo dari server

**Jika repo GitHub publik:** lewati fase ini.

**Jika repo privat** (SSH deploy key):

> Akun cPanel ini sudah punya key `github_deploy` milik project **babyshop**. **Jangan dipakai ulang atau ditimpa.** GitHub menolak satu deploy key dipakai di dua repo, dan mengubah `Host github.com` di `~/.ssh/config` bisa merusak pull babyshop. Buat key terpisah dan pakai **alias host**.

```bash
# 1. Buat key khusus grow-up
ssh-keygen -t ed25519 -f ~/.ssh/github_growup -N "" -C "growup-deploy"
cat ~/.ssh/github_growup.pub
```
2. Tempel public key ke GitHub → repo `grow-up` → *Settings → Deploy keys → Add deploy key* (read-only cukup).
```bash
# 3. Lihat config lama, lalu TAMBAHKAN alias (jangan ubah entri babyshop)
cat ~/.ssh/config
cat >> ~/.ssh/config <<'EOF'

Host github-growup
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_growup
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/github_growup

# 4. Tes
ssh -T git@github-growup
```
Harus muncul "Hi anandanajahudin/grow-up! You've successfully authenticated". Pastikan babyshop masih aman dengan menjalankan `git fetch` di folder repo babyshop.

## Fase 2 — Clone (sekali saja)

```bash
mkdir -p ~/repositories
cd ~/repositories

# Repo publik:
git clone https://github.com/anandanajahudin/grow-up.git
# Repo privat (pakai alias dari Fase 1):
# git clone git@github-growup:anandanajahudin/grow-up.git
```

**Sudah terlanjur clone di lokasi lain** (mis. `~/grow-up`)? Pindahkan agar sesuai blueprint:
```bash
mv ~/grow-up ~/repositories/grow-up
```
Atau biarkan saja: `deploy.sh` bekerja dari folder mana pun. Sesuaikan path di perintah-perintah berikutnya.

## Fase 3 — Deploy pertama

```bash
# 1. Backup public_html
cd ~ && tar -czf ~/backup_public_html_$(date +%Y%m%d).tar.gz public_html

# 2. Lihat isi public_html, hapus halaman default hosting (JANGAN hapus .well-known & cgi-bin)
ls -la ~/public_html
rm -f ~/public_html/index.php ~/public_html/default.html

# 3. Deploy
bash ~/repositories/grow-up/deploy.sh

# 4. Cek hasil
ls ~/public_html
```

`.htaccess` di repo sudah memprioritaskan `index.html`. Langkah 2 tetap disarankan supaya tidak ada halaman default yang tertinggal.

> **Perhatian `.htaccess`:** kalau `public_html` sudah punya `.htaccess` dari hosting (mis. blok `# php -- BEGIN cPanel-generated handler`), lihat dulu dengan `cat ~/public_html/.htaccess` **sebelum** deploy. Salin blok penting itu ke `.htaccess` di repo, push, baru deploy, karena `deploy.sh` akan menimpanya.

## Fase 4 — Alur update rutin

```bash
# Di laptop
git add . && git commit -m "..." && git push origin main

# Di Terminal cPanel
bash ~/repositories/grow-up/deploy.sh
```

Perbarui situs **selalu lewat laptop → GitHub**. Jangan edit file langsung di `~/repositories/grow-up`, karena `git pull --ff-only` akan gagal kalau ada perubahan lokal. Kalau terlanjur, buang perubahan server dengan `git -C ~/repositories/grow-up reset --hard origin/main`.

**Opsional — deploy otomatis via GitHub Actions** (butuh SSH Access aktif):

1. Buat key pair khusus (di laptop), lalu pasang public key di cPanel → SSH Access → *Import Key* → **Authorize**.
2. GitHub → *Settings → Secrets and variables → Actions*: `CPANEL_HOST`, `CPANEL_USER` (`growupmy`), `CPANEL_SSH_KEY` (private key), `CPANEL_PORT` (sering `22`, beberapa hosting `2222`/`64000`).
3. Buat `.github/workflows/deploy.yml`:
   ```yaml
   name: Deploy to cPanel
   on:
     push:
       branches: [main]
   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: appleboy/ssh-action@v1.2.0
           with:
             host: ${{ secrets.CPANEL_HOST }}
             username: ${{ secrets.CPANEL_USER }}
             key: ${{ secrets.CPANEL_SSH_KEY }}
             port: ${{ secrets.CPANEL_PORT }}
             script: bash ~/repositories/grow-up/deploy.sh
   ```

## Fase 5 — SSL & HTTPS

**Lakukan sebelum atau tepat setelah deploy pertama.** `.htaccess` memaksa semua pengunjung ke HTTPS, jadi tanpa SSL situs akan menampilkan error sertifikat.

1. cPanel → **SSL/TLS Status** → centang `grow-up.my.id` dan `www.grow-up.my.id` → *Run AutoSSL*.
2. Tunggu sampai status hijau (beberapa menit, DNS harus sudah mengarah ke server).

## Fase 6 — Verifikasi

- [ ] `https://grow-up.my.id` tampil dengan konten terbaru, gembok SSL valid.
- [ ] `http://grow-up.my.id` dan `https://www.grow-up.my.id` redirect ke `https://grow-up.my.id`.
- [ ] CSS/JS/gambar termuat (DevTools → Network, tidak ada 404).
- [ ] Halaman `portfolio-details.html` dan `service-details.html` terbuka.
- [ ] Hard refresh (Ctrl+F5) setelah deploy, untuk memastikan yang tampil bukan cache browser.

## Fase 7 — Rollback

- **Normal:** di laptop `git revert <commit>` → push → `bash ~/repositories/grow-up/deploy.sh`.
- **Darurat:** pulihkan backup:
  ```bash
  cd ~ && tar -xzf ~/backup_public_html_YYYYMMDD.tar.gz
  ```

> `deploy.sh` hanya menimpa/menambah file, tidak menghapus. File yang dihapus dari repo tetap ada di `public_html`; hapus manual bila perlu.

---

## Catatan penting: form kontak

`forms/contact.php` dan `forms/newsletter.php` masih bawaan template BootstrapMade: alamat penerima `contact@example.com` dan butuh library *PHP Email Form* (versi pro) yang **tidak ada** di repo. Setelah deploy, form akan menampilkan error "Unable to load the PHP Email Form Library". Pilihan:

1. Beli versi pro, taruh library di `assets/vendor/php-email-form/`, lalu ganti email penerima ke alamat `@grow-up.my.id` (buat di cPanel → Email Accounts).
2. Ganti dengan skrip PHP `mail()` sederhana atau layanan form pihak ketiga (Formspree, dsb.).
3. Sembunyikan form sementara.

## Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| `fatal: Not possible to fast-forward` / `Your local changes would be overwritten` | Ada file yang diubah langsung di server. Jalankan `git -C ~/repositories/grow-up reset --hard origin/main`, lalu deploy ulang. |
| `$'\r': command not found` | `deploy.sh` ber-line-ending Windows. Perbaiki: `sed -i 's/\r$//' ~/repositories/grow-up/deploy.sh` (repo sudah punya `.gitattributes` untuk mencegah ini). |
| `Permission denied (publickey)` saat pull | Deploy key belum dipasang, `~/.ssh/config` salah, atau remote masih `github.com` dan bukan alias. Cek: `git -C ~/repositories/grow-up remote -v`. |
| Situs masih halaman default hosting | `index.php` default belum dihapus, atau cache browser. |
| Error sertifikat / redirect loop | SSL belum aktif (Fase 5). Sementara, rename `~/public_html/.htaccess` lalu jalankan AutoSSL. |
| Error 500 setelah deploy | Ada direktif `.htaccess` yang tidak didukung server. Cek `~/logs/` atau cPanel → *Errors*, lalu hapus baris yang bermasalah. |
| Gambar/CSS 404 | Nama file case-sensitive di Linux (`Logo.png` ≠ `logo.png`). |
