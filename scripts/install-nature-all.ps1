param(
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/Yuan1z0825/nature-skills.git'
$targetRoot = Join-Path (Get-Location) '.agents\skills'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nature-skills-' + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

try {
    git clone --depth 1 --branch $Ref $repo $tempRoot | Out-Null
    $skillsRoot = Join-Path $tempRoot 'skills'

    Get-ChildItem -Path $skillsRoot -Directory -Filter 'nature-*' | ForEach-Object {
        $destination = Join-Path $targetRoot $_.Name
        if (Test-Path $destination) { Remove-Item -Recurse -Force $destination }
        Copy-Item -Recurse -Force $_.FullName $destination
        Write-Host "Installed '$($_.Name)' to $destination"
    }
}
finally {
    if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
}
