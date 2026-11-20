param([Parameter(Mandatory)][string]$ReportDir)
$ErrorActionPreference = 'Stop'
$script:HarnessTestsRoot = $PSScriptRoot
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$prefix = $harness.Substring(0, $harness.IndexOf('# ---------- Scenario ----------')).Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
. ([scriptblock]::Create($prefix)) -Script docs/public/install/chinese.ps1 -Network online -Expect record -Auth apikey -Locale override -ReportDir $ReportDir
Install-Codex
New-Item -ItemType Directory -Force $configDir | Out-Null
@'
model_provider = "OpenAI"
model = "gpt-6.1-sol"
[model_providers.OpenAI]
name = "OpenAI"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"
requires_openai_auth = true
[desktop]
localeOverride = "zh-CN"
'@ | Set-Content $config -Encoding ASCII
@{ OPENAI_API_KEY = 'sk-ci-fake-key-not-real' } | ConvertTo-Json | Set-Content (Join-Path $configDir 'auth.json') -Encoding ASCII
$probe = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'chinese-onboarding.js'))
$null = Start-Codex '--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333'
$report.steps = @()
try {
    for ($i = 0; $i -lt 35; $i++) {
        try { $state = @(Invoke-Cdp 9333 $probe)[-1] }
        catch { $state = @{error = $_.Exception.Message} }
        $report.steps += $state
        Save-Report
        if ($i -in @(10, 20, 34)) { $report["screen_$i"] = Save-Screen "step-$i" }
        Start-Sleep -Seconds 1
    }
    if (-not @($report.steps | Where-Object { $_.done }).Count) { throw 'The app did not leave onboarding for the main screen.' }
    $report.mainConfirmed = $true
    $report.unverified = @('Main screen shows a Windows setup check failure; actual task execution is not validated.')
    $newChat = @'
(() => {
    const buttons = Array.from(document.querySelectorAll('button'));
    const b = buttons.find(x => /^(New chat|新聊天)$/.test(x.innerText.trim()) && x.getClientRects().length);
    if (b) b.click();
    return JSON.stringify({clicked: Boolean(b), editor: Boolean(document.querySelector('[contenteditable="true"]')), text: document.body.innerText.slice(0,1500)});
})()
'@
    $report.newChat = @(Invoke-Cdp 9333 $newChat)[-1]
    if (-not $report.newChat.clicked) { throw 'The main screen new-chat control was not found.' }
} finally { Stop-Codex; Save-Report }
