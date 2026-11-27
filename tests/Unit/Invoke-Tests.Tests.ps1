#Requires -Version 5.1
# Unit tests for the test runner's functions. The runner is dot-sourced, which defines its functions without
# running it. Module commands are mocked, so the Pester session running these tests is never changed.

BeforeAll {
    $runnerPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts\Invoke-Tests.ps1'
    . $runnerPath
}

Describe 'Import-PinnedPester' {
    BeforeEach {
        Mock Get-Module { }
        Mock Remove-Module { }
        Mock Import-Module { }
    }

    It 'imports exactly Pester 5.9.1' {
        Import-PinnedPester

        Should -Invoke Import-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Pester' -and $RequiredVersion -eq [version] '5.9.1'
        }
    }

    It 'stops with install instructions when Pester 5.9.1 is missing' {
        Mock Import-Module { throw 'The specified module was not loaded.' }

        $message = $null
        try { Import-PinnedPester } catch { $message = $_.Exception.Message }

        $message | Should -BeLike '*Pester 5.9.1 is required*'
        $message | Should -BeLike '*Install-Module -Name Pester -RequiredVersion 5.9.1*'
        $message | Should -BeLike '*-SkipPublisherCheck*'
        $message | Should -BeLike '*Install-PackageProvider -Name NuGet*'
    }

    It 'never falls back to another Pester version when 5.9.1 is missing' {
        Mock Import-Module { throw 'The specified module was not loaded.' }

        { Import-PinnedPester } | Should -Throw '*Pester 5.9.1 is required*'

        Should -Invoke Import-Module -Times 1 -Exactly
        Should -Invoke Import-Module -Times 0 -ParameterFilter { $RequiredVersion -ne [version] '5.9.1' }
    }

    It 'unloads a different Pester version that is already loaded' {
        Mock Get-Module { [pscustomobject] @{ Name = 'Pester'; Version = [version] '3.4.0' } }

        Import-PinnedPester

        Should -Invoke Remove-Module -Times 1 -Exactly
    }

    It 'leaves Pester 5.9.1 loaded when it is already loaded' {
        Mock Get-Module { [pscustomobject] @{ Name = 'Pester'; Version = [version] '5.9.1' } }

        Import-PinnedPester

        Should -Invoke Remove-Module -Times 0
    }
}

Describe 'Get-TestRunPath' {
    BeforeAll {
        $root = Join-Path $TestDrive 'tests'
        foreach ($name in 'Unit', 'Integration', 'Compatibility') {
            New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
        }
        $partialRoot = Join-Path $TestDrive 'partial'
        New-Item -ItemType Directory -Path (Join-Path $partialRoot 'Unit') -Force | Out-Null
        $sampleFile = Join-Path $TestDrive 'Sample.Tests.ps1'
        Set-Content -LiteralPath $sampleFile -Value '# sample' -Encoding Ascii
    }

    It 'selects Unit and Integration by default' {
        $paths = Get-TestRunPath -TestRoot $root

        $paths | Should -Be @((Join-Path $root 'Unit'), (Join-Path $root 'Integration'))
    }

    It 'selects only the named suite' {
        $paths = Get-TestRunPath -TestRoot $root -Suite 'Compatibility'

        $paths | Should -Be @((Join-Path $root 'Compatibility'))
    }

    It 'selects every suite for All' {
        $paths = Get-TestRunPath -TestRoot $root -Suite 'All'

        $paths | Should -Be @(
            (Join-Path $root 'Unit'), (Join-Path $root 'Integration'), (Join-Path $root 'Compatibility'))
    }

    It 'skips suite folders that do not exist' {
        $paths = Get-TestRunPath -TestRoot $partialRoot -Suite 'Unit', 'Integration'

        $paths | Should -Be @((Join-Path $partialRoot 'Unit'))
    }

    It 'returns an empty list when no suite folder exists' {
        $paths = Get-TestRunPath -TestRoot $partialRoot -Suite 'Compatibility'

        @($paths).Count | Should -Be 0
    }

    It 'uses -Path instead of the suites' {
        $paths = Get-TestRunPath -TestRoot $root -Suite 'All' -Path $sampleFile

        $paths | Should -Be @($sampleFile)
    }

    It 'stops when a -Path value does not exist' {
        $missing = Join-Path $TestDrive 'Missing.Tests.ps1'

        { Get-TestRunPath -TestRoot $root -Path $missing } | Should -Throw "Test path not found: $missing"
    }
}

Describe 'Get-TestRunConfiguration' {
    It 'excludes tests tagged NotImplemented by default' {
        $configuration = Get-TestRunConfiguration -RunPath $TestDrive

        $configuration.Filter.ExcludeTag.Value | Should -Contain 'NotImplemented'
    }

    It 'includes tests tagged NotImplemented with -IncludeNotImplemented' {
        $configuration = Get-TestRunConfiguration -RunPath $TestDrive -IncludeNotImplemented

        @($configuration.Filter.ExcludeTag.Value) | Should -Not -Contain 'NotImplemented'
    }

    It 'filters by full test name with -TestName' {
        $configuration = Get-TestRunConfiguration -RunPath $TestDrive -TestName '*elevated*'

        $configuration.Filter.FullName.Value | Should -Be @('*elevated*')
    }

    It 'does not filter by name without -TestName' {
        $configuration = Get-TestRunConfiguration -RunPath $TestDrive

        @($configuration.Filter.FullName.Value).Count | Should -Be 0
    }

    It 'writes NUnit XML results with -ResultPath' {
        $resultPath = Join-Path $TestDrive 'results.xml'

        $configuration = Get-TestRunConfiguration -RunPath $TestDrive -ResultPath $resultPath

        $configuration.TestResult.Enabled.Value | Should -BeTrue
        $configuration.TestResult.OutputFormat.Value | Should -Be 'NUnitXml'
        $configuration.TestResult.OutputPath.Value | Should -Be $resultPath
    }

    It 'returns the result object and never exits the session' {
        $configuration = Get-TestRunConfiguration -RunPath $TestDrive

        $configuration.Run.PassThru.Value | Should -BeTrue
        $configuration.Run.Exit.Value | Should -BeFalse
    }
}

Describe 'Get-TestRunExitCode' {
    It 'returns <Expected> when <Case>' -ForEach @(
        @{ Case = 'every test passed'; Total = 3; NotRun = 0; Failed = 0; FailedBlocks = 0; FailedContainers = 0; Expected = 0 }
        @{ Case = 'some tests were filtered out'; Total = 3; NotRun = 2; Failed = 0; FailedBlocks = 0; FailedContainers = 0; Expected = 0 }
        @{ Case = 'a test failed'; Total = 3; NotRun = 0; Failed = 1; FailedBlocks = 0; FailedContainers = 0; Expected = 1 }
        @{ Case = 'a block failed'; Total = 3; NotRun = 0; Failed = 0; FailedBlocks = 1; FailedContainers = 0; Expected = 1 }
        @{ Case = 'a test file failed'; Total = 0; NotRun = 0; Failed = 0; FailedBlocks = 0; FailedContainers = 1; Expected = 1 }
        @{ Case = 'no tests were found'; Total = 0; NotRun = 0; Failed = 0; FailedBlocks = 0; FailedContainers = 0; Expected = 2 }
        @{ Case = 'every test was filtered out'; Total = 3; NotRun = 3; Failed = 0; FailedBlocks = 0; FailedContainers = 0; Expected = 2 }
    ) {
        $result = [pscustomobject] @{
            TotalCount            = $Total
            NotRunCount           = $NotRun
            FailedCount           = $Failed
            FailedBlocksCount     = $FailedBlocks
            FailedContainersCount = $FailedContainers
        }

        Get-TestRunExitCode -Result $result | Should -Be $Expected
    }
}

Describe 'Invoke-TestRun' {
    BeforeEach {
        Mock Invoke-Pester { }
        Mock Write-RunnerError { }
    }

    It 'returns 2 and runs nothing when Pester 5.9.1 is missing' {
        Mock Import-PinnedPester { throw 'Pester 5.9.1 is required but was not found.' }

        $exitCode = Invoke-TestRun -TestRoot $TestDrive

        $exitCode | Should -Be 2
        Should -Invoke Invoke-Pester -Times 0
        Should -Invoke Write-RunnerError -Times 1 -ParameterFilter { $Message -like '*Pester 5.9.1 is required*' }
    }

    It 'returns 2 and runs nothing when no suite folder exists' {
        Mock Import-PinnedPester { }

        $exitCode = Invoke-TestRun -TestRoot (Join-Path $TestDrive 'empty') -Suite 'Unit'

        $exitCode | Should -Be 2
        Should -Invoke Invoke-Pester -Times 0
    }
}
