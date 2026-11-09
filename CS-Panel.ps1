# CS2 Kasma Paneli: canlı izleme, kontrol, düzeltme ve geri alma tek pencerede.
# Kontrol ve düzeltmeleri aynı klasördeki CS-Kontrol.ps1 yapar; bu dosya yalnızca arayüzdür.
param([string]$TestGoruntu)

$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace CsPanel -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[CsPanel.Dpi]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$kontrolYolu = Join-Path $PSScriptRoot 'CS-Kontrol.ps1'
$yedekDosya = Join-Path $PSScriptRoot 'CS-Kontrol-yedek.json'
$yonetici = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$baslik = 'CS2 Kasma Paneli'

$renk = @{
    Yesil   = [Drawing.Color]::FromArgb(24, 128, 56)
    Sari    = [Drawing.Color]::FromArgb(176, 96, 0)
    Kirmizi = [Drawing.Color]::FromArgb(197, 34, 31)
    Mavi    = [Drawing.Color]::FromArgb(26, 103, 210)
    Gri     = [Drawing.Color]::FromArgb(95, 99, 104)
    Arka    = [Drawing.Color]::FromArgb(242, 243, 245)
    Beyaz   = [Drawing.Color]::White
}
$yazi = New-Object Drawing.Font('Segoe UI', 10)
$yaziKucuk = New-Object Drawing.Font('Segoe UI', 9)
$yaziBuyuk = New-Object Drawing.Font('Segoe UI Semibold', 20)
$yaziKalin = New-Object Drawing.Font('Segoe UI Semibold', 10)

# ---------------- Yardımcılar ----------------
function Sayi($s) { $v = 0; if ([int]::TryParse((("$s") -replace '[^\d-]', ''), [ref]$v)) { $v } else { $null } }
function Alan($satirlar, [string]$etiket) {
    foreach ($s in $satirlar) { if ($s -match "^\s*($etiket)\s*:\s*(.+?)\s*$") { return $Matches[2] } }
}
function SeviyeRengi([string]$sev) {
    switch ($sev) { 'TAMAM' { $renk.Yesil } 'UYARI' { $renk.Sari } 'SORUN' { $renk.Kirmizi } 'BİLGİ' { $renk.Mavi } default { $renk.Gri } }
}
function SeviyeEtiketi([string]$sev) {
    switch ($sev) { 'TAMAM' { '✔ Tamam' } 'UYARI' { '⚠ Uyarı' } 'SORUN' { '✖ Sorun' } 'BİLGİ' { 'ℹ Bilgi' } default { '' } }
}
function Kenar([int]$n) { New-Object Windows.Forms.Padding ([int]($n * $script:olcek)) }
function Mesaj([string]$metin, [string]$tur = 'Information') {
    [Windows.Forms.MessageBox]::Show($form, $metin, $baslik, 'OK', $tur) | Out-Null
}

# ---------------- Pencere ----------------
$form = New-Object Windows.Forms.Form
$form.Text = if ($yonetici) { $baslik } else { "$baslik  (yönetici değil: Wi-Fi düzeltmeleri çalışmayabilir)" }
$form.Font = $yazi
$form.BackColor = $renk.Arka
$form.StartPosition = 'CenterScreen'
$ekran = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Size = New-Object Drawing.Size([int]($ekran.Width * 0.62), [int]($ekran.Height * 0.86))
$form.MinimumSize = New-Object Drawing.Size([int]($ekran.Width * 0.4), [int]($ekran.Height * 0.55))
$g = $form.CreateGraphics(); $script:olcek = $g.DpiX / 96; $g.Dispose()

$kok = New-Object Windows.Forms.TableLayoutPanel
$kok.Dock = 'Fill'; $kok.ColumnCount = 1; $kok.RowCount = 4; $kok.Padding = Kenar 8
[void]$kok.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100)))
[void]$kok.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
[void]$kok.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 58)))
[void]$kok.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 42)))
[void]$kok.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
$form.Controls.Add($kok)

# Canlı izleme kutuları
$kutular = New-Object Windows.Forms.TableLayoutPanel
$kutular.Dock = 'Fill'; $kutular.AutoSize = $true; $kutular.ColumnCount = 4; $kutular.RowCount = 1
1..4 | ForEach-Object { [void]$kutular.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 25))) }
$kok.Controls.Add($kutular, 0, 0)

function YeniKutu([string]$ad, [int]$sutun) {
    $p = New-Object Windows.Forms.TableLayoutPanel
    $p.Dock = 'Fill'; $p.AutoSize = $true; $p.BackColor = $renk.Beyaz
    $p.Margin = Kenar 4; $p.Padding = Kenar 10; $p.ColumnCount = 1; $p.RowCount = 3
    $b = New-Object Windows.Forms.Label; $b.Text = $ad; $b.Font = $yaziKucuk; $b.ForeColor = $renk.Gri; $b.AutoSize = $true
    $d = New-Object Windows.Forms.Label; $d.Text = '…'; $d.Font = $yaziBuyuk; $d.AutoSize = $true
    $a = New-Object Windows.Forms.Label; $a.Text = ''; $a.Font = $yaziKucuk; $a.ForeColor = $renk.Gri; $a.AutoSize = $true
    $p.Controls.Add($b, 0, 0); $p.Controls.Add($d, 0, 1); $p.Controls.Add($a, 0, 2)
    $kutular.Controls.Add($p, $sutun, 0)
    @{ Deger = $d; Detay = $a }
}
$kGpu = YeniKutu 'EKRAN KARTI SICAKLIĞI' 0
$kCpu = YeniKutu 'İŞLEMCİ KULLANIMI' 1
$kPing = YeniKutu 'PING (1.1.1.1)' 2
$kAg = YeniKutu 'BAĞLANTI' 3

# Kontrol sonuçları
$grupSonuc = New-Object Windows.Forms.GroupBox
$grupSonuc.Text = 'Kontrol sonuçları'; $grupSonuc.Dock = 'Fill'; $grupSonuc.Padding = Kenar 8; $grupSonuc.Font = $yaziKalin
$liste = New-Object Windows.Forms.ListView
$liste.Dock = 'Fill'; $liste.View = 'Details'; $liste.FullRowSelect = $true; $liste.HeaderStyle = 'Nonclickable'
$liste.ShowItemToolTips = $true; $liste.BorderStyle = 'None'; $liste.Font = $yazi
[void]$liste.Columns.Add('Durum', [int](100 * $script:olcek))
[void]$liste.Columns.Add('Açıklama', [int](600 * $script:olcek))
$liste.Add_Resize({ $liste.Columns[1].Width = [Math]::Max(100, $liste.ClientSize.Width - $liste.Columns[0].Width - 4) })
$grupSonuc.Controls.Add($liste)
$kok.Controls.Add($grupSonuc, 0, 1)

# Düzeltmeler ve elle yapılacaklar
$alt = New-Object Windows.Forms.TableLayoutPanel
$alt.Dock = 'Fill'; $alt.ColumnCount = 2; $alt.RowCount = 1; $alt.Margin = Kenar 0
[void]$alt.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 56)))
[void]$alt.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 44)))
$kok.Controls.Add($alt, 0, 2)

$grupDuzelt = New-Object Windows.Forms.GroupBox
$grupDuzelt.Text = 'Düzeltilebilecekler: işaretle, sonra "Seçilenleri uygula"'; $grupDuzelt.Dock = 'Fill'; $grupDuzelt.Padding = Kenar 8; $grupDuzelt.Font = $yaziKalin
$duzeltmeListesi = New-Object Windows.Forms.CheckedListBox
$duzeltmeListesi.Dock = 'Fill'; $duzeltmeListesi.CheckOnClick = $true; $duzeltmeListesi.BorderStyle = 'None'
$duzeltmeListesi.HorizontalScrollbar = $true; $duzeltmeListesi.IntegralHeight = $false; $duzeltmeListesi.Font = $yazi
$grupDuzelt.Controls.Add($duzeltmeListesi)
$alt.Controls.Add($grupDuzelt, 0, 0)

$grupElle = New-Object Windows.Forms.GroupBox
$grupElle.Text = 'Senin elle yapman gerekenler'; $grupElle.Dock = 'Fill'; $grupElle.Padding = Kenar 8; $grupElle.Font = $yaziKalin
$elleKutu = New-Object Windows.Forms.TextBox
$elleKutu.Dock = 'Fill'; $elleKutu.Multiline = $true; $elleKutu.ReadOnly = $true; $elleKutu.ScrollBars = 'Vertical'
$elleKutu.BorderStyle = 'None'; $elleKutu.BackColor = $renk.Beyaz; $elleKutu.Font = $yazi
$grupElle.Controls.Add($elleKutu)
$alt.Controls.Add($grupElle, 1, 0)

# Düğmeler
$dugmeler = New-Object Windows.Forms.FlowLayoutPanel
$dugmeler.Dock = 'Fill'; $dugmeler.AutoSize = $true; $dugmeler.WrapContents = $true; $dugmeler.Padding = Kenar 2
function YeniDugme([string]$metin) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $metin; $b.AutoSize = $true; $b.Padding = New-Object Windows.Forms.Padding ([int](10 * $script:olcek)), ([int](4 * $script:olcek)), ([int](10 * $script:olcek)), ([int](4 * $script:olcek))
    $b.Margin = Kenar 4
    $dugmeler.Controls.Add($b); $b
}
$btnKontrol = YeniDugme 'Yeniden kontrol et'
$btnUygula = YeniDugme 'Seçilenleri uygula'; $btnUygula.Font = $yaziKalin
$btnGeriAl = YeniDugme 'Geri al'
$btnSteam = YeniDugme 'Steam''i yeniden başlat'
$chkCanli = New-Object Windows.Forms.CheckBox
$chkCanli.Text = 'Canlı izleme (3 sn)'; $chkCanli.Checked = $true; $chkCanli.AutoSize = $true; $chkCanli.Margin = Kenar 10
$dugmeler.Controls.Add($chkCanli)
$lblDurum = New-Object Windows.Forms.Label
$lblDurum.AutoSize = $true; $lblDurum.ForeColor = $renk.Gri; $lblDurum.Margin = Kenar 10
$dugmeler.Controls.Add($lblDurum)
$kok.Controls.Add($dugmeler, 0, 3)

# ---------------- Kontrol / düzeltme / geri alma ----------------
function Durum([string]$t) { $lblDurum.Text = $t; $lblDurum.Refresh() }
function Calistir([hashtable]$arg) {
    $form.UseWaitCursor = $true
    foreach ($b in $btnKontrol, $btnUygula, $btnGeriAl) { $b.Enabled = $false }
    [Windows.Forms.Application]::DoEvents()
    try { & $kontrolYolu @arg | Where-Object { $_.CsPanelSonucu } | Select-Object -Last 1 }
    finally { $form.UseWaitCursor = $false; $btnKontrol.Enabled = $true }
}
function SonucGoster($s) {
    $liste.BeginUpdate(); $liste.Items.Clear(); $liste.Groups.Clear()
    $gruplar = @{}; $sorun = 0; $uyari = 0
    foreach ($x in $s.Sonuclar) {
        if ($x.Bolum -eq 'Otomatik düzeltilebilecekler') { continue }
        $grup = $gruplar[$x.Bolum]
        if (-not $grup) { $grup = New-Object Windows.Forms.ListViewGroup([string]$x.Bolum); [void]$liste.Groups.Add($grup); $gruplar[$x.Bolum] = $grup }
        $oge = New-Object Windows.Forms.ListViewItem([string](SeviyeEtiketi $x.Seviye), $grup)
        [void]$oge.SubItems.Add([string]$x.Mesaj)
        $oge.ForeColor = SeviyeRengi $x.Seviye
        $oge.ToolTipText = [string]$x.Mesaj
        [void]$liste.Items.Add($oge)
        if ($x.Seviye -eq 'SORUN') { $sorun++ } elseif ($x.Seviye -eq 'UYARI') { $uyari++ }
    }
    $liste.EndUpdate()

    $duzeltmeListesi.Items.Clear()
    foreach ($d in $s.Duzeltmeler) { [void]$duzeltmeListesi.Items.Add([string]$d.Ad, $true) }
    $grupDuzelt.Text = if ($s.Duzeltmeler.Count) { "Düzeltilebilecekler ($($s.Duzeltmeler.Count)): işaretle, sonra `"Seçilenleri uygula`"" } else { 'Düzeltilebilecekler: otomatik düzeltilecek bir şey yok' }

    $i = 0
    $elleKutu.Text = if ($s.Elle.Count) { ($s.Elle | ForEach-Object { $i++; "$i. $_" }) -join "`r`n`r`n" } else { 'Yok.' }

    $btnUygula.Enabled = $s.Duzeltmeler.Count -gt 0
    $btnGeriAl.Enabled = Test-Path -LiteralPath $yedekDosya
    Durum ("{0} sorun, {1} uyarı  ·  son kontrol {2:HH:mm:ss}" -f $sorun, $uyari, (Get-Date))
}
function Kontrol {
    Durum 'Kontrol ediliyor…'
    $s = Calistir @{ Sessiz = $true; Deneme = $true }
    if ($s) { SonucGoster $s } else { Durum 'Kontrol çalışmadı: CS-Kontrol.ps1 bu dosyayla aynı klasörde olmalı' }
}
function IslemMesajlari($s, [string]$bolum) {
    @($s.Sonuclar | Where-Object { $_.Bolum -eq $bolum } | ForEach-Object { "$(SeviyeEtiketi $_.Seviye)  $($_.Mesaj)" }) -join "`r`n`r`n"
}

$btnKontrol.Add_Click({ Kontrol })

$btnUygula.Add_Click({
    $secilen = @($duzeltmeListesi.CheckedItems | ForEach-Object { [string]$_ })
    if (-not $secilen.Count) { Mesaj 'Önce uygulamak istediklerini işaretle.'; return }
    $metin = "Şunlar uygulanacak:`r`n`r`n• " + ($secilen -join "`r`n• ") + "`r`n`r`nAyar değişiklikleri yedeklenir; 'Geri al' ile eski haline dönebilirsin."
    if ([Windows.Forms.MessageBox]::Show($form, $metin, $baslik, 'YesNo', 'Question') -ne 'Yes') { return }
    Durum 'Uygulanıyor…'
    $s = Calistir @{ Sessiz = $true; Secilen = $secilen }
    $sonuc = if ($s) { IslemMesajlari $s 'Otomatik düzeltilebilecekler' } else { 'Uygulama çalışmadı.' }
    Kontrol
    Mesaj $sonuc
})

$btnGeriAl.Add_Click({
    $metin = "Paneldeki ve CS-Duzelt'teki ayar değişiklikleri eski haline getirilecek. Kapatılan programlar geri açılmaz.`r`n`r`nDevam edilsin mi?"
    if ([Windows.Forms.MessageBox]::Show($form, $metin, $baslik, 'YesNo', 'Question') -ne 'Yes') { return }
    Durum 'Geri alınıyor…'
    $s = Calistir @{ Sessiz = $true; GeriAl = $true }
    $sonuc = if ($s) { IslemMesajlari $s 'Geri alma' } else { 'Geri alma çalışmadı.' }
    Kontrol
    Mesaj $sonuc
})

# ---------------- Steam'i yeniden başlatma ----------------
function Sor([string]$metin) { [Windows.Forms.MessageBox]::Show($form, $metin, $baslik, 'YesNo', 'Warning') -eq 'Yes' }
function SteamBekle([bool]$acikOlsun, [int]$saniye) {
    $adlar = if ($acikOlsun) { @('steam') } else { @('steam', 'steamwebhelper') }
    $bitis = (Get-Date).AddSeconds($saniye)
    while ((Get-Date) -lt $bitis) {
        if ((@(Get-Process $adlar).Count -gt 0) -eq $acikOlsun) { return $true }
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 250
    }
    $false
}
function SteamYeniBaslat {
    $steamExe = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamExe
    if (-not $steamExe -or -not (Test-Path -LiteralPath $steamExe)) { Mesaj 'Steam bulunamadı.' 'Warning'; return }
    $oyunUyarisi = if (@(Get-Process cs2).Count) { "CS2 açık: oyun kapanır, maçtan ve lobiden düşersin.`r`n`r`n" } else { '' }
    if (-not (Sor "${oyunUyarisi}Steam tamamen kapatılıp yeniden açılacak. Devam edilsin mi?")) { return }

    $btnSteam.Enabled = $false
    try {
        Durum 'Steam kapatılıyor…'
        Start-Process $steamExe -ArgumentList '-shutdown'
        if (-not (SteamBekle $false 45)) {
            if (-not (Sor 'Steam 45 saniyede kapanmadı. Zorla kapatılsın mı? CS2 açıksa o da kapanır.')) { Durum 'Steam yeniden başlatılmadı'; return }
            Stop-Process -Name cs2, steam, steamwebhelper -Force
            if (-not (SteamBekle $false 10)) { Durum 'Steam kapatılamadı'; Mesaj 'Steam kapatılamadı. Görev Yöneticisi''nden kapatmayı dene.' 'Warning'; return }
        }
        Durum 'Steam açılıyor…'
        # Panel yönetici olarak çalışır; explorer üzerinden açılınca Steam normal kullanıcı yetkisiyle başlar.
        Start-Process explorer.exe -ArgumentList "`"$($steamExe -replace '/', '\')`""
        if (SteamBekle $true 20) { Durum 'Steam yeniden başlatıldı' }
        else { Durum 'Steam açılamadı'; Mesaj 'Steam kapandı ama açılamadı. Masaüstünden elle aç.' 'Warning' }
    } finally { $btnSteam.Enabled = $true }
}
$btnSteam.Add_Click({ SteamYeniBaslat })

# ---------------- Canlı izleme ----------------
$script:pinger = New-Object System.Net.NetworkInformation.Ping
$script:pingler = New-Object System.Collections.Generic.List[int]
$script:enYuksekGpu = 0
$script:nvVar = [bool](Get-Command nvidia-smi)

function KutuYaz($k, [string]$deger, [string]$detay, $r) { $k.Deger.Text = $deger; $k.Deger.ForeColor = $r; $k.Detay.Text = $detay }
function CanliGuncelle {
    # Ekran kartı
    if ($script:nvVar) {
        $p = ("$(& nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits | Select-Object -First 1)") -split ',\s*'
        $t = Sayi $p[0]; $u = Sayi $p[1]
        if ($null -ne $t) {
            if ($t -gt $script:enYuksekGpu) { $script:enYuksekGpu = $t }
            $r = if ($t -ge 87) { $renk.Kirmizi } elseif ($t -ge 83) { $renk.Sari } else { $renk.Yesil }
            KutuYaz $kGpu "$t °C" "Kullanım %$u  ·  en yüksek $($script:enYuksekGpu) °C" $r
        }
    } else { KutuYaz $kGpu '—' 'NVIDIA sürücüsü bulunamadı' $renk.Gri }

    # İşlemci
    $c = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
    if ($c) {
        $k = [int]$c.PercentProcessorUtility; $h = [int]$c.PercentProcessorPerformance
        $r = if ($k -ge 90) { $renk.Kirmizi } elseif ($k -ge 75) { $renk.Sari } else { $renk.Yesil }
        KutuYaz $kCpu "%$k" "Hız: temel hızın %$h'i" $r
    }

    # Ping (son 20 ölçüm = yaklaşık 1 dakika)
    $ms = -1
    try { $cevap = $script:pinger.Send('1.1.1.1', 800); if ($cevap.Status -eq 'Success') { $ms = [int]$cevap.RoundtripTime } } catch { }
    $script:pingler.Add($ms)
    while ($script:pingler.Count -gt 20) { $script:pingler.RemoveAt(0) }
    $ok = @($script:pingler | Where-Object { $_ -ge 0 })
    $kayip = [math]::Round(100 * ($script:pingler.Count - $ok.Count) / $script:pingler.Count)
    $ort = if ($ok.Count) { [math]::Round(($ok | Measure-Object -Average).Average) } else { '—' }
    $max = if ($ok.Count) { ($ok | Measure-Object -Maximum).Maximum } else { '—' }
    $r = if ($ms -lt 0 -or $kayip -gt 2) { $renk.Kirmizi } elseif ($ms -gt 60 -or ($ok.Count -and $ort -gt 60)) { $renk.Sari } else { $renk.Yesil }
    KutuYaz $kPing $(if ($ms -ge 0) { "$ms ms" } else { 'kayıp' }) "Son 1 dk: ort $ort · en yüksek $max · kayıp %$kayip" $r

    # Bağlantı
    $a = netsh wlan show interfaces
    $ssid = Alan $a 'SSID'
    if ($ssid) {
        $bant = Alan $a 'Band|Bant'
        $sin = Sayi (Alan $a 'Signal|Sinyal')
        $r = if ($bant -match '^2') { $renk.Kirmizi } elseif ($sin -lt 60) { $renk.Sari } else { $renk.Yesil }
        KutuYaz $kAg "$bant" "$ssid  ·  sinyal %$sin" $r
    } else {
        KutuYaz $kAg 'Wi-Fi yok' 'Kablo ile bağlıysan sorun yok' $renk.Gri
    }
}

$zaman = New-Object Windows.Forms.Timer
$zaman.Interval = 3000
$zaman.Add_Tick({ if ($chkCanli.Checked) { CanliGuncelle } })

$form.Add_Shown({
    $form.Activate()
    $form.Refresh()
    CanliGuncelle
    Kontrol
    $zaman.Start()
    if ($TestGoruntu) {
        [Windows.Forms.Application]::DoEvents(); $form.Refresh()
        $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
        $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
        $bmp.Save($TestGoruntu, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        $form.Close()
    }
})
$form.Add_FormClosing({ $zaman.Stop() })

[Windows.Forms.Application]::Run($form)
