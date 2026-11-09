# Sessiz mod: işlemciyi sınırlayan ayrı bir güç planına geçer; ısı düşünce fanlar kendiliğinden yavaşlar.
# Fan devrini doğrudan ayarlamaz. Panel bu script'i çağırır; zamanlanmış görevler de -Ac -Zamanli / -Kapat ile çalıştırır.
#   -Ac / -Kapat                  : sessiz modu açar, önceki güç planına döner
#   -Zamanli                      : -Ac ile birlikte; saat aralığı dışındaysa açmaz, CS2 açıkken kapanmasını bekler
#   -ZamanlamaAc / -ZamanlamaKapat: gece görevlerini kurar, kaldırır
#   -Durum                        : Acik, Zamanli, Baslangic, Bitis alanlı nesne döndürür
param([switch]$Ac, [switch]$Kapat, [switch]$Zamanli, [switch]$ZamanlamaAc, [switch]$ZamanlamaKapat, [switch]$Durum)

$ErrorActionPreference = 'SilentlyContinue'
$baslangic = '01:30'
$bitis = '09:30'
$planGuid = 'c5a2e1f0-7b3d-4e6a-9c14-5e0a7d2b8f31'
$dengeliGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$islemciGrubu = '54533251-82be-4824-96c1-47b60b740d00'
$maksIslemci = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$minIslemci = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$sogutma = '94d3a615-a899-4ac5-ae2b-e4d8f634367f'
$oncekiDosya = Join-Path $PSScriptRoot 'CS-Sessiz-onceki.txt'
$gorevAc = 'CS-Panel Sessiz Ac'
$gorevKapat = 'CS-Panel Sessiz Kapat'

function AktifPlan { if (((powercfg /getactivescheme) -join ' ') -match '([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})') { $Matches[1] } }
function PlanVar([string]$guid) { [bool]((powercfg /list) -match $guid) }
function PlanHazirla {
    if (-not (PlanVar $planGuid)) {
        powercfg /duplicatescheme $dengeliGuid $planGuid | Out-Null
        powercfg /changename $planGuid 'CS Sessiz' 'Gece için işlemciyi sınırlayan sessiz mod' | Out-Null
    }
    foreach ($komut in '/setacvalueindex', '/setdcvalueindex') {
        powercfg $komut $planGuid $islemciGrubu $maksIslemci 50 | Out-Null
        powercfg $komut $planGuid $islemciGrubu $minIslemci 5 | Out-Null
        # 0 = pasif soğutma: önce işlemci yavaşlar, fan sonra hızlanır
        powercfg $komut $planGuid $islemciGrubu $sogutma 0 | Out-Null
    }
    PlanVar $planGuid
}
function SessizAc {
    if (-not (PlanHazirla)) { return $false }
    $aktif = AktifPlan
    if ($aktif -ne $planGuid) { Set-Content -LiteralPath $oncekiDosya -Value $aktif -Encoding ASCII }
    powercfg /setactive $planGuid | Out-Null
    (AktifPlan) -eq $planGuid
}
function SessizKapat {
    if ((AktifPlan) -ne $planGuid) { return $true }
    $onceki = "$(Get-Content -LiteralPath $oncekiDosya -TotalCount 1)".Trim()
    # Varlık powercfg /list ile sınanmaz: Nihai Performans gibi gizli planlar etkin değilken listede görünmez.
    if ($onceki) { powercfg /setactive $onceki | Out-Null }
    if ((AktifPlan) -eq $planGuid) { powercfg /setactive $dengeliGuid | Out-Null }
    $tamam = (AktifPlan) -ne $planGuid
    if ($tamam) { Remove-Item -LiteralPath $oncekiDosya }
    $tamam
}
function SaatAraliginda {
    $simdi = (Get-Date).TimeOfDay
    $b = [timespan]$baslangic; $e = [timespan]$bitis
    if ($b -lt $e) { $simdi -ge $b -and $simdi -lt $e } else { $simdi -ge $b -or $simdi -lt $e }
}
function ZamanlamaKur {
    $kullanici = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $ayar = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 9)
    $betik = Join-Path $PSScriptRoot 'CS-Sessiz.ps1'
    foreach ($g in @(@{ Ad = $gorevAc; Arg = '-Ac -Zamanli'; Saat = $baslangic }, @{ Ad = $gorevKapat; Arg = '-Kapat'; Saat = $bitis })) {
        $eylem = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$betik`" $($g.Arg)"
        $tetik = New-ScheduledTaskTrigger -Daily -At $g.Saat
        Register-ScheduledTask -TaskName $g.Ad -Action $eylem -Trigger $tetik -Principal $kullanici -Settings $ayar -Force | Out-Null
    }
    [bool]((Get-ScheduledTask -TaskName $gorevAc) -and (Get-ScheduledTask -TaskName $gorevKapat))
}
function ZamanlamaKaldir {
    Unregister-ScheduledTask -TaskName $gorevAc -Confirm:$false
    Unregister-ScheduledTask -TaskName $gorevKapat -Confirm:$false
    -not (Get-ScheduledTask -TaskName $gorevAc) -and -not (Get-ScheduledTask -TaskName $gorevKapat)
}

if ($Durum) {
    [pscustomobject]@{ Acik = (AktifPlan) -eq $planGuid; Zamanli = [bool](Get-ScheduledTask -TaskName $gorevAc); Baslangic = $baslangic; Bitis = $bitis }
}
elseif ($Ac) {
    if ($Zamanli) {
        while ((SaatAraliginda) -and (Get-Process cs2)) { Start-Sleep -Seconds 30 }
        if (-not (SaatAraliginda)) { return }
    }
    SessizAc
}
elseif ($Kapat) { SessizKapat }
elseif ($ZamanlamaAc) { ZamanlamaKur }
elseif ($ZamanlamaKapat) { ZamanlamaKaldir }
