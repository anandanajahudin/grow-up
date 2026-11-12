# Blueprint Deploy — grow-up.my.id via cPanel + Git

| Item | Nilai |
|---|---|
| Domain | `grow-up.my.id` (domain utama / primary domain akun cPanel) |
| Document root | `/home/CPANEL_USERNAME/public_html/` |
| Repository | `https://github.com/anandanajahudin/grow-up.git` (branch `main`) |
| Tipe situs | Statis (HTML/CSS/JS) + 2 file PHP di `forms/` |
| Build step | Tidak ada — file langsung disalin |
| Metode | cPanel **Git™ Version Control** + `.cpanel.yml` |

## Alur

```
Laptop ──git push──▶ GitHub (main)
                         │
                         ▼  cPanel: "Update from Remote"
              ~/repositories/grow-up   (clone di server)
                         │
                         ▼  cPanel: "Deploy HEAD Commit"  (menjalankan .cpanel.yml)
              ~/public_html            ──▶ https://grow-up.my.id
```

Repo **tidak** di-clone langsung ke `public_html`, supaya folder `.git` tidak ikut terekspos ke publik dan `public_html` yang sudah berisi file (cgi-bin, .well-known) tidak bentrok.

---

## Fase 0 — Prasyarat

- [ ] Akun hosting cPanel aktif dengan `grow-up.my.id` sebagai **primary domain**.
- [ ] DNS domain mengarah ke hosting: nameserver di registrar (.my.id / PANDI reseller) = nameserver hosting, **atau** A record `@` dan `www` → IP server. Cek dengan `nslookup grow-up.my.id`.
- [ ] Menu **Git™ Version Control** tersedia di cPanel (cPanel ≥ 74). Kalau tidak ada, minta provider mengaktifkan, atau pakai Opsi B di Fase 5.
- [ ] Catat **username cPanel** (pojok kanan atas cPanel / sidebar "General Information" → *Home Directory* `/home/USERNAME`).

## Fase 1 — Siapkan repository (di laptop)

1. Edit [.cpanel.yml](.cpanel.yml): ganti `CPANEL_USERNAME` dengan username cPanel asli.
2. (Opsional, disarankan) Tambah `.htaccess` di root repo untuk paksa HTTPS + cache aset — lihat Lampiran A, lalu tambahkan baris `- /bin/cp .htaccess $DEPLOYPATH` di `.cpanel.yml`.
3. Setiap ada file HTML baru di root, tambahkan juga baris `/bin/cp <file>.html $DEPLOYPATH` di `.cpanel.yml`.
4. Commit & push:
   ```bash
   git add .cpanel.yml DEPLOY_BLUEPRINT.md
   git commit -m "Add cPanel deployment config"
   git push origin main
   ```

> `.cpanel.yml` **wajib** ada di root repo dan ter-commit; tanpa itu tombol Deploy di cPanel nonaktif.

## Fase 2 — Akses repo dari server

**Jika repo GitHub publik:** lewati fase ini, clone pakai URL HTTPS.

**Jika repo privat** (pakai SSH deploy key):

> Akun cPanel ini sudah punya key `github_deploy` milik project **babyshop**. **Jangan dipakai ulang atau ditimpa.** GitHub menolak satu deploy key dipakai di dua repo, dan mengubah `Host github.com` di `~/.ssh/config` bisa merusak pull babyshop. Buat key terpisah dan pakai **alias host**.

1. Buat key baru via Terminal cPanel (atau SSH Access → *Generate a New Key* dengan nama `github_growup`, tanpa passphrase):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/github_growup -N "" -C "growup-deploy"
   cat ~/.ssh/github_growup.pub
   ```
2. GitHub → repo `grow-up` → *Settings → Deploy keys → Add deploy key* → tempel public key (read-only cukup).
3. Lihat dulu isi config yang sudah ada: `cat ~/.ssh/config`. **Jangan ubah** entri babyshop; **tambahkan** di bagian bawah:
   ```
   Host github-growup
     HostName github.com
     User git
     IdentityFile ~/.ssh/github_growup
     IdentitiesOnly yes
   ```
   Pastikan permission benar: `chmod 600 ~/.ssh/config ~/.ssh/github_growup`.
4. Tes: `ssh -T git@github-growup` → harus muncul "Hi anandanajahudin/grow-up! You've successfully authenticated".
   Tes juga babyshop masih aman: `cd ~/repositories/<babyshop> && git fetch`.
5. Clone URL yang dipakai di Fase 3: `git@github-growup:anandanajahudin/grow-up.git` (pakai alias, **bukan** `github.com`).

## Fase 3 — Clone di cPanel

cPanel → **Git™ Version Control** → **Create**:

| Field | Isi |
|---|---|
| Clone a Repository | ON |
| Clone URL | `https://github.com/anandanajahudin/grow-up.git` (publik) atau `git@github-growup:anandanajahudin/grow-up.git` (privat, lihat Fase 2) |
| Repository Path | `repositories/grow-up` |
| Repository Name | `grow-up` |

Klik **Create**, tunggu proses clone selesai.

## Fase 4 — Deploy pertama

1. **Backup** isi `public_html` yang ada (File Manager → pilih semua → *Compress*), terutama kalau ada `index.php`/halaman default hosting.
2. Hapus halaman default hosting di `public_html` (mis. `index.php`, `default.html`) — **jangan** hapus `.well-known` dan `cgi-bin`.
   Catatan: Apache memprioritaskan `index.php` di atas `index.html`, jadi kalau tidak dihapus situs akan tetap menampilkan halaman default.
3. Git™ Version Control → *Manage* `grow-up` → tab **Pull or Deploy**:
   - **Update from Remote** (tarik commit terbaru dari GitHub)
   - **Deploy HEAD Commit** (menjalankan `.cpanel.yml`)
4. Cek log di bagian *Last Deployment Information*; kalau gagal, log lengkap ada di `~/.cpanel/logs/vc_*_git_deploy.log`.

## Fase 5 — Alur update rutin

**Opsi A — Manual (paling sederhana):**
`git push origin main` → cPanel *Update from Remote* → *Deploy HEAD Commit*.

**Opsi B — Otomatis via GitHub Actions + SSH** (butuh SSH access aktif di hosting):

1. Buat key pair khusus (di laptop), pasang public key di cPanel → SSH Access → *Import Key* → **Authorize**.
2. GitHub → *Settings → Secrets and variables → Actions*: `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_SSH_KEY` (private key), `CPANEL_PORT` (sering `22`, beberapa hosting pakai `2222`/`64000`).
3. File `.github/workflows/deploy.yml`:
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
             script: |
               cd ~/repositories/grow-up
               git pull origin main
               uapi VersionControlDeployment create repository_root=$HOME/repositories/grow-up
   ```
   `uapi VersionControlDeployment create` memicu deploy yang sama dengan tombol *Deploy HEAD Commit* (membaca `.cpanel.yml`).

Mulai dengan Opsi A; pindah ke Opsi B kalau deploy manual sudah terasa repetitif.

## Fase 6 — SSL & HTTPS

1. cPanel → **SSL/TLS Status** → centang `grow-up.my.id` dan `www.grow-up.my.id` → *Run AutoSSL* (DNS harus sudah mengarah ke server).
2. cPanel → **Domains** → aktifkan *Force HTTPS Redirect* untuk `grow-up.my.id` (atau pakai `.htaccess` di Lampiran A).

## Fase 7 — Verifikasi

- [ ] `https://grow-up.my.id` tampil dengan konten terbaru, gembok SSL valid.
- [ ] `http://grow-up.my.id` dan `https://www.grow-up.my.id` redirect ke `https://grow-up.my.id`.
- [ ] CSS/JS/gambar termuat (DevTools → Network, tidak ada 404).
- [ ] `https://grow-up.my.id/.git/` → **404/403** (memastikan repo tidak terekspos).
- [ ] Halaman `portfolio-details.html`, `service-details.html` terbuka.
- [ ] Hard refresh (Ctrl+F5) setelah deploy untuk memastikan bukan cache browser.

## Fase 8 — Rollback

- Cepat: di laptop `git revert <commit>` → push → *Update from Remote* → *Deploy HEAD Commit*.
- Darurat: restore arsip backup `public_html` dari Fase 4 via File Manager → *Extract*.

> Deploy dengan `cp` hanya menimpa/menambah file, tidak menghapus. File yang dihapus dari repo tetap ada di `public_html` — hapus manual lewat File Manager bila perlu.

---

## Catatan penting: form kontak

`forms/contact.php` dan `forms/newsletter.php` masih bawaan template BootstrapMade: alamat penerima `contact@example.com` dan butuh library *PHP Email Form* (versi pro) yang **tidak ada** di repo. Setelah deploy, form akan menampilkan error "Unable to load the PHP Email Form Library". Pilihan:

1. Beli versi pro & taruh library di `assets/vendor/php-email-form/`, ganti email penerima ke alamat `@grow-up.my.id` (buat di cPanel → Email Accounts).
2. Ganti dengan skrip PHP `mail()` sederhana / layanan form pihak ketiga (Formspree, dsb.).
3. Sembunyikan form sementara.

## Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| Tombol *Deploy* abu-abu | `.cpanel.yml` belum ter-commit di root, atau working tree di server kotor (ada file diubah langsung di `~/repositories/grow-up`). Jalankan `git status` di Terminal cPanel. |
| Deploy "sukses" tapi situs tidak berubah | `CPANEL_USERNAME` belum diganti, `index.php` default masih ada, atau cache browser/Cloudflare. |
| Clone gagal "Permission denied (publickey)" | Deploy key belum dipasang / `~/.ssh/config` salah (Fase 2). |
| SSL gagal diterbitkan | DNS belum propagasi ke IP hosting; tunggu lalu *Run AutoSSL* lagi. |
| Gambar/CSS 404 | Nama file case-sensitive di Linux (`Logo.png` ≠ `logo.png`). |

---

## Lampiran A — `.htaccess` (opsional)

```apache
# Paksa HTTPS + non-www
RewriteEngine On
RewriteCond %{HTTPS} off [OR]
RewriteCond %{HTTP_HOST} ^www\. [NC]
RewriteRule ^ https://grow-up.my.id%{REQUEST_URI} [L,R=301]

# Blokir akses ke file tersembunyi (.git, .cpanel.yml, dll.)
RedirectMatch 404 /\.(?!well-known)

# Cache aset statis
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/jpeg "access plus 1 month"
  ExpiresByType image/png "access plus 1 month"
  ExpiresByType text/css "access plus 1 week"
  ExpiresByType application/javascript "access plus 1 week"
  ExpiresByType font/woff2 "access plus 1 year"
</IfModule>
```

Kalau `.htaccess` ini ikut di-deploy, tambahkan `- /bin/cp .htaccess $DEPLOYPATH` ke `.cpanel.yml`. Perhatikan: jika `public_html` sudah punya `.htaccess` dari hosting (mis. pengaturan versi PHP), gabungkan isinya, jangan ditimpa begitu saja.
