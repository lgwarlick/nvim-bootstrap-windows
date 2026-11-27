#Requires -Version 5.1
# Unit tests for the validation runner's checks. The runner is dot-sourced, which defines its functions without
# running it. Known-good and known-bad fixture files are written into TestDrive by each test, so no file in the
# repository has to break a rule. Values that a check would flag in this file itself (a user-profile path, a byte
# order mark) are built at run time.

BeforeAll {
    $runnerPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts\Invoke-Validation.ps1'
    . $runnerPath

    $script:Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    # Built from parts so this file does not contain the literal path it tests for.
    $script:UserPath = 'C:' + '\Users\' + 'alice\AppData\Local\nvim'

    function New-FixtureRoot {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root | Out-Null
        return $root
    }

    function Write-FixtureText {
        param([string] $Root, [string] $RelativePath, [string] $Content)

        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content, $script:Utf8NoBom)
    }

    function Write-FixtureBytes {
        param([string] $Root, [string] $RelativePath, [byte[]] $Bytes)

        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [System.IO.File]::WriteAllBytes($path, $Bytes)
    }
}

Describe 'Test-PowerShellSyntax' {
    It 'passes PowerShell 5.1 code' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Good.ps1' "if (`$a) { 'yes' } else { 'no' }`r`n"
        Write-FixtureText $root 'src\Good.psm1' "function Get-Thing { param([string] `$Name) `$Name }`r`n"
        Write-FixtureText $root 'src\Good.psd1' "@{ ModuleVersion = '0.1.0' }`r`n"

        @(Test-PowerShellSyntax -Root $root).Count | Should -Be 0
    }

    It 'fails on the PowerShell 7 operator <Operator> with file and line' -ForEach @(
        @{ Operator = '??'; Code = '$b = $a ?? 1' }
        @{ Operator = '&&'; Code = 'git status && git log' }
        @{ Operator = 'ternary'; Code = '$b = $a ? 1 : 2' }
        @{ Operator = '?.'; Code = '$b = ${a}?.Name' }
    ) {
        $root = New-FixtureRoot
        Write-FixtureText $root 'scripts\Bad.ps1' "# line 1`r`n`$a = 1`r`n$Code`r`n"

        $findings = @(Test-PowerShellSyntax -Root $root)

        $findings.Count | Should -BeGreaterThan 0
        $findings[0].Path | Should -Be 'scripts\Bad.ps1'
        $findings[0].Line | Should -Be 3
        $findings[0].Message | Should -Not -BeNullOrEmpty
    }

    It 'checks .psm1 and .psd1 files' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Bad.psm1' '$b = $a ?? 1'
        Write-FixtureText $root 'Bad.psd1' '@{ A = $a ?? 1 }'

        $paths = @(Test-PowerShellSyntax -Root $root | ForEach-Object { $_.Path } | Sort-Object -Unique)

        $paths | Should -Be @('Bad.psd1', 'Bad.psm1')
    }

    It 'ignores files that are not PowerShell' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'notes.txt' '$b = $a ?? 1'

        @(Test-PowerShellSyntax -Root $root).Count | Should -Be 0
    }
}

Describe 'Test-HardcodedUserPath' {
    It 'passes paths resolved from the environment' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Good.ps1' "`$path = Join-Path `$env:LOCALAPPDATA 'nvim'`r`n"
        Write-FixtureText $root 'config\init.lua' "local data = vim.fn.stdpath('data')`n"

        @(Test-HardcodedUserPath -Root $root).Count | Should -Be 0
    }

    # Not named after the placeholder: Pester would treat <name> in a test name as a template.
    It 'passes a placeholder user name in angle brackets' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Good.ps1' ("# Never write a path such as C:" + "\Users\<name>`r`n")

        @(Test-HardcodedUserPath -Root $root).Count | Should -Be 0
    }

    It 'passes a profile path built from an environment variable' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Good.ps1' ("`$p = `"C:" + "\Users\`$env:USERNAME`"`r`n")

        @(Test-HardcodedUserPath -Root $root).Count | Should -Be 0
    }

    It 'fails on a hardcoded user-profile path in a <Extension> file with file and line' -ForEach @(
        @{ Extension = '.ps1' }
        @{ Extension = '.psm1' }
        @{ Extension = '.psd1' }
        @{ Extension = '.lua' }
        @{ Extension = '.json' }
    ) {
        $root = New-FixtureRoot
        Write-FixtureText $root "src\Bad$Extension" "first`nsecond '$script:UserPath'`n"

        $findings = @(Test-HardcodedUserPath -Root $root)

        $findings.Count | Should -Be 1
        $findings[0].Path | Should -Be "src\Bad$Extension"
        $findings[0].Line | Should -Be 2
        $findings[0].Message | Should -BeLike '*alice*'
    }

    It 'fails on a path with forward slashes or a different drive letter and case' {
        $root = New-FixtureRoot
        $forward = 'C:' + '/Users/' + 'bob/.config'
        $lower = 'd:' + '\users\' + 'carol'
        Write-FixtureText $root 'Bad.ps1' "'$forward'`r`n'$lower'`r`n"

        $findings = @(Test-HardcodedUserPath -Root $root)

        @($findings | ForEach-Object { $_.Line }) | Should -Be @(1, 2)
    }
}

Describe 'Test-FileEncoding' {
    It 'passes UTF-8 without a byte order mark, including non-ASCII text' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'README.md' ("Caf" + [char] 0x00E9 + " " + [char] 0x2014 + " notes`n")
        Write-FixtureText $root 'Good.ps1' "'plain'`r`n"
        Write-FixtureText $root 'init.lua' "-- lua`n"

        @(Test-FileEncoding -Root $root).Count | Should -Be 0
    }

    It 'passes an empty file' {
        $root = New-FixtureRoot
        Write-FixtureBytes $root 'Empty.ps1' ([byte[]] @())

        @(Test-FileEncoding -Root $root).Count | Should -Be 0
    }

    It 'fails on a byte order mark in a <Extension> file' -ForEach @(
        @{ Extension = '.md' }
        @{ Extension = '.ps1' }
        @{ Extension = '.psm1' }
        @{ Extension = '.psd1' }
        @{ Extension = '.lua' }
    ) {
        $root = New-FixtureRoot
        Write-FixtureBytes $root "docs\Bad$Extension" ([byte[]] (0xEF, 0xBB, 0xBF, 0x61, 0x0A))

        $findings = @(Test-FileEncoding -Root $root)

        $findings.Count | Should -Be 1
        $findings[0].Path | Should -Be "docs\Bad$Extension"
        $findings[0].Line | Should -Be 1
        $findings[0].Message | Should -BeLike '*byte order mark*'
    }

    It 'fails on a UTF-16 file' {
        $root = New-FixtureRoot
        Write-FixtureBytes $root 'Bad.md' ([byte[]] (0xFF, 0xFE, 0x61, 0x00, 0x0A, 0x00))

        $findings = @(Test-FileEncoding -Root $root)

        $findings.Count | Should -Be 1
        $findings[0].Message | Should -BeLike '*UTF-16*'
    }

    It 'fails on bytes that are not valid UTF-8 and reports their line' {
        $root = New-FixtureRoot
        # Line 3 contains 0xE9 on its own: an ANSI (Windows-1252) e-acute, invalid as UTF-8.
        Write-FixtureBytes $root 'Bad.md' ([byte[]] (0x61, 0x0A, 0x62, 0x0A, 0x63, 0xE9, 0x0A))

        $findings = @(Test-FileEncoding -Root $root)

        $findings.Count | Should -Be 1
        $findings[0].Line | Should -Be 3
        $findings[0].Message | Should -BeLike '*not valid UTF-8*'
    }

    It 'ignores file types it does not cover' {
        $root = New-FixtureRoot
        Write-FixtureBytes $root 'Bad.txt' ([byte[]] (0xEF, 0xBB, 0xBF, 0x61))

        @(Test-FileEncoding -Root $root).Count | Should -Be 0
    }
}

Describe 'Get-ValidationFile' {
    It 'skips the .git and TestResults folders' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Keep.md' 'a'
        Write-FixtureText $root '.git\Skip.md' 'a'
        Write-FixtureText $root 'TestResults\Skip.md' 'a'
        Write-FixtureText $root 'docs\Keep.md' 'a'

        $paths = @(Get-ValidationFile -Root $root -Extension '.md' | ForEach-Object { $_.Path } | Sort-Object)

        $paths | Should -Be @('docs\Keep.md', 'Keep.md')
    }
}

Describe 'Invoke-Validation' {
    BeforeEach {
        Mock Write-ValidationLine { }
        Mock Test-WindowsPowerShellHost { $true }
    }

    It 'returns 0 and reports every check as passed when all checks pass' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Good.ps1' "'plain'`r`n"

        Invoke-Validation -Root $root | Should -Be 0

        foreach ($check in Get-ValidationCheck) {
            Should -Invoke Write-ValidationLine -Times 1 -Exactly -ParameterFilter {
                $Message -eq "PASS  $($check.Name)"
            }
        }
    }

    It 'returns 1 and reports file and line when a check fails' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'scripts\Bad.ps1' "`$a = 1`r`n`$b = `$a ?? 1`r`n"

        Invoke-Validation -Root $root | Should -Be 1

        Should -Invoke Write-ValidationLine -ParameterFilter { $Message -like 'FAIL  PowerShell 5.1 syntax*' }
        Should -Invoke Write-ValidationLine -ParameterFilter { $Message -like '*scripts\Bad.ps1:2: *' }
    }

    It 'runs every check even when an earlier check fails' {
        $root = New-FixtureRoot
        Write-FixtureText $root 'Bad.ps1' '$b = $a ?? 1'

        Invoke-Validation -Root $root | Out-Null

        Should -Invoke Write-ValidationLine -ParameterFilter { $Message -like 'PASS  No hardcoded user paths*' }
        Should -Invoke Write-ValidationLine -ParameterFilter { $Message -like 'PASS  UTF-8 without BOM*' }
    }

    It 'returns 1 and reports the error when a check throws' {
        $root = New-FixtureRoot
        Mock Test-FileEncoding { throw 'disk read failed' }

        Invoke-Validation -Root $root | Should -Be 1

        Should -Invoke Write-ValidationLine -ParameterFilter {
            $Message -like 'FAIL  UTF-8 without BOM*' -or $Message -like '*disk read failed*'
        } -Times 2 -Exactly
    }

    It 'returns 2 and runs no checks outside Windows PowerShell 5.1' {
        Mock Test-WindowsPowerShellHost { $false }
        Mock Test-PowerShellSyntax { }
        Mock Write-RunnerError { }

        Invoke-Validation -Root $TestDrive | Should -Be 2

        Should -Invoke Test-PowerShellSyntax -Times 0
        Should -Invoke Write-RunnerError -Times 1 -ParameterFilter { $Message -like '*Windows PowerShell 5.1*' }
    }

    It 'returns 2 when the root folder does not exist' {
        Mock Write-RunnerError { }

        Invoke-Validation -Root (Join-Path $TestDrive 'missing') | Should -Be 2

        Should -Invoke Write-RunnerError -Times 1 -ParameterFilter { $Message -like '*not found*' }
    }
}
