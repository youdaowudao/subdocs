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
    const skip = buttons.find(b => /^(Skip|跳过)$/.test(b.innerText.trim()) && !b.disabled);
    const next = buttons.find(b => /^(Continue|继续)$/.test(b.innerText.trim()) && !b.disabled);
    if (/What kind of work|你从事什么工作|按你的工作方式|哪一项最能描述你的工作/.test(text)) {
        if (skip) { action = skip.innerText; skip.click(); }
        else {
            const input = Array.from(document.querySelectorAll('input')).find(x => /engineering/i.test(x.value));
            const label = Array.from(document.querySelectorAll('label,[role="radio"],[role="option"]')).find(x => /^(工程|Engineering)$/.test(x.innerText.trim()));
            if (input && !input.checked) { action = '选择工程'; input.click(); }
            else if (label && !input?.checked) { action = '选择工程'; label.click(); }
            else if (next) { action = next.innerText; next.click(); }
        }
    } else if (skip) { action = skip.innerText; skip.click(); }
    else if (next) { action = next.innerText; next.click(); }
    return JSON.stringify({text: text.slice(0, 3500), action,
        buttons: buttons.map(b => ({text: b.innerText, label: b.getAttribute('aria-label'), testid: b.getAttribute('data-testid')})),
        inputs: Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]')).map(x => ({tag: x.tagName, type: x.type, value: x.value, checked: x.checked, parent: x.parentElement?.innerText?.slice(0,250), role: x.getAttribute('role'), placeholder: x.getAttribute('placeholder'), label: x.getAttribute('aria-label'), testid: x.getAttribute('data-testid')}))});
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
