#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the project's static checks.

.DESCRIPTION
    Runs a list of independent checks over the repository files. Every check runs, even when an earlier one fails.
    Each check reports PASS or FAIL; each failure is listed as <file>:<line>: <message>.

    Checks:
      PowerShell 5.1 syntax    Every .ps1, .psm1, and .psd1 file parses with the Windows PowerShell 5.1 parser,
                               which rejects PowerShell 7-only syntax (NFR-01).
      No hardcoded user paths  No PowerShell, Lua, or JSON file contains a literal user-profile path such as
                               C:\Users\<name> (NFR-03).
      UTF-8 without BOM        Markdown, PowerShell, and Lua files are valid UTF-8 without a byte order mark.

    The folders .git and TestResults are skipped.

    Exit codes:
      0  Every check passed.
      1  At least one check failed.
      2  The run could not start: the host is not Windows PowerShell 5.1, or the root folder does not exist.

.PARAMETER Root
    Folder to check. Default: the repository root. Used by the runner's own tests.

.EXAMPLE
    scripts\Invoke-Validation.ps1
#>
[CmdletBinding()]
param(
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Computed here, not as a parameter default: Windows PowerShell 5.1 leaves $PSScriptRoot empty in param defaults.
if (-not $Root) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$script:SkippedFolders = @('.git', 'TestResults')
$script:PowerShellExtensions = @('.ps1', '.psm1', '.psd1')

# A drive letter, \Users\ or /Users/, then a name. A name starting with a character that marks a placeholder or a
# variable (<name>, $env:USERNAME, %USERNAME%) is not a literal path.
$script:UserPathPattern = '(?i)\b[a-z]:[\\/]Users[\\/][^\\/\s<>$%''"`]+'

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

function Write-ValidationLine {
    <#
    .SYNOPSIS
        Writes one line of the validation report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Message
    )

    $Host.UI.WriteLine($Message)
}

function Test-WindowsPowerShellHost {
    <#
    .SYNOPSIS
        Returns $true when running in Windows PowerShell 5.1, whose parser the syntax check depends on.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $edition = if ($PSVersionTable.ContainsKey('PSEdition')) { $PSVersionTable.PSEdition } else { 'Desktop' }
    return ($edition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and
        $PSVersionTable.PSVersion.Minor -eq 1)
}

function New-ValidationFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [int] $Line,
        [Parameter(Mandatory)] [string] $Message
    )

    [pscustomobject] @{
        Path    = $Path
        Line    = $Line
        Message = $Message
    }
}

function Get-ValidationFile {
    <#
    .SYNOPSIS
        Returns the files under Root with the given extensions, skipping the .git and TestResults folders.
        Each result has FullName and Path (relative to Root).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [string[]] $Extension
    )

    $rootPath = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\')
    $pending = New-Object System.Collections.Generic.Stack[string]
    $pending.Push($rootPath)

    while ($pending.Count -gt 0) {
        $folder = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $folder -Force) {
            if ($item.PSIsContainer) {
                if ($script:SkippedFolders -notcontains $item.Name) {
                    $pending.Push($item.FullName)
                }
            }
            elseif ($Extension -contains $item.Extension) {
                [pscustomobject] @{
                    FullName = $item.FullName
                    Path     = $item.FullName.Substring($rootPath.Length + 1)
                }
            }
        }
    }
}

function Test-PowerShellSyntax {
    <#
    .SYNOPSIS
        Returns a finding for every parse error in the PowerShell files under Root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Root
    )

    foreach ($file in Get-ValidationFile -Root $Root -Extension $script:PowerShellExtensions) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors) |
            Out-Null
        foreach ($parseError in $errors) {
            New-ValidationFinding -Path $file.Path -Line $parseError.Extent.StartLineNumber `
                -Message $parseError.Message
        }
    }
}

function Test-HardcodedUserPath {
    <#
    .SYNOPSIS
        Returns a finding for every literal user-profile path in the PowerShell, Lua, and JSON files under Root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Root
    )

    $extensions = $script:PowerShellExtensions + @('.lua', '.json')
    foreach ($file in Get-ValidationFile -Root $Root -Extension $extensions) {
        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $lineNumber++
            foreach ($match in [regex]::Matches($line, $script:UserPathPattern)) {
                New-ValidationFinding -Path $file.Path -Line $lineNumber `
                    -Message ("Hardcoded user-profile path '{0}'; resolve it from the environment." -f $match.Value)
            }
        }
    }
}

function Get-LineNumberAtByte {
    <#
    .SYNOPSIS
        Returns the 1-based line number of the byte at Index.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [byte[]] $Bytes,
        [Parameter(Mandatory)] [int] $Index
    )

    $line = 1
    $end = [Math]::Min($Index, $Bytes.Length)
    for ($i = 0; $i -lt $end; $i++) {
        if ($Bytes[$i] -eq 0x0A) {
            $line++
        }
    }
    return $line
}

function Test-FileEncoding {
    <#
    .SYNOPSIS
        Returns a finding for every Markdown, PowerShell, or Lua file under Root that is not UTF-8 without a BOM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Root
    )

    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $extensions = @('.md') + $script:PowerShellExtensions + @('.lua')
    foreach ($file in Get-ValidationFile -Root $Root -Extension $extensions) {
        [byte[]] $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            New-ValidationFinding -Path $file.Path -Line 1 -Message 'UTF-8 with a byte order mark; save without it.'
            continue
        }
        if ($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or
                ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))) {
            New-ValidationFinding -Path $file.Path -Line 1 -Message 'UTF-16; save as UTF-8 without a byte order mark.'
            continue
        }

        try {
            $strictUtf8.GetString($bytes) | Out-Null
        }
        catch [System.Text.DecoderFallbackException] {
            $index = $_.Exception.Index
            $line = if ($index -ge 0) { Get-LineNumberAtByte -Bytes $bytes -Index $index } else { 1 }
            New-ValidationFinding -Path $file.Path -Line $line `
                -Message 'Contains bytes that are not valid UTF-8; save as UTF-8 without a byte order mark.'
        }
    }
}

function Get-ValidationCheck {
    <#
    .SYNOPSIS
        Returns the checks to run, in order. Each check has a Name and the Command that returns its findings.
        Later checks (PSScriptAnalyzer, documents checks, documents-vs-data checks) are added to this list.
    #>
    [CmdletBinding()]
    param()

    [pscustomobject] @{ Name = 'PowerShell 5.1 syntax'; Command = 'Test-PowerShellSyntax' }
    [pscustomobject] @{ Name = 'No hardcoded user paths'; Command = 'Test-HardcodedUserPath' }
    [pscustomobject] @{ Name = 'UTF-8 without BOM'; Command = 'Test-FileEncoding' }
}

function Invoke-Validation {
    <#
    .SYNOPSIS
        Runs every check over Root, writes the report, and returns the exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [string] $Root
    )

    if (-not (Test-WindowsPowerShellHost)) {
        Write-RunnerError -Message ('Validation must run in Windows PowerShell 5.1 (powershell.exe), because the ' +
            'syntax check uses its parser. Current version: ' + $PSVersionTable.PSVersion)
        return 2
    }
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        Write-RunnerError -Message "Validation root folder not found: $Root"
        return 2
    }

    $failedCount = 0
    foreach ($check in Get-ValidationCheck) {
        try {
            $findings = @(& $check.Command -Root $Root)
            $errorMessage = $null
        }
        catch {
            $findings = @()
            $errorMessage = $_.Exception.Message
        }

        if ($null -ne $errorMessage) {
            $failedCount++
            Write-ValidationLine -Message "FAIL  $($check.Name)"
            Write-ValidationLine -Message "      The check could not run: $errorMessage"
        }
        elseif ($findings.Count -gt 0) {
            $failedCount++
            Write-ValidationLine -Message "FAIL  $($check.Name)"
            foreach ($finding in $findings) {
                Write-ValidationLine -Message ('      {0}:{1}: {2}' -f $finding.Path, $finding.Line, $finding.Message)
            }
        }
        else {
            Write-ValidationLine -Message "PASS  $($check.Name)"
        }
    }

    if ($failedCount -gt 0) {
        return 1
    }
    return 0
}

# When dot-sourced (by the runner's own unit tests), only define the functions above.
if ($MyInvocation.InvocationName -eq '.') {
    return
}

exit (Invoke-Validation -Root $Root)
