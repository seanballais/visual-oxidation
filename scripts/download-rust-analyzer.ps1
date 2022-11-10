# DeGZip-File function based on:
# https://scatteredcode.net/download-and-extract-gzip-tar-with-powershell
function DeGZipFile
{
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
    )

    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

    $buffer = New-Object byte[](1024)
    while($true) {
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0) {
            break
        }
        
        $output.Write($buffer, 0, $read)
    }

    $gzipStream.Close()
    $output.Close()
    $input.Close()
}

# Code based from:
# https://social.technet.microsoft.com/Forums/office/en-US/93728a72-93d5-4264-9841-eaa2315ec60b/powershell-while-waiting-indications?forum=ITCG
function StartJobWithSpinner
{
    param (
        [parameter(Mandatory=$true)]
        $scriptCommands,
        $initCommands
    )

    $scriptBlock = [scriptblock]::Create($scriptCommands)

    if ($initCommands) {
        $initBlock = [scriptblock]::Create($initCommands)
        $job = Start-Job -ScriptBlock $scriptBlock -InitializationScript $initBlock
    } else {
        $job = Start-Job -ScriptBlock $scriptBlock
    }

    $origCursorPos = $Host.UI.RawUI.CursorPosition

    $scrollAnim = "/-\|"
    $loadingMessages = @(
        'Beep boop.',
        'Finishing in NaN seconds.',
        'Hush, hush. Sit down and wait.',
        'Might wanna grab a cup of coffee.'
        'Aaaaannnnyyyy tiiiimmmeeee nowwwwww.',
        'Seriously. Why is this taking too long?',
        'Ughhhhhhhhhh!',
        'Does life have meaning?',
        'Why are we here?',
        'Never gonna give you up. Never gonna let you down.',
        'No warranty provided.'
        'I hear the drums echoing tonight...',
        'Can''t stop me. Wooo-oooh. [Actually, you can.]'
        'Running out of loading screen messages.',
        'You should play Stardew Valley.'
    )
    $animIdx = 0
    $currLoadingMsgIdx = Get-Random -Maximum $loadingMessages.Count
    $loadingMsgTickCtr = 0

    # Define the variables we would need to clear out the spinner and loading messages.
    $longestLoadingMsgLen = ($loadingMessages | Measure-Object -Maximum -Property Length).Maximum
    $loadingScreenClearStrLen = $longestLoadingMsgLen + 4 # Plus 4 for the spinner, the succeeding space,
                                                          # and the surrounding message parentheses. Ref:
                                                          # 
                                                          # <...>Deleting... / (<loading screen message>)
                                                          # 
    $loadingScreenClearStr = " " * $loadingScreenClearStrLen

    while (($job.State -eq 'Running') -and ($job.State -ne 'NotStarted')) {
        $Host.UI.RawUI.CursorPosition = $origCursorPos

        # Clear the remaining columns to the right, and return back to the proper cursor position.
        Write-Host "$loadingScreenClearStr" -NoNewLine
        $Host.UI.RawUI.CursorPosition = $origCursorPos

        # And print the spinner and loading message now.
        Write-Host "$($scrollAnim[$animIdx]) ($($loadingMessages[$currLoadingMsgIdx]))" -NoNewLine
        
        if ($loadingMsgTickCtr -eq 30) {
            $currLoadingMsgIdx = Get-Random -Maximum $loadingMessages.Count

            $loadingMessageTickCtr = 0; # Reset.
        }

        $animIdx = ($animIdx + 1) % $scrollAnim.Length
        $loadingMsgTickCtr++;

        Start-Sleep -Milliseconds 100
    }

    $result = Receive-Job -Job $job
    Write-Host $result

    # Clean up the console, and clear out the used space for the spinner and loading messages.
    $Host.UI.RawUI.CursorPosition = $origCursorPos
    Write-Host "$loadingScreenClearStr" -NoNewLine
    $Host.UI.RawUI.CursorPosition = $origCursorPos

    # And return the cursor to its original position.
    $Host.UI.RawUI.CursorPosition = $origCursorPos
}

function Main
{
    param (
        $archiveFileName = 'rust-analyzer-x86_64-pc-windows-msvc.gz',
        $exeFileName = 'rust-analyzer.exe',
        $inputFile = $(Join-Path $pwd $archiveFileName),
        $outputFile = $(Join-Path $pwd 'assets' $exeFileName)
    )

    Write-Host "Downloading the latest version of rust-analyzer."

    # Let's delete copies of rust-analyzer if it exists.
    # Let's delete the archived copy first.
    if (Test-Path $inputFile) {
        Write-Host "  $archiveFileName exists in current directory. Deleting... " -NoNewLine
        StartJobWithSpinner "Remove-Item '$inputFile'"

        if (Test-Path $inputFile) {
            throw "Failed to delete $inputFile."
        } else {
            Write-Host "done!" -ForegroundColor green
        }
    }

    # Then the executable next.
    if (Test-Path $outputFile) {
        Write-Host "  $exeFileName exists in the assets directory. Deleting... " -NoNewLine
        StartJobWithSpinner "Remove-Item '$outputFile'"

        if (Test-Path $outputFile) {
            throw "Failed to delete $outputFile."
        } else {
            Write-Host "done!" -ForegroundColor green
        }
    }

    Write-Host "  Downloading $archiveFileName... " -NoNewLine
    $curlJobCommands = @"
`$serverAPIURL = 'https://api.github.com/repos/rust-lang/rust-analyzer/releases/latest'
`$url = ((curl -s `$serverAPIURL | Select-String "/$archiveFileName") -split ':',2)[-1].Trim().Trim('"')
curl -sL `$url -o '$archiveFileName';
"@
    StartJobWithSpinner $curlJobCommands
    if (Test-Path $inputFile) {
        Write-Host "done!" -ForegroundColor green
    } else {
        throw "Failed to download $archiveFileName."
    }

    Write-Host "  Extracting $exeFileName... " -NoNewLine
    StartJobWithSpinner "DeGZipFile '$inputFile' '$outputFile'" "function DeGZipFile { $function:DeGZipFile }"
    if (Test-Path $outputFile) {
        Write-Host "done!" -ForegroundColor green
    } else {
        throw "Failed to extract $exeFileName."
    }
}

# Console Set Up.
[console]::CursorVisible = $false # Not expecting this to fail.

# Set up the header information.
$scriptMajorVersion = 0
$scriptMinorVersion = 0
$scriptPatchVersion = 0
$scriptDevStage = 'alpha'
$scriptMiscData = ''
$scriptVersion = "$scriptMajorVersion.$scriptMinorVersion.$scriptPatchVersion"

if ($scriptDevStage) {
    $scriptVersion = "$scriptVersion-$scriptDevStage"
}

if ($scriptMiscData) {
    $scriptVersion = "$scriptVersion+$scriptMiscData"
}

$copyrightYear = 2022
$copyrightOwner = 'Sean Francis N. Ballais'

# Set up some important variables.
$archiveFileName = 'rust-analyzer-x86_64-pc-windows-msvc.gz'
$exeFileName = 'rust-analyzer.exe'
$inputFile = Join-Path $pwd $archiveFileName
$outputFile = Join-Path $pwd 'assets' $exeFileName

Write-Host "Rust Analyzer (Windows) Downloader $scriptVersion"
Write-Host "Copyright (c) $copyrightYear $copyrightOwner."
Write-Host ''

try {
    $ranSuccessfully = $false

    Main $archiveFileName $exeFileName $inputFile $outputFile

    $ranSuccessfully = $true;
} catch {
    Write-Host 'failed!' -ForegroundColor red
    Write-Host ''
} finally {
    # Check if the user pressed Ctrl+C or not by checking if we have the rust-analyzer archive and the executable.
    # Both of them should exist if the user pressed Ctrl+C. This logic does fail when the user presses Ctrl+C after
    # downloading the archive and extracting it or while both the archive and executable are in their expected
    # locations as far as this script is concerned. We are also expecting that the user will only press Ctrl+C once.
    # This check is also hacky, but this should work for now, while we are not running Main inside a job. Fortunately,
    # the aforementioned cases should be rare enough that this logical bug is a low priority. Nevertheless, transforming
    # this into a proper Ctrl+C interrupt check would be a great task to undertake, especially if you are new to this
    # codebase.
    if (-not ((Test-Path $inputFile) -and (Test-Path $outputFile))) {
        $isCtrlCPressed = $true
    }

    # Clean up.
    if ($isCtrlCPressed) {
        # Stop the spinner for the currently running task, and let's print a cancelled message at the bottom.
        Write-Host '' # Before this, we're on the same line as the spinner and loading message.
        Write-Host ''
        Write-Host 'Task cancelled by the user!' -ForegroundColor magenta
    }

    Write-Host ''
    Write-Host 'Cleaning up the mess we created.'

    if (-not ($ranSuccessfully)) { # Note that $ranSuccessfully is false when Ctrl+C was pressed.
        # We need to stop all jobs when we exit. Otherwise, they might leave files that we don't want
        # to remain. For example, if we don't make sure curl is automatically stopped, it might keep
        # on downloading the rust-analyzer archive, even if our script already exits.
        Get-Job | Remove-Job -Force
    }

    # Let's delete the archived copy first.
    $hasCleanUpBeenPerformed = $false
    if (Test-Path $inputFile) {
        $inputFileMBSize = (Get-Item -Path $inputFile).Length / 1MB

        Write-Host "  Deleting the possibly corrupt $archiveFileName ($inputFileMBSize MB)... " -NoNewLine
        StartJobWithSpinner "Remove-Item '$inputFile'"

        if (Test-Path $inputFile) {
            Write-Host 'failed!' -ForegroundColor red
        } else {
            Write-Host 'done!' -ForegroundColor green
        }

        $hasCleanUpBeenPerformed = $true
    }
    
    if (-not $hasCleanUpBeenPerformed) {
        Write-Host "  Nothing to clean up."
    }

    if ($ranSuccessfully) {
        Write-Host ''
        Write-Host 'The latest version of rust-analyzer has been downloaded.✨'
        Write-Host 'Executable can be found in: ' -NoNewLine
        Write-Host "$outputFile" -ForegroundColor yellow
    } else {
        Write-Host ''
        Write-Host 'Failed to successfully obtain the latest version of rust-analyzer. ' -NoNewLine

        if ($isCtrlCPressed) {
            Write-Host 'Action cancelled by user (via Ctrl+C).' -NoNewLine
        }

        Write-Host '😭'
    }

    # Console Clean Up
    [console]::CursorVisible = $true # Not expecting this to fail.
}
