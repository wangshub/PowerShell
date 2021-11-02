# Other hosts (ISE, ConEmu) don't always work as well with PSReadLine.
# Also, if PS is run with -Command, PSRL loading is suppressed.
$psrlMod = Get-Module PSReadLine
if (($null -eq $psrlMod) -or
    ($host.Name -eq 'Windows PowerShell ISE Host') -or
    ([System.Environment]::CommandLine -match '-command')) {
    return
}
elseif ($psrlMod.Version.Major -lt 2) {
    throw "PSReadLine 1.x installed or not imported, import PSRL or ugprade to at least 2.x."
}

if ((Get-Module PSReadLine).Version.Major -lt 2) {
    throw "PSReadLine 1.x installed or not imported, import PSRL or ugprade to at least 2.x."
}

# Configure PSReadLine options
$darkGray = "$([char]27)[38;2;192;192;192m"
$options = @{
    Colors                        = @{ Parameter = $darkGray; Operator = $darkGray }
    ExtraPromptLineCount          = 1
    MaximumHistoryCount           = 10000
    HistorySavePath               = "$PSScriptRoot\PSReadLine_history.txt"
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    PromptText                    = "> "
    AddToHistoryHandler           = {
        param([string]$line)
        return $line.Length -gt 3 -and $line[0] -ne ' ' -and $line[0] -ne ';'
    }
}

if ($PSVersionTable.PSVersion.Major -gt 5) {
    $options['PredictionSource'] = 'History'
}

Set-PSReadLineOption @options

if ($env:TERM_PROGRAM -eq "vscode") {
    Set-PSReadLineKeyHandler -Chord Ctrl+w   -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Chord Alt+D    -Function KillWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+@' -Function MenuComplete
}

# For Windows Terminal / SSH clients
if ($env:WT_SESSION -or $env:SSH_CLIENT) {
    Set-PSReadLineKeyHandler -Chord Ctrl+h -Function BackwardDeleteWord
}

Set-PSReadlineKeyHandler -Chord UpArrow   -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Chord DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord Ctrl+f    -Function ForwardWord
Set-PSReadLineKeyHandler -Chord Ctrl+k    -Function CaptureScreen
Set-PSReadlineKeyHandler -Chord Ctrl+Tab  -Function Complete
Set-PSReadlineKeyHandler -Chord Ctrl+q    -Function YankLastArg
Set-PSReadLineKeyHandler -Chord Ctrl+u    -Function RevertLine

Set-PSReadLineKeyHandler -Key Alt+6 -ScriptBlock {
    Set-Location .. -ErrorAction Ignore
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# Insert paired quotes if not already on a quote
Set-PSReadlineKeyHandler -Chord "Ctrl+'","Ctrl+Shift+'" `
                         -BriefDescription SmartInsertQuote `
                         -Description "Insert paired quotes if not already on a quote" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $keyChar = $key.KeyChar
    if ($key.Key -eq 'Oem7') {
        if ($key.Modifiers -eq 'Control') {
            $keyChar = "`'"
        }
        elseif ($key.Modifiers -eq 'Shift','Control') {
            $keyChar = '"'
        }
    }

    if ($line[$cursor] -eq $key.KeyChar) {
        # Just move the cursor
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        # Insert matching quotes, move cursor to be in between the quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$keyChar" * 2)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}

# Copy the current path to the clipboard
Set-PSReadlineKeyHandler -Chord Alt+c `
                         -BriefDescription CopyCurrentPathToClipboard `
                         -LongDescription "Copy the current path to the clipboard" `
                         -ScriptBlock {
    param($key, $arg)

    Set-Clipboard $pwd.Path
}

# Create the following handler(s) only when running on Linux
if ($IsLinux) {
    # Paste the clipboard text
    Set-PSReadlineKeyHandler -Chord Ctrl+v `
                             -BriefDescription PasteText `
                             -LongDescription "Paste the clipboard text" `
                             -ScriptBlock {
        param($key, $arg)

        $clipboardText = Get-Clipboard

        $isWsl = $null -ne (Get-Command -Name pwsh.exe -CommandType Application -ErrorAction Ignore)
        if ($isWsl -and !$clipboardText) {
            $clipboardText = powershell.exe -NoProfile -NonInteractive -Command 'Get-Clipboard'
        }

        if ($clipboardText) {
            $joinedText = $clipboardText -join [System.Environment]::NewLine
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($joinedText)
        }
        else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
        }
    }
}

# Paste the clipboard text as a here string
Set-PSReadlineKeyHandler -Chord Alt+v `
                         -BriefDescription PasteAsHereString `
                         -LongDescription "Paste the clipboard text as a here string" `
                         -ScriptBlock {
    param($key, $arg)

    $clipboardText = Get-Clipboard
    if ($clipboardText) {
        # Remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text =  $clipboardText.TrimEnd() -join "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

# Put parentheses around the selection or entire line and move the cursor to after the closing paren
Set-PSReadlineKeyHandler -Chord 'Ctrl+(' `
                         -BriefDescription ParenthesizeSelection `
                         -LongDescription "Put parentheses around the selection or entire line and move the cursor to after the closing parenthesis" `
                         -ScriptBlock {
    param($key, $arg)

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1)
    {
        $replacement = '(' + $line.SubString($selectionStart, $selectionLength) + ')'
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $replacement)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

# Replace all aliases with the full command
Set-PSReadlineKeyHandler -Chord Alt+r `
                         -BriefDescription ResolveAliases `
                         -LongDescription "Replace all aliases with the full command" `
                         -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $startAdjustment = 0
    foreach ($token in $tokens)
    {
        if ($token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CommandName)
        {
            $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
            if ($alias -ne $null)
            {
                $resolvedCommand = $alias.ResolvedCommandName
                if ($resolvedCommand -ne $null)
                {
                    $extent = $token.Extent
                    $length = $extent.EndOffset - $extent.StartOffset
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                        $extent.StartOffset + $startAdjustment,
                        $length,
                        $resolvedCommand)

                    # Our copy of the tokens won't have been updated, so we need to
                    # adjust by the difference in length
                    $startAdjustment += ($resolvedCommand.Length - $length)
                }
            }
        }
    }
}

# Save current line in history but do not execute
Set-PSReadlineKeyHandler -Chord Alt+w `
                         -BriefDescription SaveInHistory `
                         -LongDescription "Save current line in history but do not execute" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# This key handler shows the entire or filtered history using Out-GridView. The
# typed text is used as the substring pattern for filtering. A selected command
# is inserted to the command line without invoking. Multiple command selection
# is supported, e.g. selected by Ctrl + Click.
Set-PSReadlineKeyHandler -Chord F7 `
                         -BriefDescription History `
                         -LongDescription 'Show command history' `
                         -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern)
    {
        $pattern = [regex]::Escape($pattern)
    }

    $history = [System.Collections.ArrayList]@(
        $last = ''
        $lines = ''
        foreach ($line in [System.IO.File]::ReadLines((Get-PSReadlineOption).HistorySavePath))
        {
            if ($line.EndsWith('`'))
            {
                $line = $line.Substring(0, $line.Length - 1)
                $lines = if ($lines)
                {
                    "$lines`n$line"
                }
                else
                {
                    $line
                }
                continue
            }

            if ($lines)
            {
                $line = "$lines`n$line"
                $lines = ''
            }

            if (($line -cne $last) -and (!$pattern -or ($line -match $pattern)))
            {
                $last = $line
                $line
            }
        }
    )
    $history.Reverse()

    $command = $history | Out-GridView -Title History -PassThru
    if ($command)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}
