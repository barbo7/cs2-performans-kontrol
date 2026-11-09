# CS2 Performans Kontrol

Windows laptop veya masaüstünde **CS2 kasıyor, FPS düşüyor, ping dalgalanıyor** sorunlarının yaygın sebeplerini bulan ve istersen tek tıkla düzelten küçük bir araç.

- Kurulum gerektirmez, Windows'un kendi PowerShell'i ile çalışır.
- Hiçbir şeyi sormadan değiştirmez. Her değişikliği yedekler ve **Geri al** ile eski haline getirebilirsin.
- İnternete veri göndermez. Tek ağ kullanımı, ping ölçmek için `1.1.1.1` adresine gönderilen ping'dir.

---

## Hızlı başlangıç (3 adım)

1. **İndir:** Bu sayfanın üstündeki yeşil **Code** düğmesine tıkla, sonra **Download ZIP**'e tıkla.
2. **Klasöre çıkar:** İndirilen ZIP'e sağ tıkla → **Tümünü ayıkla** → bir klasör seç (örneğin `Belgeler\CS2-Kontrol`).
   > ZIP'in içinden çift tıklayarak çalıştırma. Dosyalar birlikte çalışıyor; önce mutlaka klasöre çıkar.
3. **Aç:** Çıkardığın klasördeki **`CS-Panel.bat`** dosyasına çift tıkla, Windows izin isterse **Evet** de.

Panel açılır ve kontrolü kendiliğinden başlatır.

---

## İlk açılışta Windows uyarı verirse

İnternetten indirilen dosyalarda Windows bazen uyarı gösterir. Bu normaldir.

| Gördüğün uyarı | Ne yapmalı |
|---|---|
| **"Windows bilgisayarınızı korudu"** (mavi pencere) | **Ek bilgi** → **Yine de çalıştır** |
| **"Bu uygulamanın cihazınızda değişiklik yapmasına izin vermek istiyor musunuz?"** | **Evet**. Panel, Wi-Fi ayarlarını değiştirebilmek için yönetici izni ister |

Uyarının her seferinde çıkmasını istemiyorsan: ZIP'i **çıkarmadan önce** sağ tıkla → **Özellikler** → alttaki **Engellemeyi kaldır** kutusunu işaretle → **Tamam**. Sonra ZIP'i klasöre çıkar.

---

## Nasıl kullanılır

### En doğru sonuç için: oyun açıkken bak

Kasma genelde oyun sırasında ısınma ya da ağ yüzünden olur, o yüzden ölçümü oyun açıkken yap:

1. CS2'yi aç ve bir maça (ya da deathmatch'e) gir.
2. `CS-Panel.bat` ile paneli aç, ikinci ekranda ya da Alt+Tab ile arada bir bak.
3. Üstteki 4 kutuyu izle:

| Kutu | Yeşil | Sarı | Kırmızı |
|---|---|---|---|
| **Ekran kartı sıcaklığı** | 83 °C altı | 83–86 °C | 87 °C ve üstü (kart kendini yavaşlatır) |
| **İşlemci kullanımı** | %75 altı | %75–89 | %90 ve üstü |
| **Ping** | 60 ms altı | 60 ms üstü | Paket kaybı var |
| **Bağlantı** | 5 GHz, iyi sinyal | Sinyal %60 altı | 2.4 GHz'e bağlısın |

### Sorunları düzeltmek

1. **Kontrol sonuçları** listesinde sarı (⚠) ve kırmızı (✖) satırlar sorunları gösterir.
2. **Düzeltilebilecekler** kutusunda uygulamak istediklerini işaretli bırak, istemediklerinin işaretini kaldır.
3. **Seçilenleri uygula**'ya bas ve onay penceresinde **Evet** de.
4. **Senin elle yapman gerekenler** kutusundakileri kendin yap. Bunlar araç tarafından değiştirilemeyen şeylerdir: fan modu, modem ayarı, VPN gibi.

### Geri almak

Paneldeki **Geri al** düğmesi ya da `CS-GeriAl.bat`, araçla değiştirilen tüm ayarları eski haline getirir. Kapatılan programlar bilgisayarı yeniden başlatınca ya da programı tekrar açınca kendiliğinden geri gelir.

---

## Dosyalar

| Dosya | Ne yapar |
|---|---|
| **`CS-Panel.bat`** | **Önerilen.** Her şeyi tek pencereden yönetir: canlı izleme, kontrol, düzeltme, geri alma |
| `CS-Kontrol.bat` | Panelsiz, yalnızca kontrol eder. CS2 açıkken çalıştırırsan 30 sn ısınma ve ping ölçer |
| `CS-Duzelt.bat` | Panelsiz düzeltme; her adım için E/H sorar |
| `CS-GeriAl.bat` | Yapılan ayar değişikliklerini geri alır |
| `CS-Kontrol.ps1`, `CS-Panel.ps1` | Asıl kod. `.bat` dosyaları bunları çalıştırır, bunlara çift tıklama |

---

## Neleri kontrol eder

- **Güç:** güç planı, şarj aleti takılı mı (laptopta pille oynamak FPS'i ciddi düşürür)
- **Windows:** Oyun Modu, arka plan oyun kaydı, CS2'nin güçlü ekran kartında (NVIDIA) çalışma tercihi
- **RAM ve disk:** boş RAM, RAM modül uyumu, boş disk alanı
- **Arka plan programları:** SteelSeries GG, Logitech G HUB, OMEN Light Studio, Plex, Epic, torrent
- **Açılışta başlayan programlar:** torrent, Plex, Epic, Opera
- **İnternet:** kablo bağlı mı, VPN açık mı, Wi-Fi bandı, sinyal, kanal
- **Wi-Fi ağlarının gerçek bandı:** Adında "5G" yazıp aslında 2.4 GHz yayın yapan ağları (ve tersini) bulur. Modemlerde ağ adları sık sık yanlış verilir.
- **Bağlantı geçmişi ve Steam sesi:** Son 24 saatteki Wi-Fi kopmalarını ve son 3 saatte Steam sesli sohbetin bağlanamadığı denemeleri bilgisayardaki günlüklerden okur. Anlık ping iyi görünse bile bu sorunları yakalar.
- **Canlı ölçüm:** ekran kartı sıcaklığı ve ısınmadan dolayı yavaşlama, işlemci hızı, modeme ve internete ping

## Neleri otomatik düzeltebilir

| Düzeltme | Kalıcı mı | Geri alınır mı |
|---|---|---|
| Güç planını Yüksek Performans yapma | Evet | Evet |
| Oyun Modunu açma, arka plan oyun kaydını kapatma | Evet | Evet |
| CS2'yi her zaman NVIDIA kartta çalıştırma | Evet | Evet |
| Açılışta başlayan ağır programları devre dışı bırakma | Evet | Evet |
| Yanıltıcı adlı 2.4 GHz ağa otomatik bağlanmayı kapatma | Evet | Evet |
| Gerçek 5 GHz ağa geçme | Hayır | Gerek yok |
| Arka plan programlarını kapatma | Hayır, yalnızca o oturum | Yeniden başlatınca geri gelir |

Ayar değişiklikleri araçla aynı klasördeki `CS-Kontrol-yedek.json` dosyasına yedeklenir. Bu dosyayı silme; geri alma bu dosyadan yapılır.

---

## Sık sorulanlar

**Panele çift tıkladım ama hiçbir şey açılmadı.**
Önce dosyaları ZIP'ten bir klasöre çıkardığından emin ol. Yine açılmıyorsa `CS-Kontrol.bat`'ı çalıştır: aynı kontrolleri siyah bir pencerede yapar ve bir hata varsa orada görünür.

**Ekran kartı kutusunda "—" ya da "NVIDIA sürücüsü bulunamadı" yazıyor.**
Sıcaklık ölçümü NVIDIA kartlarda çalışır. AMD veya yalnızca dahili grafik kullanıyorsan bu kutu boş kalır, diğer kontroller yine çalışır.

**Benim bilgisayarım HP OMEN değil, işime yarar mı?**
Evet. Kontrollerin hemen hepsi her Windows 10/11 bilgisayarda geçerlidir. OMEN'e özel olan tek şey Light Studio'yu tanımasıdır.

**VPN'imi neden kapatmıyor?**
VPN çoğu zaman iş ya da okul bağlantısıdır; araç bilerek dokunmaz, sadece uyarır. Oynarken kendin kapat.

**Güvenli mi?**
Kod açık; `.ps1` dosyalarını Not Defteri ile açıp okuyabilirsin. Araç yalnızca bu sayfadaki tablolarda yazan ayarları değiştirir ve bunları da senin onayınla yapar.

**Nasıl kaldırırım?**
Araçla bir şey değiştirdiysen önce **Geri al**'a bas, sonra klasörü sil. Başka bir yere bir şey kurulmaz.

---

## Gereksinimler

- Windows 10 veya 11 (Windows PowerShell 5.1 hazır gelir)
- Ekran kartı sıcaklığı için NVIDIA sürücüsü (`nvidia-smi`, NVIDIA sürücüsüyle birlikte gelir)
