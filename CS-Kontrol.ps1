# CS2 kasma kontrolü ve düzeltme
#   CS-Kontrol.bat : yalnızca kontrol eder. CS2 açıkken çalıştırırsan ısınma ve ping'i de ölçer.
#   CS-Duzelt.bat  : kontrol eder, bulunan her düzeltme için tek tek E/H sorar (yönetici izni ister).
#   CS-GeriAl.bat  : CS-Duzelt'in değiştirdiği ayarları eski haline getirir.
#   CS-Panel.bat   : hepsini tek pencereden yönetir (bu script'i -Sessiz ile çağırır).
# -Sessiz  : ekrana yazmaz, sonucu nesne olarak döndürür (panel için).
# -Secilen : yalnızca adı verilen düzeltmeleri sormadan uygular (panel için).
param([int]$Saniye = 30, [switch]$Duzelt, [switch]$Deneme, [switch]$GeriAl, [switch]$Sessiz, [string[]]$Secilen)

$ErrorActionPreference = 'SilentlyContinue'
$script:sonuclar = New-Object System.Collections.Generic.List[object]
$script:bolum = ''
$script:bulgular = New-Object System.Collections.Generic.List[object]
$script:duzeltmeler = New-Object System.Collections.Generic.List[object]
$script:elle = New-Object System.Collections.Generic.List[string]
$yedekDosya = Join-Path $PSScriptRoot 'CS-Kontrol-yedek.json'
$baslangicOnayYolu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$gpuTercihYolu = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'

# ---------------- Yardımcılar ----------------
function Yaz([string]$seviye, [string]$mesaj) {
    $script:sonuclar.Add([pscustomobject]@{ Bolum = $script:bolum; Seviye = $seviye; Mesaj = $mesaj })
    if (-not $Sessiz) {
        $renk = @{ 'TAMAM' = 'Green'; 'UYARI' = 'Yellow'; 'SORUN' = 'Red'; 'BİLGİ' = 'Cyan'; 'NOT' = 'Gray' }[$seviye]
        if ($seviye -eq 'NOT') { Write-Host "        $mesaj" }
        else {
            Write-Host ("[{0,-5}] " -f $seviye) -ForegroundColor $renk -NoNewline
            Write-Host $mesaj
        }
    }
    if ($seviye -eq 'UYARI' -or $seviye -eq 'SORUN') {
        $script:bulgular.Add([pscustomobject]@{ Seviye = $seviye; Mesaj = $mesaj })
    }
}
function Baslik([string]$t) {
    $script:bolum = $t
    if (-not $Sessiz) { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor White }
}
function SessizSonuc {
    [pscustomobject]@{ CsPanelSonucu = $true; Sonuclar = $script:sonuclar.ToArray(); Duzeltmeler = $script:duzeltmeler.ToArray(); Elle = $script:elle.ToArray() }
}
function Sayi($s) { $v = 0; if ([int]::TryParse((("$s") -replace '[^\d-]', ''), [ref]$v)) { $v } else { $null } }
function Alan($satirlar, [string]$etiket) {
    foreach ($s in $satirlar) { if ($s -match "^\s*($etiket)\s*:\s*(.+?)\s*$") { return $Matches[2] } }
}
function KanaldanBant([int]$k) { if ($k -ge 1 -and $k -le 14) { '2.4 GHz' } elseif ($k -ge 32) { '5 GHz' } }
function PingOzet($dizi) {
    $dizi = @($dizi)
    $ok = @($dizi | Where-Object { $_ -ge 0 })
    $kayip = if ($dizi.Count) { [math]::Round(100 * ($dizi.Count - $ok.Count) / $dizi.Count, 1) } else { 0 }
    if ($ok.Count -eq 0) { return [pscustomobject]@{ Ort = $null; Max = $null; Jitter = $null; Kayip = $kayip } }
    $j = 0; for ($i = 1; $i -lt $ok.Count; $i++) { $j += [math]::Abs($ok[$i] - $ok[$i - 1]) }
    [pscustomobject]@{
        Ort    = [math]::Round(($ok | Measure-Object -Average).Average, 1)
        Max    = ($ok | Measure-Object -Maximum).Maximum
        Jitter = if ($ok.Count -gt 1) { [math]::Round($j / ($ok.Count - 1), 1) } else { 0 }
        Kayip  = $kayip
    }
}
function Duzeltme([string]$tur, [string]$ad, $veri) {
    $script:duzeltmeler.Add([pscustomobject]@{ Tur = $tur; Ad = $ad; Veri = $veri })
}
function Elle([string]$m) { if (-not $script:elle.Contains($m)) { $script:elle.Add($m) } }

function KayitOku([string]$yol, [string]$ad) {
    $k = Get-Item -LiteralPath $yol
    if ($k -and ($k.GetValueNames() -contains $ad)) {
        return [pscustomobject]@{ Var = $true; Deger = $k.GetValue($ad); Tip = $k.GetValueKind($ad).ToString() }
    }
    [pscustomobject]@{ Var = $false; Deger = $null; Tip = $null }
}
function KayitYaz([string]$yol, [string]$ad, $deger, [string]$tip) {
    if (-not (Test-Path -LiteralPath $yol)) { New-Item -Path $yol -Force -ErrorAction Stop | Out-Null }
    if ($tip -eq 'Binary') { $deger = [byte[]]@($deger) }
    elseif ($tip -eq 'DWord') { $deger = [int]$deger }
    New-ItemProperty -LiteralPath $yol -Name $ad -Value $deger -PropertyType $tip -Force -ErrorAction Stop | Out-Null
}
function NetshCalistir([string]$argumanlar) {
    $cikti = cmd.exe /c "netsh $argumanlar" 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($cikti | Where-Object { $_ }) -join ' ') }
    $cikti
}
function GucPlaniGuid { if (((powercfg /getactivescheme) -join ' ') -match '([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})') { $Matches[1] } }
function Cs2Yolu {
    $p = (Get-Process cs2 | Select-Object -First 1).Path
    if ($p) { return $p }
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
    if (-not $steam) { return $null }
    $kutuphaneler = @($steam)
    foreach ($s in (Get-Content -LiteralPath (Join-Path $steam 'steamapps\libraryfolders.vdf'))) {
        if ($s -match '"path"\s+"(.+?)"') { $kutuphaneler += ($Matches[1] -replace '\\\\', '\') }
    }
    foreach ($k in $kutuphaneler) {
        $y = Join-Path $k 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'
        if (Test-Path -LiteralPath $y) { return (Resolve-Path -LiteralPath $y).Path }
    }
}

# Bir düzeltmeyi uygular, geri alma kayıtlarını döndürür
function Uygula($d) {
    $v = $d.Veri
    switch ($d.Tur) {
        'Kayit' {
            foreach ($x in @($v)) {
                $eski = KayitOku $x.Yol $x.Ad
                KayitYaz $x.Yol $x.Ad $x.Deger $x.Tip
                [pscustomobject]@{ Tur = 'Kayit'; Yol = $x.Yol; Ad = $x.Ad; EskiVar = $eski.Var; Eski = $eski.Deger; EskiTip = $eski.Tip }
            }
        }
        'GucPlani' {
            $eski = GucPlaniGuid
            powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # Bazı laptoplarda Yüksek Performans planı gizlidir; Nihai Performans planı oluşturulur
                $yeni = if (((powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' ') -match '([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})') { $Matches[1] }
                if (-not $yeni) { throw 'Yüksek performans planı etkinleştirilemedi' }
                powercfg /setactive $yeni | Out-Null
            }
            [pscustomobject]@{ Tur = 'GucPlani'; Eski = $eski }
        }
        'Surec' {
            Get-Process -Name $v | Stop-Process -Force
            Start-Sleep -Seconds 1
            if (Get-Process -Name $v) { throw 'bazı parçaları kapanmadı, programın kendi menüsünden çık' }
        }
        'WifiManuel' {
            NetshCalistir "wlan set profileparameter name=`"$v`" connectionmode=manual" | Out-Null
            [pscustomobject]@{ Tur = 'WifiManuel'; Profil = $v }
        }
        'WifiBaglan' {
            NetshCalistir "wlan connect name=`"$v`"" | Out-Null
        }
    }
}
function GeriYukle($k) {
    switch ($k.Tur) {
        'Kayit' {
            if ($k.EskiVar) { KayitYaz $k.Yol $k.Ad $k.Eski $k.EskiTip }
            else { Remove-ItemProperty -LiteralPath $k.Yol -Name $k.Ad -ErrorAction Stop }
        }
        'GucPlani' { if ($k.Eski) { powercfg /setactive $k.Eski | Out-Null } }
        'WifiManuel' { NetshCalistir "wlan set profileparameter name=`"$($k.Profil)`" connectionmode=auto" | Out-Null }
    }
}
function YedekOku {
    $liste = @()
    if (Test-Path -LiteralPath $yedekDosya) {
        foreach ($i in (Get-Content -Raw -LiteralPath $yedekDosya -Encoding UTF8 | ConvertFrom-Json)) { $liste += $i }
    }
    , $liste
}
function YedekEkle($yeni) {
    $liste = YedekOku
    $liste += $yeni
    ConvertTo-Json -InputObject @($liste) -Depth 6 | Set-Content -LiteralPath $yedekDosya -Encoding UTF8
}

# ---------------- Geri alma modu ----------------
if ($GeriAl) {
    Baslik 'Geri alma'
    $liste = YedekOku
    if (-not $liste.Count) {
        Yaz 'BİLGİ' 'Geri alınacak bir değişiklik yok.'
        if ($Sessiz) { return SessizSonuc } else { return }
    }
    [array]::Reverse($liste)
    $hata = 0
    foreach ($k in $liste) {
        try { GeriYukle $k; Yaz 'TAMAM' "Geri alındı: $($k.Aciklama)" }
        catch { $hata++; Yaz 'SORUN' "Geri alınamadı: $($k.Aciklama) ($($_.Exception.Message))" }
    }
    if ($hata -eq 0) {
        Rename-Item -LiteralPath $yedekDosya -NewName ('CS-Kontrol-yedek-geri-alindi-{0:yyyyMMdd-HHmmss}.json' -f (Get-Date))
    }
    Yaz 'BİLGİ' 'Kapatılan programlar geri alınmaz; bilgisayarı yeniden başlatınca ya da programı açınca geri gelirler.'
    if ($Sessiz) { return SessizSonuc } else { return }
}

$mod = if ($Duzelt) { 'kontrol + düzeltme (her adımda sorar)' } elseif ($Deneme) { 'deneme: hiçbir şey değiştirilmez' } else { 'yalnızca kontrol, hiçbir şey değiştirilmez' }
if (-not $Sessiz) { Write-Host "CS2 kasma kontrolü - $mod" -ForegroundColor White }

# ---------------- Güç ----------------
Baslik 'Güç'
$plan = (powercfg /getactivescheme) -join ' '
$planAd = if ($plan -match '\((.+)\)') { $Matches[1] } else { $plan }
if ($planAd -eq 'CS Sessiz') {
    Yaz 'UYARI' 'Sessiz mod açık: işlemci yarıya sınırlı, oyunda FPS düşer'
    Elle 'Oynayacaksan paneldeki "Sessiz modu kapat" düğmesine bas.'
}
elseif ($plan -match 'erforman|Ultimate|High|Nihai') { Yaz 'TAMAM' "Güç planı: $planAd" }
else {
    Yaz 'UYARI' "Güç planı: $planAd"
    Duzeltme 'GucPlani' 'Güç planını Yüksek Performans yap' $null
}
$pil = Get-CimInstance Win32_Battery | Select-Object -First 1
if ($pil) {
    if ($pil.BatteryStatus -in 2, 3, 6, 7, 8, 9) { Yaz 'TAMAM' 'Şarj aleti takılı' }
    else { Yaz 'SORUN' 'Pille çalışıyor: ekran kartı ve işlemci yavaşlar'; Elle 'Oynarken şarj aletini tak.' }
}

# ---------------- Windows oyun ayarları ----------------
Baslik 'Windows oyun ayarları'
if ((KayitOku 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled').Deger -eq 0) {
    Yaz 'UYARI' 'Oyun Modu kapalı'
    Duzeltme 'Kayit' 'Oyun Modunu aç' @(@{ Yol = 'HKCU:\Software\Microsoft\GameBar'; Ad = 'AutoGameModeEnabled'; Tip = 'DWord'; Deger = 1 })
} else { Yaz 'TAMAM' 'Oyun Modu açık' }

$dvr = KayitOku 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
$yakala = KayitOku 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
if ($dvr.Deger -eq 1 -or $yakala.Deger -eq 1) {
    Yaz 'UYARI' 'Windows arka plan oyun kaydı açık'
    Duzeltme 'Kayit' 'Windows arka plan oyun kaydını kapat' @(
        @{ Yol = 'HKCU:\System\GameConfigStore'; Ad = 'GameDVR_Enabled'; Tip = 'DWord'; Deger = 0 },
        @{ Yol = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Ad = 'AppCaptureEnabled'; Tip = 'DWord'; Deger = 0 })
} else { Yaz 'TAMAM' 'Windows arka plan oyun kaydı kapalı' }

$cs2Yol = Cs2Yolu
if ($cs2Yol) {
    $tercih = KayitOku $gpuTercihYolu $cs2Yol
    if ("$($tercih.Deger)" -match 'GpuPreference=2') { Yaz 'TAMAM' 'CS2 Windows grafik ayarında "Yüksek performans" (NVIDIA) olarak işaretli' }
    else {
        Yaz 'UYARI' 'CS2 için Windows grafik tercihi ayarlı değil: laptopta zayıf Intel grafikte açılabilir'
        $yeniDeger = (("$($tercih.Deger)" -replace 'GpuPreference=\d;', '') + 'GpuPreference=2;')
        Duzeltme 'Kayit' 'CS2''yi her zaman NVIDIA ekran kartında çalıştır' @(@{ Yol = $gpuTercihYolu; Ad = $cs2Yol; Tip = 'String'; Deger = $yeniDeger })
    }
} else { Yaz 'BİLGİ' 'CS2 kurulumu bulunamadı, grafik tercihi kontrol edilmedi' }

# ---------------- RAM ve disk ----------------
Baslik 'RAM ve disk'
$os = Get-CimInstance Win32_OperatingSystem
$bosRam = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$topRam = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
if ($bosRam -lt 2) { Yaz 'SORUN' "Boş RAM çok az: $bosRam / $topRam GB" } else { Yaz 'TAMAM' "Boş RAM: $bosRam / $topRam GB" }
$moduller = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object { [math]::Round($_.Capacity / 1GB) })
if (($moduller | Select-Object -Unique).Count -gt 1) {
    Yaz 'BİLGİ' ("RAM modülleri farklı boyutta ({0} GB): çift kanal tam çalışmaz, etkisi küçük" -f ($moduller -join ' + '))
}
$suruculer = @('C')
if ($cs2Yol) { $suruculer += $cs2Yol.Substring(0, 1) }
foreach ($h in ($suruculer | Select-Object -Unique)) {
    $bos = [math]::Round((Get-PSDrive $h).Free / 1GB, 1)
    if ($bos -lt 15) { Yaz 'UYARI' "${h}: sürücüsünde az yer var: $bos GB"; Elle "${h}: sürücüsünde yer aç (en az 15 GB boş olsun)." }
    else { Yaz 'TAMAM' "${h}: sürücüsü boş alan: $bos GB" }
}

# ---------------- Arka plan programları ----------------
Baslik 'Arka plan programları'
$izlenen = [ordered]@{
    'SteelSeries GG'          = @('SteelSeriesGG', 'SteelSeriesGGEZ', 'SteelSeriesEngine', 'SteelSeriesPrism')
    'Logitech G HUB'          = @('lghub_agent', 'lghub', 'lghub_system_tray')
    'OMEN Light Studio (RGB)' = @('LightStudio-background', 'LightStudioHelper')
    'Plex Media Server'       = @('Plex Media Server')
    'Epic Games Launcher'     = @('EpicGamesLauncher')
    'Torrent programı'        = @('btweb', 'BitTorrent', 'uTorrent', 'qbittorrent')
}
$calisan = @(Get-Process | Select-Object -ExpandProperty ProcessName -Unique)
$bulundu = $false
foreach ($ad in $izlenen.Keys) {
    $acik = @($izlenen[$ad] | Where-Object { $calisan -contains $_ })
    if ($acik.Count) {
        $bulundu = $true
        if ($ad -eq 'Torrent programı') { Yaz 'SORUN' 'Torrent programı çalışıyor: interneti ve diski meşgul eder' }
        else { Yaz 'UYARI' "Çalışıyor: $ad" }
        Duzeltme 'Surec' "Şimdilik kapat: $ad (bilgisayar yeniden açılınca geri gelir)" $acik
    }
}
if (-not $bulundu) { Yaz 'TAMAM' 'Bilinen ağır arka plan programı yok' }
if ($calisan -contains 'SteelSeriesGG') { Elle 'SteelSeries GG kullanıyorsan içindeki Moments (otomatik kayıt) özelliğini kapat.' }

Baslik 'Windows açılışında başlayan programlar'
$runAnahtar = Get-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$agirBaslangic = 'btweb|BitTorrent|uTorrent|qBittorrent|Plex|EpicGames|Opera'
$acilista = 0
foreach ($ad in @($runAnahtar.GetValueNames())) {
    if ($ad -notmatch $agirBaslangic) { continue }
    $onay = KayitOku $baslangicOnayYolu $ad
    $kapali = $onay.Var -and $onay.Deger -and ((([byte[]]$onay.Deger)[0] -band 1) -eq 1)
    if (-not $kapali) {
        $acilista++
        Yaz 'UYARI' "Açılışta başlıyor: $ad"
        Duzeltme 'Kayit' "Açılışta başlamasın: $ad (Görev Yöneticisi > Başlangıç'taki 'Devre dışı' ile aynı)" @(
            @{ Yol = $baslangicOnayYolu; Ad = $ad; Tip = 'Binary'; Deger = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) })
    }
}
if (-not $acilista) { Yaz 'TAMAM' 'Açılışta gereksiz ağır program başlamıyor' }

# ---------------- Ağ ----------------
Baslik 'İnternet bağlantısı'
$kablo = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.PhysicalMediaType -notmatch '802\.11|Wireless|Native' -and $_.InterfaceDescription -notmatch 'Wi-?Fi|Wireless|Bluetooth' }
if ($kablo) { Yaz 'TAMAM' "Kablo ile bağlı: $($kablo[0].InterfaceDescription)" }
else { Yaz 'BİLGİ' 'Kablo bağlı değil. CS için en stabil bağlantı kablodur.'; Elle 'Mümkünse modeme kablo ile bağlan (laptopta Ethernet girişi var).' }

$vpn = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'PANGP|GlobalProtect|TAP-|WireGuard|WireSock|Wintun|VPN' })
if ($vpn.Count) {
    $rota = Find-NetRoute -RemoteIPAddress 1.1.1.1 | Where-Object InterfaceAlias | Select-Object -First 1
    if ($vpn.Name -contains $rota.InterfaceAlias) { Yaz 'SORUN' "İnternet trafiği VPN'den geçiyor ($($vpn[0].InterfaceDescription))" }
    else { Yaz 'UYARI' "VPN bağlı ($($vpn[0].InterfaceDescription)), oyun trafiği ondan geçmiyor görünüyor" }
    Elle "Oynarken VPN'i (GlobalProtect) sistem tepsisinden Disconnect et. İş VPN'i olabileceği için script kapatmaz."
}

$arayuz = netsh wlan show interfaces
$ssid = Alan $arayuz 'SSID'
$bant = $null
if ($ssid) {
    $kanal = Sayi (Alan $arayuz 'Channel|Kanal')
    $bant = Alan $arayuz 'Band|Bant'
    if (-not $bant) { $bant = KanaldanBant $kanal }
    $sinyal = Sayi (Alan $arayuz 'Signal|Sinyal')
    $hiz = Alan $arayuz 'Receive rate \(Mbps\)|Alma hızı \(Mbps\)'
    Yaz 'BİLGİ' "Bağlı Wi-Fi: '$ssid'  |  $bant, kanal $kanal, sinyal %$sinyal, hız $hiz Mbps"
    if ($bant -match '^2') { Yaz 'SORUN' "2.4 GHz'e bağlısın: ping dalgalanır" } else { Yaz 'TAMAM' "$bant bantta bağlısın" }
    if ($sinyal -lt 40) { Yaz 'SORUN' "Wi-Fi sinyali zayıf: %$sinyal" } elseif ($sinyal -lt 60) { Yaz 'UYARI' "Wi-Fi sinyali orta: %$sinyal" }
    if ($kanal -ge 52 -and $kanal -le 144) {
        Yaz 'BİLGİ' "Kanal $kanal bir DFS kanalı: modem radar algılarsa bağlantı birkaç saniye kopabilir"
        Elle 'Oyunda ara ara kopma yaşıyorsan modemin arayüzünden 5 GHz kanalını 36-48 arasına sabitle.'
    }
} else { Yaz 'BİLGİ' 'Wi-Fi bağlı değil' }

# Kayıtlı ve görünen ağların gerçek bandı (adında 5G yazıp yazmamasından bağımsız)
Baslik 'Wi-Fi ağlarının gerçek bandı'
$kayitli = @(netsh wlan show profiles | ForEach-Object { if ($_ -match '^\s+\S.*?\s:\s(.+?)\s*$') { $Matches[1] } })
$aglar = @{}
$mevcut = $null; $b = $null
foreach ($s in (netsh wlan show networks mode=bssid)) {
    if ($s -match '^SSID \d+\s*:\s*(.*)$') {
        $mevcut = $Matches[1].Trim(); $b = $null
        if ($mevcut -and -not $aglar.ContainsKey($mevcut)) { $aglar[$mevcut] = New-Object System.Collections.ArrayList }
        continue
    }
    if (-not $mevcut) { continue }
    if ($s -match '^\s+BSSID \d+\s*:') { $b = [pscustomobject]@{ Bant = $null; Kanal = 0; Sinyal = 0 }; [void]$aglar[$mevcut].Add($b); continue }
    if (-not $b) { continue }
    if ($s -match '^\s+(Signal|Sinyal)\s*:\s*(\d+)') { $b.Sinyal = [int]$Matches[2] }
    elseif ($s -match '^\s+(Band|Bant)\s*:\s*(.+?)\s*$') { $b.Bant = $Matches[2] }
    elseif ($s -match '^\s+(Channel|Kanal)\s*:\s*(\d+)') { $b.Kanal = [int]$Matches[2]; if (-not $b.Bant) { $b.Bant = KanaldanBant $b.Kanal } }
}

$adi5G = '(?i)5\s?g(hz)?(?![a-z])'
$adi24 = '(?i)2[.,]?4\s?g'
$ilgili = @($aglar.Keys | Where-Object { $kayitli -contains $_ -or $_ -eq $ssid })
$enIyi5 = $null
$yaniltici = @()
foreach ($ag in ($ilgili | Sort-Object)) {
    $liste = @($aglar[$ag])
    $var5 = @($liste | Where-Object { $_.Bant -match '^[56]' })
    $var24 = @($liste | Where-Object { $_.Bant -match '^2' })
    $ozet = ($liste | ForEach-Object { "$($_.Bant) kanal $($_.Kanal) %$($_.Sinyal)" }) -join ' | '
    $isim5 = $ag -match $adi5G
    if ($isim5 -and $var5.Count -eq 0) {
        Yaz 'UYARI' "'$ag' adında 5G yazıyor ama ASLINDA 2.4 GHz  ($ozet)"
        $yaniltici += $ag
    } elseif (-not $isim5 -and $var5.Count -gt 0 -and $var24.Count -eq 0) {
        Yaz 'BİLGİ' "'$ag' adında 5G yok ama ASLINDA 5 GHz  ($ozet)"
    } elseif (($ag -match $adi24) -and $var5.Count -gt 0) {
        Yaz 'BİLGİ' "'$ag' adında 2.4 yazıyor ama 5 GHz de yayınlıyor  ($ozet)"
    } else {
        Yaz 'NOT' "'$ag'  ($ozet)"
    }
    foreach ($x in $var5) { if (-not $enIyi5 -or $x.Sinyal -gt $enIyi5.Sinyal) { $enIyi5 = [pscustomobject]@{ Ad = $ag; Sinyal = $x.Sinyal } } }
}
if (-not $ilgili.Count) { Yaz 'NOT' 'Kayıtlı Wi-Fi ağlarından hiçbiri şu an görünmüyor.' }

if ($enIyi5 -and $ssid) {
    if ($ssid -eq $enIyi5.Ad) { Yaz 'TAMAM' "Doğru ağdasın: '$ssid' gerçek 5 GHz ağın" }
    elseif ($bant -match '^2' -and $enIyi5.Sinyal -ge 40) {
        Yaz 'SORUN' "Gerçek 5 GHz ağın '$($enIyi5.Ad)' (sinyal %$($enIyi5.Sinyal)), ama 2.4 GHz'e bağlısın"
        Duzeltme 'WifiBaglan' "Gerçek 5 GHz ağa bağlan: '$($enIyi5.Ad)' (internet 2-3 saniye kesilir)" $enIyi5.Ad
    }
}
if ($enIyi5) {
    foreach ($y in $yaniltici) {
        $profil = cmd.exe /c "netsh wlan show profile name=`"$y`"" 2>&1
        $baglanti = Alan $profil 'Connection mode|Bağlantı modu'
        if ($baglanti -match '(?i)manual|el ile|elle') { Yaz 'TAMAM' "'$y' ağına otomatik bağlanma zaten kapalı" }
        else {
            Duzeltme 'WifiManuel' "'$y' ağına otomatik bağlanmayı kapat (aslında 2.4 GHz; şifre silinmez, elle yine bağlanabilirsin)" $y
        }
    }
    if ($yaniltici.Count) { Elle 'Kalıcı çözüm: modemin arayüzünden ağ adlarını düzelt (gerçek 5 GHz olana _5G ekle, diğerinden kaldır).' }
}

# ---------------- Geçmiş kopmalar ve Steam sesi (anlık ping bunları göremez) ----------------
Baslik 'Bağlantı geçmişi ve Steam sesi'
$simdi = Get-Date
$kopmalar = @()
$wifiGunluguOkundu = $true
try {
    $kopmalar = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WLAN-AutoConfig/Operational'; StartTime = $simdi.AddHours(-24); Id = 8003 } -ErrorAction Stop | Where-Object {
        # ReasonCode 2/3: kullanıcı kesti veya başka ağa geçti, kopma sayılmaz. Mesaj metni dile göre değişir, kod değişmez.
        $kod = foreach ($alan in ([xml]$_.ToXml()).Event.EventData.Data) { if ($alan.Name -eq 'ReasonCode') { $alan.'#text' } }
        $kod -notin '2', '3'
    })
} catch { if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { $wifiGunluguOkundu = $false } }

$kopma3Saat = @($kopmalar | Where-Object { $_.TimeCreated -ge $simdi.AddHours(-3) })
if (-not $wifiGunluguOkundu) { Yaz 'NOT' 'Wi-Fi olay günlüğü okunamadı.' }
elseif ($kopma3Saat.Count -or $kopmalar.Count -ge 3) {
    Yaz 'UYARI' "Wi-Fi son 24 saatte $($kopmalar.Count) kez koptu (son 3 saatte $($kopma3Saat.Count), en son $($kopmalar[0].TimeCreated.ToString('dd.MM HH:mm'))). Anlık ping bunu göstermez."
    Elle 'Wi-Fi sık kopuyorsa: Intel Wi-Fi sürücüsünü güncelle ve Aygıt Yöneticisi > Wi-Fi bağdaştırıcısı > Güç Yönetimi''nde güç tasarrufu için kapatmayı kaldır.'
}
elseif ($kopmalar.Count) { Yaz 'BİLGİ' "Wi-Fi son 24 saatte $($kopmalar.Count) kez koptu, en son $($kopmalar[0].TimeCreated.ToString('dd.MM HH:mm')) (uyku ve modem yeniden başlaması da buna dahil)" }
else { Yaz 'TAMAM' 'Wi-Fi son 24 saatte kendiliğinden kopmamış' }

$steamYolu = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
$cefGunluk = if ($steamYolu) { Join-Path $steamYolu 'logs\cef_log.txt' }
if (-not $cefGunluk -or -not (Test-Path -LiteralPath $cefGunluk)) { Yaz 'NOT' 'Steam ses günlüğü bulunamadı.' }
else {
    # Steam sesli sohbeti WebRTC'dir; kanala bağlanamayınca günlüğe bu ICE satırı düşer. Satırda yıl yok: [pid:tid:AAGG/SSDDSS.mmm:...]
    $sesHatalari = @()
    foreach ($m in (Select-String -LiteralPath $cefGunluk -SimpleMatch 'Remapping ICE state failed')) {
        if ($m.Line -notmatch ':(\d{4})/(\d{6})\.') { continue }
        $t = [datetime]::MinValue
        if (-not [datetime]::TryParseExact("$($simdi.Year)$($Matches[1])$($Matches[2])", 'yyyyMMddHHmmss', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$t)) { continue }
        if ($t -gt $simdi.AddDays(1)) { $t = $t.AddYears(-1) }
        if ($t -ge $simdi.AddHours(-3)) { $sesHatalari += $t }
    }
    if (-not $sesHatalari.Count) { Yaz 'TAMAM' 'Steam sesli sohbette son 3 saatte bağlantı hatası görünmüyor' }
    else {
        $metin = "Steam sesli sohbet son 3 saatte $($sesHatalari.Count) kez bağlanamadı (en son $($sesHatalari[-1].ToString('HH:mm'))). Ses, ping'den ayrı bir yoldan (WebRTC/UDP) gider."
        if ($sesHatalari.Count -ge 3) { Yaz 'SORUN' $metin } else { Yaz 'UYARI' $metin }
        $tetikleyen = @($kopmalar | Where-Object { $_.TimeCreated -le $sesHatalari[0] -and $_.TimeCreated -ge $sesHatalari[0].AddMinutes(-10) })
        if ($tetikleyen.Count) { Yaz 'BİLGİ' "Ses hataları, saat $($tetikleyen[0].TimeCreated.ToString('HH:mm'))'deki Wi-Fi kopmasından sonra başlamış" }
        Elle 'Steam sesi "Bağlanıyor"da kalıyorsa: paneldeki "Steam''i yeniden başlat" düğmesiyle veya Steam > Çıkış ile tamamen kapatıp aç (CS2 lobisinden düşersin). Düzelmezse telefon hotspot''unda dene; orada çalışıyorsa sorun modemde veya internet hattındadır.'
    }
}

# ---------------- Ses aygıtı (kulaklık takınca donma) ----------------
Baslik 'Ses aygıtı'
$sesUclari = @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' })
# Realtek iki akış modunda hoparlör ve jack ayrı aygıttır; jack takılınca varsayılan aygıt oyun açıkken değişir ve CS2 sesi yeniden kurarken donabilir.
$rtHoparlor = $sesUclari | Where-Object { $_.FriendlyName -match '^Speakers? \(Realtek' }
$rtKulaklik = $sesUclari | Where-Object { $_.FriendlyName -match '^Headphones? \(Realtek' }
if ($rtHoparlor -and $rtKulaklik) {
    Yaz 'UYARI' 'Realtek hoparlör ve kulaklık jack''i ayrı aygıt olarak görünüyor. CS2 açıkken kulaklık takılınca Windows çıkışı değiştirir, oyun donabilir.'
    Elle 'Kulaklık takınca CS2 donuyorsa: Realtek Audio Console''u (yoksa Microsoft Store''dan "Realtek Audio Control" kur; "RtkAudioUniversalService" servisi çalışmalı) aç > Cihaz gelişmiş ayarları > "Harici kulaklık takıldığında dahili çıkışı sessize al" seçeneğini seç (iki ayrı akış seçeneğini değil). Olmuyorsa kulaklığı CS2''yi açmadan önce tak.'
}
elseif ($rtHoparlor) { Yaz 'TAMAM' 'Realtek hoparlör ve kulaklık tek aygıt; jack takılınca çıkış değişmez' }
else { Yaz 'NOT' 'Realtek ses aygıtı bulunamadı.' }

if ($sesUclari | Where-Object { $_.FriendlyName -match 'SteelSeries Sonar' }) {
    Yaz 'BİLGİ' 'SteelSeries Sonar sesi kendi sanal aygıtından geçiriyor; aygıt değişiminde CS2 donmasına katkı verebilir.'
    Elle 'Sonar kullanmıyorsan SteelSeries GG''den kapat; kullanıyorsan Ayarlar > Ses > Ses karıştırıcı''da cs2.exe çıkışını Sonar "Game" aygıtına sabitle.'
}

# ---------------- Canlı ölçüm (yalnızca kontrol modunda) ----------------
if (-not $Duzelt -and -not $Deneme -and -not $Sessiz -and -not $Secilen -and $Saniye -gt 0) {
    Baslik "Canlı ölçüm ($Saniye sn): ekran kartı, işlemci, ping"
    $cs2Proc = Get-Process cs2 | Select-Object -First 1
    if ($cs2Proc) {
        Write-Host 'CS2 açık. 5 saniye içinde oyuna dön ve normal oyna; ölçüm bitince bu pencereye bak.' -ForegroundColor Cyan
        Start-Sleep -Seconds 5
    } else {
        Yaz 'BİLGİ' 'CS2 kapalı. En doğru sonuç için script''i CS2 açıkken (maç içinde) çalıştır.'
    }

    $nv = Get-Command nvidia-smi
    $gw = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1).IPv4DefaultGateway.NextHop
    $pinger = New-Object System.Net.NetworkInformation.Ping
    $gpu = @(); $cpu = @(); $pGw = @(); $pNet = @()
    $bitis = (Get-Date).AddSeconds($Saniye)
    while ((Get-Date) -lt $bitis) {
        if ($nv) {
            $l = & nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,clocks.gr,clocks_throttle_reasons.sw_thermal_slowdown,clocks_throttle_reasons.hw_thermal_slowdown --format=csv,noheader,nounits | Select-Object -First 1
            $p = "$l" -split ',\s*'
            if ($p.Count -ge 5) {
                $t = Sayi $p[0]
                # Laptop kartlarında yazılımsal termal bayrağı boştayken bile "Active" görünür;
                # yalnızca yük altında ve gerçekten sıcakken ya da donanım termal sınırı devredeyse sayılır.
                $termalVar = ($p[4] -match '^Active') -or (($p[3] -match '^Active') -and $t -ge 83 -and (Sayi $p[1]) -ge 40)
                $gpu += [pscustomobject]@{ Sicaklik = $t; Kullanim = Sayi $p[1]; Saat = Sayi $p[2]; Termal = $termalVar }
            }
        }
        $c = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        if ($c) { $cpu += [pscustomobject]@{ Kullanim = [int]$c.PercentProcessorUtility; Performans = [int]$c.PercentProcessorPerformance } }
        try { if ($gw) { $r = $pinger.Send($gw, 1000); $pGw += $(if ($r.Status -eq 'Success') { [int]$r.RoundtripTime } else { -1 }) } } catch { $pGw += -1 }
        try { $r = $pinger.Send('1.1.1.1', 1000); $pNet += $(if ($r.Status -eq 'Success') { [int]$r.RoundtripTime } else { -1 }) } catch { $pNet += -1 }
        Write-Host '.' -NoNewline
        Start-Sleep -Milliseconds 700
    }
    Write-Host ''

    if ($gpu.Count) {
        $maxT = ($gpu | Measure-Object Sicaklik -Maximum).Maximum
        $ortK = [math]::Round(($gpu | Measure-Object Kullanim -Average).Average)
        $ortS = [math]::Round(($gpu | Measure-Object Saat -Average).Average)
        $termal = @($gpu | Where-Object Termal).Count
        $metin = "Ekran kartı: en yüksek $maxT°C, ortalama kullanım %$ortK, saat $ortS MHz"
        if ($maxT -ge 87) { Yaz 'SORUN' "$metin -> AŞIRI ISINMA" }
        elseif ($maxT -ge 83) { Yaz 'UYARI' "$metin -> sınıra yakın ısınma" }
        else { Yaz 'TAMAM' $metin }
        if ($termal) { Yaz 'SORUN' "Ekran kartı ısındığı için kendini yavaşlattı ($termal ölçümde)" }
        if ($maxT -ge 83 -or $termal) {
            Elle 'Isınma: OMEN Gaming Hub > Performance modu + Fan Max yap, laptopu düz masaya koy ve arkasını yükselt, fanları temizlet.'
        }
        if ($cs2Proc) {
            $nvMetin = ((& nvidia-smi --query-compute-apps=process_name --format=csv,noheader) + (& nvidia-smi)) -join ' '
            if ($nvMetin -match 'cs2') { Yaz 'TAMAM' 'CS2 şu an NVIDIA ekran kartında çalışıyor' }
            else { Yaz 'UYARI' 'CS2 şu an NVIDIA kartta görünmüyor (grafik tercihi düzeltmesini uygula, oyunu yeniden başlat)' }
        }
    } elseif (-not $nv) {
        Yaz 'UYARI' 'nvidia-smi bulunamadı: NVIDIA sürücüsü kurulu değil ya da bozuk'
        Elle 'NVIDIA sürücüsünü NVIDIA App üzerinden yeniden kur.'
    }

    if ($cpu.Count) {
        $ortCK = [math]::Round(($cpu | Measure-Object Kullanim -Average).Average)
        $ortP = [math]::Round(($cpu | Measure-Object Performans -Average).Average)
        $minP = ($cpu | Measure-Object Performans -Minimum).Minimum
        $metin = "İşlemci: ortalama kullanım %$ortCK, hız temel hızın %$ortP'i (en düşük %$minP)"
        if ($cs2Proc -and $ortP -lt 90) {
            Yaz 'UYARI' "$metin -> oyun açıkken işlemci yavaşlıyor (ısınma veya güç sınırı)"
            Elle 'Isınma: OMEN Gaming Hub > Performance modu + Fan Max yap, laptopu düz masaya koy ve arkasını yükselt, fanları temizlet.'
        } else { Yaz 'TAMAM' $metin }
        if ($ortCK -ge 90) { Yaz 'UYARI' 'İşlemci neredeyse tam dolu: arka plan programlarını kapat' }
    }

    if ($gw) {
        $g = PingOzet $pGw
        $metin = "Modeme ping ($gw): ort $($g.Ort) ms, en yüksek $($g.Max) ms, dalgalanma $($g.Jitter) ms, kayıp %$($g.Kayip)"
        # Modemler ping'e düşük öncelikle cevap verir; tek başına dalgalanma sorun sayılmaz, kayıp sayılır.
        if ($g.Kayip -gt 0) { Yaz 'SORUN' "$metin -> modem ile bilgisayar arasında paket kaybı var (Wi-Fi)" }
        elseif ($g.Ort -gt 20 -or $g.Jitter -gt 20) { Yaz 'UYARI' "$metin -> Wi-Fi bağlantısı dalgalı (bilgisayar ile modem arası)" }
        else { Yaz 'TAMAM' $metin }
    }
    $n = PingOzet $pNet
    $metin = "İnternete ping (1.1.1.1): ort $($n.Ort) ms, en yüksek $($n.Max) ms, dalgalanma $($n.Jitter) ms, kayıp %$($n.Kayip)"
    if ($n.Kayip -gt 2 -or $null -eq $n.Ort) { Yaz 'SORUN' "$metin -> paket kaybı var" }
    elseif ($n.Ort -gt 60 -or $n.Jitter -gt 15) { Yaz 'UYARI' "$metin -> ping yüksek veya dalgalı" }
    else { Yaz 'TAMAM' $metin }
}

# ---------------- Özet ----------------
if (-not $Sessiz) {
    Baslik 'ÖZET'
    if (-not $script:bulgular.Count) { Write-Host 'Belirgin bir sorun bulunmadı.' -ForegroundColor Green }
    else {
        foreach ($x in ($script:bulgular | Sort-Object { if ($_.Seviye -eq 'SORUN') { 0 } else { 1 } })) {
            Write-Host ("[{0}] {1}" -f $x.Seviye, $x.Mesaj) -ForegroundColor $(if ($x.Seviye -eq 'SORUN') { 'Red' } else { 'Yellow' })
        }
    }
}

# ---------------- Düzeltmeler ----------------
Baslik 'Otomatik düzeltilebilecekler'
if ($Secilen) {
    # Panelden gelen seçim: yalnızca adı eşleşenler, sormadan uygulanır
    $geri = @()
    foreach ($d in $script:duzeltmeler) {
        if ($Secilen -notcontains $d.Ad) { continue }
        try {
            foreach ($x in @(Uygula $d)) {
                if ($x) { $x | Add-Member -NotePropertyName Aciklama -NotePropertyValue $d.Ad -Force; $geri += $x }
            }
            Yaz 'TAMAM' "Yapıldı: $($d.Ad)"
        } catch { Yaz 'SORUN' "Yapılamadı: $($d.Ad) ($($_.Exception.Message))" }
    }
    foreach ($s in $Secilen) {
        if (-not ($script:duzeltmeler | Where-Object { $_.Ad -eq $s })) { Yaz 'BİLGİ' "Artık gerekmiyor: $s" }
    }
    if ($geri.Count) { YedekEkle $geri }
} elseif ($Sessiz) {
    # Panel listeyi kendisi gösterir
} elseif (-not $script:duzeltmeler.Count) {
    Write-Host 'Otomatik düzeltilecek bir şey yok.' -ForegroundColor Green
} elseif (-not $Duzelt) {
    $i = 0
    foreach ($d in $script:duzeltmeler) { $i++; Write-Host ("  {0}. {1}" -f $i, $d.Ad) }
    if ($Deneme) { Write-Host '[DENEME] Hiçbiri uygulanmadı.' -ForegroundColor Cyan }
    else { Write-Host 'Uygulamak için CS-Duzelt.bat''a çift tıkla; her biri için tek tek sorar.' -ForegroundColor Cyan }
} else {
    $geri = @()
    foreach ($d in $script:duzeltmeler) {
        $cevap = Read-Host "$($d.Ad)  ->  Uygulansın mı? (E/H)"
        if ($cevap -notmatch '^\s*[eEyY]') { Write-Host '        atlandı'; continue }
        try {
            foreach ($x in @(Uygula $d)) {
                if ($x) { $x | Add-Member -NotePropertyName Aciklama -NotePropertyValue $d.Ad -Force; $geri += $x }
            }
            Yaz 'TAMAM' "Yapıldı: $($d.Ad)"
        } catch { Yaz 'SORUN' "Yapılamadı: $($d.Ad) ($($_.Exception.Message))" }
    }
    if ($geri.Count) {
        YedekEkle $geri
        Write-Host "Ayar değişiklikleri kaydedildi. Geri almak için CS-GeriAl.bat'a çift tıkla." -ForegroundColor Cyan
    }
}

if ($Sessiz) { return SessizSonuc }

# ---------------- Elle yapılacaklar ----------------
if ($script:elle.Count) {
    Baslik 'Senin elle yapman gerekenler'
    $i = 0
    foreach ($m in $script:elle) { $i++; Write-Host ("  {0}. {1}" -f $i, $m) }
}
Write-Host ''
