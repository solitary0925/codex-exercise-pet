function Get-PetDataDirectory([string]$Directory) {
    if (-not $Directory) { $Directory = $env:PLUGIN_DATA }
    if (-not $Directory) { $Directory = Join-Path $env:LOCALAPPDATA 'CodexExercisePet' }
    [IO.Path]::GetFullPath($Directory)
}

function Get-Key([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Get-PetMutexName([string]$Directory) {
    'Local\CodexExercisePet-' + (Get-Key $Directory.TrimEnd('\').ToUpperInvariant())
}
