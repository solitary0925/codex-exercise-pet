# Entry point for existing 0.2.0 installs that reference this checkout.
& (Join-Path $PSScriptRoot 'plugins\codex-exercise-pet\CommandHook.ps1') -DataDirectory (Join-Path $PSScriptRoot '.runtime')
