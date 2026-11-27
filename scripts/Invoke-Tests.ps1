#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the project's Pester test suites with Pester 5.9.1.

.DESCRIPTION
    Imports Pester 5.9.1 exactly (ADR-013) and runs the selected suites. It never falls back to another Pester
    version, such as the Windows built-in 3.4.0.

    Tests tagged 'NotImplemented' (tests written ahead of the code they test) are excluded unless
    -IncludeNotImplemented is given.

    Exit codes:
      0  All selected tests passed.
      1  At least one test, block, or test file failed.
      2  The run could not start: Pester 5.9.1 is missing, a path does not exist, or no tests were selected.

.PARAMETER Suite
    One or more suites to run: Unit, Integration, Compatibility, or All. Default: Unit and Integration.
    Ignored when -Path is given.

.PARAMETER Path
    One or more test files or folders to run instead of the suites.

.PARAMETER TestName
    Runs only tests whose full name (Describe, Context, and It names joined by '.') matches this wildcard
    pattern, for example '*elevated*'.

.PARAMETER IncludeNotImplemented
    Also runs tests tagged 'NotImplemented'.

.PARAMETER ResultPath
    Writes an NUnit XML result file to this path.

.PARAMETER TestRoot
    Folder that contains the suite folders. Default: the repository's tests folder. Used by the runner's own
    tests.

.EXAMPLE
    scripts\Invoke-Tests.ps1

.EXAMPLE
    scripts\Invoke-Tests.ps1 -Path tests\Unit\Invoke-Tests.Tests.ps1 -TestName '*missing*'
#>
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Compatibility', 'All')]
    [string[]] $Suite = @('Unit', 'Integration'),

    [string[]] $Path,

    [string] $TestName,

    [switch] $IncludeNotImplemented,

    [string] $ResultPath,

    [string] $TestRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Computed here, not as a parameter default: Windows PowerShell 5.1 leaves $PSScriptRoot empty in param defaults.
if (-not $TestRoot) {
    $TestRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'tests'
}

$script:PesterVersion = '5.9.1'
$script:AllSuites = @('Unit', 'Integration', 'Compatibility')
$script:NotImplementedTag = 'NotImplemented'

function Write-RunnerError {
    <#
    .SYNOPSIS
        Writes a message for the user to the error stream without a PowerShell error record.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Message
    )

    $Host.UI.WriteErrorLine($Message)
}

function Get-PesterInstallMessage {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @"
Pester $script:PesterVersion is required but was not found. The Windows built-in Pester 3.4.0 is not supported.
Install it for the current user from Windows PowerShell 5.1 (see README.md, "Development prerequisites"):

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force
    Install-Module -Name Pester -RequiredVersion $script:PesterVersion -Repository PSGallery -Scope CurrentUser -SkipPublisherCheck -Force
"@
}

function Import-PinnedPester {
    <#
    .SYNOPSIS
        Imports exactly the pinned Pester version, or throws with install instructions.
    #>
    [CmdletBinding()]
    param()

    $loaded = @(Get-Module -Name Pester | Where-Object { $_.Version -ne [version] $script:PesterVersion })
    if ($loaded.Count -gt 0) {
        Remove-Module -Name Pester -Force
    }

    try {
        Import-Module -Name Pester -RequiredVersion $script:PesterVersion -ErrorAction Stop
    }
    catch {
        throw (Get-PesterInstallMessage)
    }
}

function Get-TestRunPath {
    <#
    .SYNOPSIS
        Returns the files or folders to run: the -Path values, or the folders of the selected suites.
    #>
    [CmdletBinding()]
    [OutputType([string], [string[]])]
    param(
        [Parameter(Mandatory)] [string] $TestRoot,
        [string[]] $Suite = @('Unit', 'Integration'),
        [string[]] $Path
    )

    if ($Path) {
        foreach ($item in $Path) {
            if (-not (Test-Path -LiteralPath $item)) {
                throw "Test path not found: $item"
            }
        }
        return $Path
    }

    $selected = if ($Suite -contains 'All') { $script:AllSuites } else { $Suite | Select-Object -Unique }
    foreach ($name in $selected) {
        $folder = Join-Path $TestRoot $name
        if (Test-Path -LiteralPath $folder -PathType Container) {
            $folder
        }
    }
}

function Get-TestRunConfiguration {
    <#
    .SYNOPSIS
        Builds the Pester configuration for a run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $RunPath,
        [string] $TestName,
        [switch] $IncludeNotImplemented,
        [string] $ResultPath
    )

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $RunPath
    $configuration.Run.PassThru = $true
    $configuration.Run.Exit = $false
    $configuration.Output.Verbosity = 'Normal'

    if ($TestName) {
        $configuration.Filter.FullName = $TestName
    }
    if (-not $IncludeNotImplemented) {
        $configuration.Filter.ExcludeTag = $script:NotImplementedTag
    }
    if ($ResultPath) {
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = 'NUnitXml'
        $configuration.TestResult.OutputPath = $ResultPath
    }

    return $configuration
}

function Get-TestRunExitCode {
    <#
    .SYNOPSIS
        Converts a Pester run result to the runner's exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] $Result
    )

    $failed = $Result.FailedCount + $Result.FailedBlocksCount + $Result.FailedContainersCount
    if ($failed -gt 0) {
        return 1
    }
    # Pester counts tests removed by a filter as NotRun; they are part of TotalCount.
    if (($Result.TotalCount - $Result.NotRunCount) -eq 0) {
        return 2
    }
    return 0
}

function Invoke-TestRun {
    <#
    .SYNOPSIS
        Runs the selected tests and returns the exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string[]] $Suite = @('Unit', 'Integration'),
        [string[]] $Path,
        [string] $TestName,
        [switch] $IncludeNotImplemented,
        [string] $ResultPath,
        [Parameter(Mandatory)] [string] $TestRoot
    )

    try {
        Import-PinnedPester
        $runPath = @(Get-TestRunPath -TestRoot $TestRoot -Suite $Suite -Path $Path)
    }
    catch {
        Write-RunnerError -Message ($_.Exception.Message)
        return 2
    }

    if ($runPath.Count -eq 0) {
        Write-RunnerError -Message ("No test folders found for suite(s) '$($Suite -join ', ')' under $TestRoot.")
        return 2
    }

    $configuration = Get-TestRunConfiguration -RunPath $runPath -TestName $TestName `
        -IncludeNotImplemented:$IncludeNotImplemented -ResultPath $ResultPath
    # Run the tests with PowerShell's default error and strict mode settings, so they behave the same as when
    # Invoke-Pester is called directly. This script's own settings would otherwise apply to every test.
    $result = & {
        Set-StrictMode -Off
        $ErrorActionPreference = 'Continue'
        Invoke-Pester -Configuration $configuration
    }

    $exitCode = Get-TestRunExitCode -Result $result
    if ($exitCode -eq 2) {
        Write-RunnerError -Message ('No tests were selected. Check -Path, -TestName, and -IncludeNotImplemented.')
    }
    return $exitCode
}

# When dot-sourced (by the runner's own unit tests), only define the functions above.
if ($MyInvocation.InvocationName -eq '.') {
    return
}

exit (Invoke-TestRun -Suite $Suite -Path $Path -TestName $TestName -IncludeNotImplemented:$IncludeNotImplemented `
        -ResultPath $ResultPath -TestRoot $TestRoot)
