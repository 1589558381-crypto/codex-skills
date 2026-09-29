param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/Yuan1z0825/nature-skills.git'
$targetRoot = Join-Path (Get-Location) '.agents\skills'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nature-skills-' + [guid]::NewGuid().ToString('N'))

if (-not $Name.StartsWith('nature-')) {
    throw "Nature skill names must start with 'nature-'. Example: nature-writing"
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

try {
    git clone --depth 1 --branch $Ref $repo $tempRoot | Out-Null

    $shared = Join-Path $tempRoot 'skills\nature-shared'
    $source = Join-Path $tempRoot ("skills\{0}" -f $Name)

    if (-not (Test-Path (Join-Path $source 'SKILL.md'))) {
        throw "Skill '$Name' was not found in Yuan1z0825/nature-skills at ref '$Ref'."
    }

    if (Test-Path $shared) {
        $sharedDest = Join-Path $targetRoot 'nature-shared'
        if (Test-Path $sharedDest) { Remove-Item -Recurse -Force $sharedDest }
        Copy-Item -Recurse -Force $shared $sharedDest
        Write-Host "Installed shared support to $sharedDest"
    }

    $destination = Join-Path $targetRoot $Name
    if (Test-Path $destination) { Remove-Item -Recurse -Force $destination }
    Copy-Item -Recurse -Force $source $destination
    Write-Host "Installed '$Name' to $destination"
}
finally {
    if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
}
