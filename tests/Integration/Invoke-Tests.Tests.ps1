#Requires -Version 5.1
# Integration tests for the test runner. Each test starts the real runner in a new Windows PowerShell process
# against a small sample test tree inside TestDrive. Each sample test that runs leaves a marker file, so the tests
# can check exactly which sample tests the runner selected.

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $runnerPath = Join-Path $repoRoot 'scripts\Invoke-Tests.ps1'
    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $markerFolder = Join-Path $TestDrive 'markers'
    $script:originalMarkerVariable = $env:NVB_RUNNER_MARKERS

    function Write-SampleTestFile {
        param([string] $Path, [string] $Content)

        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Content -Encoding Ascii
    }

    $markerFunction = @'
function Set-Marker([string] $Name) {
    New-Item -ItemType File -Path (Join-Path $env:NVB_RUNNER_MARKERS $Name) -Force | Out-Null
}
'@

    $sampleRoot = Join-Path $TestDrive 'tests'
    Write-SampleTestFile -Path (Join-Path $sampleRoot 'Unit\UnitSample.Tests.ps1') -Content @"
BeforeAll {
$markerFunction
}
Describe 'UnitSample' {
    It 'passes' { Set-Marker 'Unit.passes' }
    It 'runs on Pester 5.9.1' { Set-Marker ('Pester-' + (Get-Module Pester).Version) }
    It 'runs with default error handling' { Set-Marker ('ErrorAction-' + `$ErrorActionPreference) }
    It 'waits for its implementation' -Tag 'NotImplemented' {
        Set-Marker 'Unit.notimplemented'
        throw 'not implemented'
    }
}
"@
    Write-SampleTestFile -Path (Join-Path $sampleRoot 'Integration\IntegrationSample.Tests.ps1') -Content @"
BeforeAll {
$markerFunction
}
Describe 'IntegrationSample' {
    It 'passes' { Set-Marker 'Integration.passes' }
}
"@
    Write-SampleTestFile -Path (Join-Path $sampleRoot 'Compatibility\CompatibilitySample.Tests.ps1') -Content @"
BeforeAll {
$markerFunction
}
Describe 'CompatibilitySample' {
    It 'passes' { Set-Marker 'Compatibility.passes' }
}
"@

    $failingRoot = Join-Path $TestDrive 'failing'
    Write-SampleTestFile -Path (Join-Path $failingRoot 'Unit\FailingSample.Tests.ps1') -Content @'
Describe 'FailingSample' {
    It 'fails' { $false | Should -BeTrue }
}
'@

    function Invoke-Runner {
        param(
            [string] $TestRoot = $sampleRoot,
            [string[]] $Arguments = @()
        )

        if (Test-Path -LiteralPath $markerFolder) {
            Get-ChildItem -LiteralPath $markerFolder | Remove-Item -Force
        }
        else {
            New-Item -ItemType Directory -Path $markerFolder | Out-Null
        }
        $env:NVB_RUNNER_MARKERS = $markerFolder

        $allArguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $runnerPath,
            '-TestRoot', $TestRoot) + $Arguments
        # The runner writes messages to stderr; collect them as text instead of stopping on them.
        $ErrorActionPreference = 'Continue'
        $output = & $powershellPath @allArguments 2>&1 | ForEach-Object { "$_" }

        [pscustomobject] @{
            ExitCode = $LASTEXITCODE
            Output   = $output -join [Environment]::NewLine
            Ran      = @(Get-ChildItem -LiteralPath $markerFolder -Name | Sort-Object)
        }
    }
}

AfterAll {
    $env:NVB_RUNNER_MARKERS = $script:originalMarkerVariable
}

Describe 'Invoke-Tests.ps1' {
    It 'runs the Unit and Integration suites by default, without NotImplemented tests, and exits 0' {
        $run = Invoke-Runner

        $run.Ran | Should -Be @('ErrorAction-Continue', 'Integration.passes', 'Pester-5.9.1', 'Unit.passes')
        $run.ExitCode | Should -Be 0
    }

    It 'runs only the Compatibility suite with -Suite Compatibility' {
        $run = Invoke-Runner -Arguments '-Suite', 'Compatibility'

        $run.Ran | Should -Be @('Compatibility.passes')
        $run.ExitCode | Should -Be 0
    }

    It 'runs every suite with -Suite All' {
        $run = Invoke-Runner -Arguments '-Suite', 'All'

        $run.Ran | Should -Be @(
            'Compatibility.passes', 'ErrorAction-Continue', 'Integration.passes', 'Pester-5.9.1', 'Unit.passes')
        $run.ExitCode | Should -Be 0
    }

    It 'runs a single test file with -Path' {
        $file = Join-Path $sampleRoot 'Integration\IntegrationSample.Tests.ps1'

        $run = Invoke-Runner -Arguments '-Path', $file

        $run.Ran | Should -Be @('Integration.passes')
        $run.ExitCode | Should -Be 0
    }

    It 'runs a single test with -TestName' {
        $run = Invoke-Runner -Arguments '-TestName', 'UnitSample.passes'

        $run.Ran | Should -Be @('Unit.passes')
        $run.ExitCode | Should -Be 0
    }

    It 'runs NotImplemented tests with -IncludeNotImplemented and exits 1 when they fail' {
        $run = Invoke-Runner -Arguments '-IncludeNotImplemented'

        $run.Ran | Should -Contain 'Unit.notimplemented'
        $run.ExitCode | Should -Be 1
    }

    It 'exits 1 when a test fails' {
        $run = Invoke-Runner -TestRoot $failingRoot

        $run.ExitCode | Should -Be 1
    }

    It 'exits 2 when -TestName selects no tests' {
        $run = Invoke-Runner -Arguments '-TestName', 'NoSuchTest*'

        $run.Ran.Count | Should -Be 0
        $run.ExitCode | Should -Be 2
        $run.Output | Should -BeLike '*No tests were selected*'
    }

    It 'exits 2 when -Path does not exist' {
        $missing = Join-Path $TestDrive 'Missing.Tests.ps1'

        $run = Invoke-Runner -Arguments '-Path', $missing

        $run.Ran.Count | Should -Be 0
        $run.ExitCode | Should -Be 2
        $run.Output | Should -BeLike "*Test path not found: $missing*"
    }
}
