#Requires -Version 5.1
# Integration tests for the validation runner. Each test starts the real runner in a new Windows PowerShell process,
# against a small sample tree inside TestDrive or against the repository itself (read-only).

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $runnerPath = Join-Path $repoRoot 'scripts\Invoke-Validation.ps1'
    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false

    function Write-SampleFile {
        param([string] $Root, [string] $RelativePath, [string] $Content)

        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content, $utf8NoBom)
    }

    function Invoke-Runner {
        param([string] $Root)

        $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $runnerPath)
        if ($Root) {
            $arguments += @('-Root', $Root)
        }
        $ErrorActionPreference = 'Continue'
        $output = & $powershellPath @arguments 2>&1 | ForEach-Object { "$_" }

        [pscustomobject] @{
            ExitCode = $LASTEXITCODE
            Output   = $output -join [Environment]::NewLine
        }
    }

    $goodRoot = Join-Path $TestDrive 'good'
    Write-SampleFile $goodRoot 'scripts\Good.ps1' "`$path = Join-Path `$env:LOCALAPPDATA 'nvim'`r`n"
    Write-SampleFile $goodRoot 'docs\README.md' "# Notes`n"
    Write-SampleFile $goodRoot 'config\init.lua' "-- lua`n"

    $badRoot = Join-Path $TestDrive 'bad'
    Write-SampleFile $badRoot 'scripts\Bad.ps1' "`$a = 1`r`n`$b = `$a ?? 1`r`n"
    Write-SampleFile $badRoot 'config\init.lua' ("`nlocal p = '" + 'C:' + '\Users\' + "alice'`n")
    $bomPath = Join-Path $badRoot 'docs\Bom.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $bomPath) -Force | Out-Null
    [System.IO.File]::WriteAllBytes($bomPath, [byte[]] (0xEF, 0xBB, 0xBF, 0x61, 0x0A))
}

Describe 'Invoke-Validation.ps1' {
    It 'exits 0 when every check passes' {
        $run = Invoke-Runner -Root $goodRoot

        $run.ExitCode | Should -Be 0
        $run.Output | Should -BeLike '*PASS  PowerShell 5.1 syntax*'
        $run.Output | Should -BeLike '*PASS  No hardcoded user paths*'
        $run.Output | Should -BeLike '*PASS  UTF-8 without BOM*'
    }

    It 'exits 1 and reports each failure with file and line' {
        $run = Invoke-Runner -Root $badRoot

        $run.ExitCode | Should -Be 1
        $run.Output | Should -BeLike '*FAIL  PowerShell 5.1 syntax*'
        $run.Output | Should -BeLike '*scripts\Bad.ps1:2: *'
        $run.Output | Should -BeLike '*FAIL  No hardcoded user paths*'
        $run.Output | Should -BeLike '*config\init.lua:2: *'
        $run.Output | Should -BeLike '*FAIL  UTF-8 without BOM*'
        $run.Output | Should -BeLike '*docs\Bom.md:1: *'
    }

    It 'exits 2 when the root folder does not exist' {
        $run = Invoke-Runner -Root (Join-Path $TestDrive 'missing')

        $run.ExitCode | Should -Be 2
        $run.Output | Should -BeLike '*not found*'
    }

    It 'passes on the repository by default' {
        $run = Invoke-Runner

        $run.Output | Should -Not -BeLike '*FAIL*'
        $run.ExitCode | Should -Be 0
    }
}
