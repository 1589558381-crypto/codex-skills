$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/1589558381-crypto/codex-skills.git'
$targetRoot = Join-Path (Get-Location) '.agents\skills'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-skills-' + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

try {
    git clone --depth 1 $repo $tempRoot | Out-Null
    $skillsRoot = Join-Path $tempRoot 'skills'

    Get-ChildItem -Path $skillsRoot -Directory | ForEach-Object {
        if (Test-Path (Join-Path $_.FullName 'SKILL.md')) {
            $destination = Join-Path $targetRoot $_.Name
            if (Test-Path $destination) {
                Remove-Item -Recurse -Force $destination
            }
            Copy-Item -Recurse -Force $_.FullName $destination
            Write-Host "Installed '$($_.Name)' to $destination"
        }
    }
}
finally {
    if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
}
