param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/1589558381-crypto/codex-skills.git'
$targetRoot = Join-Path (Get-Location) '.agents\skills'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-skills-' + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

try {
    git clone --depth 1 --filter=blob:none --sparse $repo $tempRoot | Out-Null
    Push-Location $tempRoot
    git sparse-checkout set ("skills/{0}" -f $Name) | Out-Null
    Pop-Location

    $source = Join-Path $tempRoot ("skills\{0}" -f $Name)
    if (-not (Test-Path (Join-Path $source 'SKILL.md'))) {
        throw "Skill '$Name' was not found in the repository."
    }

    $destination = Join-Path $targetRoot $Name
    if (Test-Path $destination) {
        Remove-Item -Recurse -Force $destination
    }
    Copy-Item -Recurse -Force $source $destination
    Write-Host "Installed '$Name' to $destination"
}
finally {
    if ((Get-Location).Path -like "$tempRoot*") { Pop-Location }
    if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
}
