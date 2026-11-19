function Add-AppActivationInterop {
    if ('UseGoodAI.CodexChinese.NativeActivation' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace UseGoodAI.CodexChinese
{
    public static class NativeActivation
    {
        private const uint CLSCTX_LOCAL_SERVER = 0x4;

        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(
            ref Guid rclsid,
            IntPtr pUnkOuter,
            uint dwClsContext,
            ref Guid riid,
            out IntPtr ppv);

        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate int ActivateApplicationDelegate(
            IntPtr self,
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            int options,
            out uint processId);

        public static int Activate(
            string appUserModelId,
            string arguments,
            out uint processId)
        {
            Guid clsid = new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C");
            Guid iid = new Guid("2e941141-7f97-4756-ba1d-9decde894a3d");
            IntPtr manager;
            int hr = CoCreateInstance(
                ref clsid,
                IntPtr.Zero,
                CLSCTX_LOCAL_SERVER,
                ref iid,
                out manager);
            if (hr < 0)
            {
                processId = 0;
                return hr;
            }

            try
            {
                IntPtr vtable = Marshal.ReadIntPtr(manager);
                IntPtr method = Marshal.ReadIntPtr(vtable, 3 * IntPtr.Size);
                ActivateApplicationDelegate activate =
                    (ActivateApplicationDelegate)Marshal.GetDelegateForFunctionPointer(
                        method,
                        typeof(ActivateApplicationDelegate));
                return activate(manager, appUserModelId, arguments, 0, out processId);
            }
            finally
            {
                Marshal.Release(manager);
            }
        }
    }
}
'@
}

function Get-OfficialCodexDesktop {
    $packages = @(Get-AppxPackage -Name OpenAI.Codex |
        Where-Object { $_.PackageFamilyName -ceq 'OpenAI.Codex_2p2nqsd0c76g0' -and $_.SignatureKind -eq 'Store' } |
        Sort-Object Version -Descending)
    if ($packages.Count -eq 0) { throw '找不到当前 Windows 用户安装的微软商店版 Codex。' }

    $package = $packages[0]
    [xml]$manifest = Get-AppxPackageManifest -Package $package.PackageFullName
    $application = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application'][@Id='App']")
    if (-not $application) { throw '找不到官方 Codex 桌面入口。' }
    $relativeExe = $application.GetAttribute('Executable').Replace('/', '\')
    if ($relativeExe -notmatch '^(?:[^\\/:]+\\)*(?:ChatGPT|Codex)\.exe$' -or $relativeExe -match '(?:^|\\)\.\.(?:\\|$)') {
        throw '该版 Codex 使用了未知的桌面入口。'
    }
    return @{
        Aumid = $package.PackageFamilyName + '!App'
        Executable = Join-Path $package.InstallLocation $relativeExe
        Name = Split-Path -Leaf $relativeExe
    }
}

function Get-CodexDesktopProcesses($Desktop) {
    Get-CimInstance Win32_Process -Filter ("Name='" + $Desktop.Name + "'") |
        Where-Object {
            $_.ExecutablePath -eq $Desktop.Executable -and
            $_.CommandLine -and $_.CommandLine -notmatch '(?:\s--type=|\s--crashpad-handler)'
        }
}

# Process ancestry, forced stop, and exit polling follow install/codex.ps1.
function Get-OwnProcessIds {
  $ids = @()
  $current = $PID
  while ($current -and ($ids -notcontains $current)) {
    $ids += $current
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $current" -ErrorAction Stop
    if ($process) {
      $current = $process.ParentProcessId
    } else {
      $current = 0
    }
  }
  return $ids
}

function Test-ProcessExited($Process) {
  try {
    return $Process.HasExited
  } catch {
    return $false
  }
}

function Close-ExistingCodexDesktop($Desktop) {
    $running = @(Get-CodexDesktopProcesses $Desktop)
    if ($running.Count -eq 0) { return }

    $sessionId = (Get-Process -Id $PID).SessionId
    $ownIds = @(Get-OwnProcessIds)
    if (@($running | Where-Object { $_.ProcessId -in $ownIds }).Count) {
        throw '请在 Codex 外部打开 PowerShell 后重新运行。'
    }

    $targets = @(
        foreach ($item in $running) {
            $process = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
            if ($process -and $process.SessionId -eq $sessionId -and
                $process.Path -eq $Desktop.Executable -and -not (Test-ProcessExited $process)) {
                $process
            }
        }
    )
    if ($targets.Count) {
        Write-Host '正在强制关闭 Codex 桌面版。'
        $targets | Stop-Process -Force -ErrorAction SilentlyContinue
        for ($attempt = 0; $attempt -le 10; $attempt++) {
            if ($attempt -gt 0) { Start-Sleep -Milliseconds 500 }
            $remaining = @($targets | Where-Object { -not (Test-ProcessExited $_) })
            if ($remaining.Count -eq 0) { break }
        }
    }
    if (@(Get-CodexDesktopProcesses $Desktop).Count) {
        throw 'Codex 仍在运行。请在托盘彻底退出 Codex，若 CC Switch 自动打开它，先退出 CC Switch 再重试。'
    }
}

function Start-OfficialCodexDesktop($Desktop, [string]$Arguments = '') {
    [uint32]$processId = 0
    $result = [UseGoodAI.CodexChinese.NativeActivation]::Activate($Desktop.Aumid, $Arguments, [ref]$processId)
    if ($result -lt 0 -or $processId -eq 0) {
        throw ('Windows 未能启动 Codex（HRESULT 0x{0:X8}）。' -f $result)
    }
    return $processId
}

function Get-CodexLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return $listener.LocalEndpoint.Port
    } finally {
        $listener.Stop()
    }
}

function Get-StartedDebugProcess($Desktop, [uint32]$ProcessId, [int]$Port) {
    $expected = '(?:^|\s)--remote-debugging-port=' + $Port + '(?:\s|$)'
    Get-CodexDesktopProcesses $Desktop | Where-Object {
        $_.ProcessId -eq $ProcessId -and $_.CommandLine -match $expected
    }
}

function Stop-StartedDebugProcess($Desktop, [uint32]$ProcessId, [int]$Port) {
    if (-not (Get-StartedDebugProcess $Desktop $ProcessId $Port)) {
        $remainingListener = Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Where-Object { $_.OwningProcess -eq $ProcessId -and $_.LocalPort -eq $Port }
        if ($remainingListener) {
            throw '无法确认仍在监听的进程，请从托盘彻底退出 Codex 后再打开。'
        }
        return
    }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process -or $process.HasExited) { return }
    $null = $process.CloseMainWindow()
    if ($process.WaitForExit(3000)) { return }
    if ((Get-StartedDebugProcess $Desktop $ProcessId $Port) -and -not $process.HasExited) {
        $process.Kill()
        if (-not $process.WaitForExit(5000)) { throw '调试进程未退出，请从托盘彻底退出 Codex。' }
    }
}
