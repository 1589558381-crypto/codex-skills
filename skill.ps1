param(
    [Parameter(Position = 0)]
    [ValidateSet("help","sources","list","search","info","install","install-source","remove")]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Name,

    [string]$Source,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RegistryUrl = "https://raw.githubusercontent.com/1589558381-crypto/codex-skills/main/registry/skills.json"
$InstallRoot = Join-Path (Get-Location) ".agents\skills"

function Get-Registry {
    $localCandidates = @(
        (Join-Path $PSScriptRoot "registry\skills.json"),
        (Join-Path (Split-Path $PSScriptRoot -Parent) "registry\skills.json")
    )

    foreach ($localRegistry in $localCandidates) {
        if (Test-Path $localRegistry) {
            return (Get-Content -Raw -Encoding UTF8 $localRegistry | ConvertFrom-Json)
        }
    }

    try {
        return (Invoke-RestMethod -Uri $RegistryUrl)
    }
    catch {
        throw "Unable to load the skill registry. Check your network connection or clone 1589558381-crypto/codex-skills locally. $($_.Exception.Message)"
    }
}

function Normalize-Selector {
    param([string]$Selector, [string]$ExplicitSource)

    $result = [ordered]@{ Source = $ExplicitSource; Skill = $Selector }
    if (-not $ExplicitSource -and $Selector -and $Selector.Contains("/")) {
        $parts = $Selector -split "/", 2
        $result.Source = $parts[0]
        $result.Skill = $parts[1]
    }
    return [pscustomobject]$result
}

function Get-SourceByAlias {
    param($Registry, [string]$Alias)
    $source = @($Registry.sources | Where-Object { $_.alias -ieq $Alias })
    if ($source.Count -eq 0) {
        $known = ($Registry.sources.alias -join ", ")
        throw "Unknown source '$Alias'. Available sources: $known"
    }
    return $source[0]
}

function Find-Skill {
    param($Registry, [string]$Selector, [string]$ExplicitSource)

    if (-not $Selector) { throw "A skill name is required." }
    $normalized = Normalize-Selector -Selector $Selector -ExplicitSource $ExplicitSource
    $candidates = @()

    if ($normalized.Source) {
        $src = Get-SourceByAlias -Registry $Registry -Alias $normalized.Source
        foreach ($skill in $src.skills) {
            if ($skill.name -ieq $normalized.Skill) {
                $candidates += [pscustomobject]@{ source = $src; skill = $skill }
            }
        }
    }
    else {
        foreach ($src in $Registry.sources) {
            foreach ($skill in $src.skills) {
                if ($skill.name -ieq $normalized.Skill) {
                    $candidates += [pscustomobject]@{ source = $src; skill = $skill }
                }
            }
        }
    }

    if ($candidates.Count -eq 0) {
        throw "Skill '$($normalized.Skill)' was not found. Run: .\skill.ps1 search $($normalized.Skill)"
    }

    if ($candidates.Count -gt 1) {
        $choices = ($candidates | ForEach-Object { "  $($_.source.alias)/$($_.skill.name)" }) -join [Environment]::NewLine
        throw "Skill '$($normalized.Skill)' exists in more than one source. Use a qualified name:`n$choices"
    }

    return $candidates[0]
}

function Get-DependencyPlan {
    param($SourceObject, $SkillObject)

    $plan = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    function Add-SkillWithDependencies {
        param($Skill)
        if ($seen.ContainsKey($Skill.name)) { return }

        if ($Skill.PSObject.Properties.Name -contains "dependencies") {
            foreach ($dependencyName in @($Skill.dependencies)) {
                $dep = @($SourceObject.skills | Where-Object { $_.name -ieq $dependencyName })
                if ($dep.Count -eq 0) {
                    throw "Dependency '$dependencyName' required by '$($Skill.name)' is missing from source '$($SourceObject.alias)'."
                }
                Add-SkillWithDependencies -Skill $dep[0]
            }
        }

        $seen[$Skill.name] = $true
        $plan.Add($Skill)
    }

    Add-SkillWithDependencies -Skill $SkillObject
    return $plan.ToArray()
}

function Assert-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required. Install Git for Windows first, then reopen PowerShell."
    }
}

function Invoke-Git {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

function Copy-SkillDirectory {
    param([string]$SourcePath, [string]$DestinationPath)

    New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    Get-ChildItem -Force -Path $SourcePath |
        Where-Object { $_.Name -ne ".git" } |
        ForEach-Object { Copy-Item -Recurse -Force $_.FullName $DestinationPath }
}

function Install-SkillSet {
    param($SourceObject, [object[]]$Skills, [switch]$Overwrite)

    Assert-Git
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-" + [guid]::NewGuid().ToString("N"))
    $repoUrl = "https://github.com/$($SourceObject.repo).git"

    try {
        Invoke-Git -Arguments @("clone","--filter=blob:none","--no-checkout",$repoUrl,$tempRoot)

        $paths = @($Skills | ForEach-Object { $_.path })
        if ($SourceObject.PSObject.Properties.Name -contains "supportPaths") {
            $paths += @($SourceObject.supportPaths)
        }
        $paths = @($paths | Sort-Object -Unique)
        if (-not ($paths -contains ".")) {
            Invoke-Git -Arguments @("-C",$tempRoot,"sparse-checkout","init","--cone")
            $args = @("-C",$tempRoot,"sparse-checkout","set","--cone","--") + $paths
            Invoke-Git -Arguments $args
        }

        Invoke-Git -Arguments @("-C",$tempRoot,"checkout","--detach",$SourceObject.commit)

        if ($SourceObject.PSObject.Properties.Name -contains "supportPaths") {
            foreach ($supportPath in @($SourceObject.supportPaths)) {
                $relativeSupportPath = $supportPath -replace "/", [IO.Path]::DirectorySeparatorChar
                $sourceSupportPath = Join-Path $tempRoot $relativeSupportPath
                $targetSupportPath = Join-Path $InstallRoot $relativeSupportPath

                if (-not (Test-Path $sourceSupportPath)) {
                    throw "Missing support path: $($SourceObject.repo):$supportPath"
                }

                if (Test-Path $targetSupportPath) {
                    if (-not $Overwrite) {
                        Write-Host "Skip existing support: $supportPath (use -Force to replace)"
                        continue
                    }
                    Remove-Item -Recurse -Force $targetSupportPath
                }

                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetSupportPath) | Out-Null
                Copy-Item -Recurse -Force -Path $sourceSupportPath -Destination $targetSupportPath
                Write-Host "Installed shared support: $supportPath"
            }
        }

        foreach ($skill in $Skills) {
            $relativePath = $skill.path -replace "/", [IO.Path]::DirectorySeparatorChar
            $sourcePath = if ($skill.path -eq ".") { $tempRoot } else { Join-Path $tempRoot $relativePath }
            $destination = Join-Path $InstallRoot $skill.name

            if (-not (Test-Path (Join-Path $sourcePath "SKILL.md"))) {
                throw "The indexed skill path no longer contains SKILL.md: $($SourceObject.repo):$($skill.path)"
            }

            if (Test-Path $destination) {
                if (-not $Overwrite) {
                    Write-Host "Skip existing: $($skill.name)  (use -Force to replace)"
                    continue
                }
                Remove-Item -Recurse -Force $destination
            }

            Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath $destination

            $marker = [ordered]@{
                source = $SourceObject.alias
                repository = $SourceObject.repo
                commit = $SourceObject.commit
                path = $skill.path
            } | ConvertTo-Json
            Set-Content -Path (Join-Path $destination ".codex-skill-source.json") -Value $marker -Encoding UTF8

            Write-Host "Installed: $($SourceObject.alias)/$($skill.name)"
            Write-Host "        -> $destination"
        }
    }
    finally {
        if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
    }
}

function Show-Help {
    @'
Project-local Codex skill manager

Usage:
  .\skill.ps1 sources
  .\skill.ps1 list [source]
  .\skill.ps1 search <text>
  .\skill.ps1 info <skill>
  .\skill.ps1 install <skill> [-Source <alias>] [-Force]
  .\skill.ps1 install <source/skill> [-Force]
  .\skill.ps1 install-source <source> [-Force]
  .\skill.ps1 remove <skill>

Examples:
  .\skill.ps1 install nature-writing
  .\skill.ps1 install anthropic/frontend-design
  .\skill.ps1 install kdense/literature-review
  .\skill.ps1 search citation
  .\skill.ps1 list nature
  .\skill.ps1 install-source nature

All installs go to the current project only:
  .agents\skills\
'@ | Write-Host
}

$registry = Get-Registry

switch ($Command) {
    "help" {
        Show-Help
    }

    "sources" {
        $registry.sources | ForEach-Object {
            [pscustomobject]@{
                Alias = $_.alias
                Skills = @($_.skills).Count
                Repository = $_.repo
            }
        } | Format-Table -AutoSize
    }

    "list" {
        $sources = if ($Name) { @(Get-SourceByAlias -Registry $registry -Alias $Name) } else { @($registry.sources) }
        $rows = foreach ($src in $sources) {
            foreach ($skill in $src.skills) {
                [pscustomobject]@{ Source = $src.alias; Skill = $skill.name }
            }
        }
        $rows | Sort-Object Source, Skill | Format-Table -AutoSize
    }

    "search" {
        if (-not $Name) { throw "Search text is required." }
        $rows = foreach ($src in $registry.sources) {
            foreach ($skill in $src.skills) {
                if ($skill.name -like "*$Name*" -or $src.alias -like "*$Name*" -or $src.repo -like "*$Name*") {
                    [pscustomobject]@{ Source = $src.alias; Skill = $skill.name; Selector = "$($src.alias)/$($skill.name)" }
                }
            }
        }
        if (-not $rows) { Write-Host "No matching skills." }
        else { $rows | Sort-Object Skill, Source | Format-Table -AutoSize }
    }

    "info" {
        $match = Find-Skill -Registry $registry -Selector $Name -ExplicitSource $Source
        [pscustomobject]@{
            Selector = "$($match.source.alias)/$($match.skill.name)"
            Repository = $match.source.repo
            Commit = $match.source.commit
            Path = $match.skill.path
            Dependencies = if ($match.skill.PSObject.Properties.Name -contains "dependencies") { @($match.skill.dependencies) -join ", " } else { "" }
        } | Format-List
    }

    "install" {
        $match = Find-Skill -Registry $registry -Selector $Name -ExplicitSource $Source
        $plan = Get-DependencyPlan -SourceObject $match.source -SkillObject $match.skill
        Install-SkillSet -SourceObject $match.source -Skills $plan -Overwrite:$Force
    }

    "install-source" {
        if (-not $Name) { throw "Source alias is required. Run .\skill.ps1 sources" }
        $src = Get-SourceByAlias -Registry $registry -Alias $Name
        Install-SkillSet -SourceObject $src -Skills @($src.skills) -Overwrite:$Force
    }

    "remove" {
        if (-not $Name) { throw "Skill name is required." }
        $normalized = Normalize-Selector -Selector $Name -ExplicitSource $Source
        $destination = Join-Path $InstallRoot $normalized.Skill
        if (-not (Test-Path $destination)) {
            Write-Host "Not installed: $($normalized.Skill)"
        }
        else {
            Remove-Item -Recurse -Force $destination
            Write-Host "Removed: $($normalized.Skill)"
        }
    }
}
