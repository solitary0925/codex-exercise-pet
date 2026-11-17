param([string]$DataDirectory)

$ErrorActionPreference = 'Stop'
$startedAt = [DateTime]::UtcNow
. (Join-Path $PSScriptRoot 'Runtime.ps1')

try {
    $eventData = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if (-not $eventData.session_id -or -not $eventData.turn_id) { return }

    $runtime = Get-PetDataDirectory $DataDirectory
    $active = Join-Path $runtime 'active'
    $prefix = Get-Key "$($eventData.session_id):$($eventData.turn_id)"

    if ($eventData.hook_event_name -in 'Stop', 'Interrupt') {
        if ([IO.Directory]::Exists($active)) {
            foreach ($marker in [IO.Directory]::EnumerateFiles($active, "$prefix-*.run")) {
                [IO.File]::Delete($marker)
            }
        }
        return
    }

    if (-not $eventData.tool_use_id) { return }
    $marker = Join-Path $active "$prefix-$(Get-Key $eventData.tool_use_id).run"
    switch ($eventData.hook_event_name) {
        'PreToolUse' {
            [void][IO.Directory]::CreateDirectory($active)
            if (-not [IO.File]::Exists($marker)) {
                [IO.File]::WriteAllText($marker, '')
            }

            $runningPet = $null
            if ([Threading.Mutex]::TryOpenExisting((Get-PetMutexName $runtime), [ref]$runningPet)) {
                $runningPet.Dispose()
            } else {
                $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
                $petScript = Join-Path $PSScriptRoot 'Pet.ps1'
                $arguments = '-NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -DataDirectory "{1}" -WatchFromUtcTicks {2}' -f $petScript, $runtime, $startedAt.Ticks
                Start-Process -FilePath $windowsPowerShell -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
            }
        }
        'PostToolUse' {
            if ([IO.Directory]::Exists($active)) { [IO.File]::Delete($marker) }
        }
    }
} catch {
    # This optional notification must leave Codex's command and output alone.
} finally {
    [Console]::WriteLine('{}')
}
