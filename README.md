# CS2 Performans Kontrol

Windows laptopta CS2 kasmalarının yaygın sebeplerini bulan, isteğe bağlı olarak düzelten küçük bir araç. Kurulum gerektirmez, Windows'un kendi PowerShell'i ile çalışır.

## Kullanım

| Dosya | Ne yapar |
|---|---|
| `CS-Panel.bat` | Hepsini tek pencereden yönetir: canlı izleme, kontrol, düzeltme, geri alma |
| `CS-Kontrol.bat` | Yalnızca kontrol eder. CS2 açıkken çalıştırırsan 30 sn ısınma ve ping ölçer |
| `CS-Duzelt.bat` | Kontrol eder, her düzeltme için tek tek E/H sorar |
| `CS-GeriAl.bat` | Yapılan ayar değişikliklerini eski haline getirir |

Panel, Düzelt ve Geri Al açılırken yönetici izni ister (Wi-Fi profil ayarı için).

## Kontrol edilenler

- **Güç:** güç planı, şarj aleti takılı mı
- **Windows:** Oyun Modu, arka plan oyun kaydı, CS2'nin NVIDIA kartta çalışma tercihi
- **RAM ve disk:** boş RAM, modül uyumu, boş disk alanı
- **Arka plan:** SteelSeries GG, Logitech G HUB, OMEN Light Studio, Plex, Epic, torrent
- **Açılış programları:** torrent, Plex, Epic, Opera
- **Ağ:** kablo, VPN, Wi-Fi bandı / sinyal / DFS kanalı
- **Wi-Fi ağlarının gerçek bandı:** adında "5G" yazıp aslında 2.4 GHz olan ağları (ve tersini) bulur
- **Canlı ölçüm:** ekran kartı sıcaklığı ve termal yavaşlama, işlemci hızı, modeme ve internete ping

## Otomatik düzeltilebilenler

Güç planı, Oyun Modu, oyun kaydı, CS2 grafik tercihi, arka plan programlarını kapatma (yalnızca o oturum), açılış programlarını devre dışı bırakma, gerçek 5 GHz ağa geçme, yanıltıcı adlı 2.4 GHz ağa otomatik bağlanmayı kapatma.

Her ayar değişikliği `CS-Kontrol-yedek.json` dosyasına yedeklenir; `CS-GeriAl.bat` ya da paneldeki **Geri al** ile geri alınır. Kapatılan programlar yeniden başlatınca kendiliğinden geri gelir.

VPN, fan modu, modem ayarları gibi araçların değiştiremediği şeyler "elle yapman gerekenler" listesinde gösterilir.

## Gereksinimler

- Windows 10/11, Windows PowerShell 5.1
- Ekran kartı ölçümü için NVIDIA sürücüsü (`nvidia-smi`)
