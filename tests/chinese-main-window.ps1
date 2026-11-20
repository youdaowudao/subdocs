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
$probe = @'
(() => {
    const text = document.body?.innerText || '';
    const buttons = Array.from(document.querySelectorAll('button')).filter(b => b.getClientRects().length);
    let action = null;
    if (/What kind of work|你从事什么工作|按你的工作方式/.test(text)) {
        const skip = buttons.find(b => /^(Skip|跳过)$/.test(b.innerText.trim()));
        if (skip) { action = skip.innerText; skip.click(); }
    }
    return JSON.stringify({text: text.slice(0, 3500), action,
        buttons: buttons.map(b => ({text: b.innerText, label: b.getAttribute('aria-label'), testid: b.getAttribute('data-testid')})),
        inputs: Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]')).map(x => ({tag: x.tagName, role: x.getAttribute('role'), placeholder: x.getAttribute('placeholder'), label: x.getAttribute('aria-label'), testid: x.getAttribute('data-testid')}))});
})()
'@
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
} finally { Stop-Codex; Save-Report }
