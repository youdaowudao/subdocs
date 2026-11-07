# 复现客户报错「基础连接已经关闭: 未能为 SSL/TLS 安全通道建立信任关系」：
# baseline 正常电脑；clock 电脑时间慢 30 天；roots 关掉根证书自动更新并删掉相关根证书。
# 每次探测都开新的 Windows PowerShell 5.1 进程跑 irm，并用 Go 程序访问同样的网址。
param(
  [Parameter(Mandatory = $true)][ValidateSet("baseline", "clock", "roots")][string]$Scenario,
  [Parameter(Mandatory = $true)][string]$Probe
)
$ErrorActionPreference = "Stop"
$docs = "https://docs.usegoodai.com/install/helper.ps1"
$api = "https://api.usegoodai.com/v1/usage"
$rows = New-Object System.Collections.Generic.List[string]

# 用 -EncodedCommand 传给新的 Windows PowerShell 5.1 进程，避免命令里的引号被改写。
function Invoke-Child([string]$Command) {
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    return (& powershell.exe -NoProfile -EncodedCommand $encoded | Out-String).Trim()
  } finally {
    $ErrorActionPreference = $previous
  }
}

function Invoke-Probes([string]$Label) {
  $irm = 'try { $r = Invoke-RestMethod -Uri "' + $docs + '" -TimeoutSec 20; "OK " + $r.Length + " chars" } catch { "ERR " + $_.Exception.Message }'
  $iwr = 'try { Invoke-WebRequest -UseBasicParsing -Uri "' + $api + '" -TimeoutSec 20 | Out-Null; "OK" } catch { "ERR " + $_.Exception.Message }'
  $irmResult = Invoke-Child $irm
  $iwrResult = Invoke-Child $iwr
  $goResult = (& $Probe $docs $api | Out-String).Trim()
  Write-Host "=== $Label（本机时间 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')）"
  Write-Host "PS5 irm docs : $irmResult"
  Write-Host "PS5 iwr api  : $iwrResult"
  Write-Host $goResult
  $rows.Add("| $Label | ``$($irmResult -replace '\|','/')`` | ``$($iwrResult -replace '\|','/')`` |")
}

function Get-Roots([string]$Subject) {
  @(Get-ChildItem Cert:\LocalMachine\AuthRoot, Cert:\LocalMachine\Root | Where-Object { $_.Subject -eq $Subject -and $_.Issuer -eq $Subject })
}

$gts = "CN=GTS Root R4, O=Google Trust Services LLC, C=US"
$globalSign = "CN=GlobalSign Root CA, OU=Root CA, O=GlobalSign nv-sa, C=BE"
$isrg = "CN=ISRG Root X1, O=Internet Security Research Group, C=US"
Write-Host "PowerShell $($PSVersionTable.PSVersion)；$((Get-CimInstance Win32_OperatingSystem).Caption)"
foreach ($subject in @($gts, $globalSign, $isrg)) {
  Write-Host ("根证书 {0}: {1} 份" -f $subject, (Get-Roots $subject).Count)
}

switch ($Scenario) {
  "baseline" {
    Invoke-Probes "正常电脑"
  }
  "clock" {
    foreach ($service in @("w32time", "vmictimesync")) {
      Stop-Service $service -Force -ErrorAction SilentlyContinue
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $start = Get-Date
    try {
      Set-Date -Date $start.AddDays(-30) | Out-Null
      Invoke-Probes "电脑时间慢 30 天"
    } finally {
      Set-Date -Date ($start + $watch.Elapsed) | Out-Null
      foreach ($service in @("vmictimesync", "w32time")) {
        Start-Service $service -ErrorAction SilentlyContinue
      }
      w32tm /resync /force 2>&1 | Out-Null
    }
    Invoke-Probes "把时间改回正确之后"
  }
  "roots" {
    $policy = "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot"
    New-Item -Path $policy -Force | Out-Null
    Set-ItemProperty -Path $policy -Name DisableRootAutoUpdate -Value 1 -Type DWord
    $saved = @{}
    foreach ($subject in @($gts, $globalSign)) {
      $found = Get-Roots $subject
      if ($found.Count -gt 0) {
        $saved[$subject] = $found[0].RawData
      }
      # 第三方根证书同时出现在 AuthRoot 和 Root 两个视图里，删掉一处另一处也没了。
      foreach ($certificate in $found) {
        Remove-Item -LiteralPath $certificate.PSPath -Force -ErrorAction SilentlyContinue
      }
      Write-Host ("删除后 {0}: {1} 份" -f $subject, (Get-Roots $subject).Count)
    }
    Invoke-Probes "关闭根证书自动更新，缺 GTS Root R4 和 GlobalSign Root CA"

    function Add-Root([string]$Subject) {
      if (-not $saved.ContainsKey($Subject)) {
        Write-Host "没有可以放回的 $Subject"
        return
      }
      $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
      $store.Open("ReadWrite")
      $store.Add((New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, $saved[$Subject])))
      $store.Close()
    }
    Add-Root $globalSign
    Invoke-Probes "关闭根证书自动更新，只缺 GTS Root R4（GlobalSign Root CA 在）"
    Add-Root $gts
    Remove-ItemProperty -Path $policy -Name DisableRootAutoUpdate
    Invoke-Probes "根证书全部放回"
  }
}

if ($env:GITHUB_STEP_SUMMARY) {
  $summary = @("### $Scenario（$env:ImageOS）", "", "| 情况 | PowerShell 5.1 irm docs | PowerShell 5.1 访问 api |", "|---|---|---|") + $rows + @("")
  $summary -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
