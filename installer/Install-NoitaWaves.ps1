$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packagedPayload = Join-Path $scriptDirectory "payload\mods\noita-arena-singleplayer"
$embeddedPayloadArchive = Join-Path $scriptDirectory "NoitaWaves-Mod.zip"
$repositoryPayload = Join-Path $scriptDirectory ".."
if (Test-Path (Join-Path $packagedPayload "mod.xml")) {
    $payloadSource = $packagedPayload
} elseif (Test-Path -LiteralPath $embeddedPayloadArchive -PathType Leaf) {
    $payloadArchive = $embeddedPayloadArchive
} elseif (Test-Path (Join-Path $repositoryPayload "mod.xml")) {
    $payloadSource = (Resolve-Path $repositoryPayload).Path
} else {
    [System.Windows.Forms.MessageBox]::Show(
        "The Noita Waves mod files could not be found. Download the complete installer ZIP from the GitHub Releases page and extract it before running the installer.",
        "Noita Waves Installer",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

function Test-NoitaDirectory {
    param([string]$Path)

    return -not [string]::IsNullOrWhiteSpace($Path) `
        -and (Test-Path -LiteralPath (Join-Path $Path "noita.exe") -PathType Leaf) `
        -and (Test-Path -LiteralPath (Join-Path $Path "data") -PathType Container)
}

function Get-NoitaInstallCandidates {
    $steamRoots = New-Object 'System.Collections.Generic.List[string]'
    $candidates = New-Object 'System.Collections.Generic.List[string]'

    foreach ($registryPath in @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
    )) {
        if (Test-Path $registryPath) {
            $steam = Get-ItemProperty -LiteralPath $registryPath
            foreach ($property in @("SteamPath", "InstallPath")) {
                $value = $steam.$property
                if (-not [string]::IsNullOrWhiteSpace($value) -and -not $steamRoots.Contains($value)) {
                    $steamRoots.Add($value)
                }
            }
        }
    }

    foreach ($defaultSteam in @(
        (Join-Path ${env:ProgramFiles(x86)} "Steam"),
        (Join-Path $env:ProgramFiles "Steam")
    )) {
        if ((Test-Path -LiteralPath $defaultSteam -PathType Container) -and -not $steamRoots.Contains($defaultSteam)) {
            $steamRoots.Add($defaultSteam)
        }
    }

    foreach ($steamRoot in $steamRoots) {
        if (-not (Test-Path -LiteralPath $steamRoot -PathType Container)) {
            continue
        }

        $libraryFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        $libraries = New-Object 'System.Collections.Generic.List[string]'
        $libraries.Add($steamRoot)
        if (Test-Path -LiteralPath $libraryFile -PathType Leaf) {
            $vdf = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($vdf, '"path"\s*"([^"]+)"')) {
                $library = $match.Groups[1].Value -replace '\\\\', '\'
                if (-not $libraries.Contains($library)) {
                    $libraries.Add($library)
                }
            }
        }

        foreach ($library in $libraries) {
            if (-not (Test-Path -LiteralPath $library -PathType Container)) {
                continue
            }
            $candidates.Add((Join-Path $library "steamapps\common\Noita"))
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-NoitaDirectory $candidate) {
            return $candidate
        }
    }
    return $null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Noita Waves Installer v0.1.0-alpha.5"
$form.ClientSize = New-Object System.Drawing.Size(570, 205)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

$intro = New-Object System.Windows.Forms.Label
$intro.Location = New-Object System.Drawing.Point(18, 16)
$intro.Size = New-Object System.Drawing.Size(530, 42)
$intro.Text = "Choose your Noita game folder. The installer adds Noita Waves to the game's standard mods folder; it does not inject code into the game."
$form.Controls.Add($intro)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Location = New-Object System.Drawing.Point(18, 72)
$pathLabel.Size = New-Object System.Drawing.Size(530, 18)
$pathLabel.Text = "Noita game folder (the folder containing noita.exe and data):"
$form.Controls.Add($pathLabel)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(18, 95)
$pathBox.Size = New-Object System.Drawing.Size(425, 24)
$detectedPath = Get-NoitaInstallCandidates
if ($detectedPath) {
    $pathBox.Text = $detectedPath
}
$form.Controls.Add($pathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(453, 93)
$browseButton.Size = New-Object System.Drawing.Size(95, 28)
$browseButton.Text = "Browse..."
$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the Noita game folder containing noita.exe and data."
    $dialog.ShowNewFolderButton = $false
    if (Test-NoitaDirectory $pathBox.Text) {
        $dialog.SelectedPath = $pathBox.Text
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.SelectedPath
    }
    $dialog.Dispose()
})
$form.Controls.Add($browseButton)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Location = New-Object System.Drawing.Point(418, 150)
$installButton.Size = New-Object System.Drawing.Size(130, 34)
$installButton.Text = "Install Noita Waves"
$installButton.Add_Click({
    $gamePath = $pathBox.Text.Trim()
    if (-not (Test-NoitaDirectory $gamePath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "That folder does not look like a Noita installation. Select the folder that contains both noita.exe and the data folder.",
            "Noita folder not found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $installButton.Enabled = $false
    $form.UseWaitCursor = $true
    [System.Windows.Forms.Application]::DoEvents()

    $modsDirectory = Join-Path $gamePath "mods"
    $destination = Join-Path $modsDirectory "noita-arena-singleplayer"
    $temporary = Join-Path $modsDirectory (".noita-waves-install-" + [guid]::NewGuid().ToString("N"))
    $backup = $null
    try {
        [System.IO.Directory]::CreateDirectory($modsDirectory) | Out-Null
        [System.IO.Directory]::CreateDirectory($temporary) | Out-Null
        if ($payloadArchive) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($payloadArchive, $temporary)
        } else {
            Get-ChildItem -LiteralPath $payloadSource -Force | Copy-Item -Destination $temporary -Recurse -Force
        }
        if (-not (Test-Path -LiteralPath (Join-Path $temporary "mod.xml") -PathType Leaf)) {
            throw "The installer payload is missing mod.xml."
        }

        if (Test-Path -LiteralPath $destination) {
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backup = Join-Path $modsDirectory "noita-arena-singleplayer.backup-$stamp"
            $suffix = 1
            while (Test-Path -LiteralPath $backup) {
                $backup = Join-Path $modsDirectory "noita-arena-singleplayer.backup-$stamp-$suffix"
                $suffix++
            }
            [System.IO.Directory]::Move($destination, $backup)
        }

        try {
            [System.IO.Directory]::Move($temporary, $destination)
        } catch {
            if ($backup -and -not (Test-Path -LiteralPath $destination)) {
                [System.IO.Directory]::Move($backup, $destination)
                $backup = $null
            }
            throw
        }

        $message = "Noita Waves v0.1.0-alpha.5 is installed.`r`n`r`nStart Noita, enable Noita Waves in the Mods menu, and choose it from New Game."
        if ($backup) {
            $message += "`r`n`r`nYour previous mod folder was preserved at:`r`n$backup"
        }
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Installation complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $form.Close()
    } catch {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Recurse -Force
        }
        [System.Windows.Forms.MessageBox]::Show(
            "Installation failed: $($_.Exception.Message)",
            "Noita Waves Installer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        $form.UseWaitCursor = $false
        $installButton.Enabled = $true
    }
})
$form.Controls.Add($installButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(323, 150)
$cancelButton.Size = New-Object System.Drawing.Size(85, 34)
$cancelButton.Text = "Cancel"
$cancelButton.Add_Click({ $form.Close() })
$form.Controls.Add($cancelButton)
$form.AcceptButton = $installButton
$form.CancelButton = $cancelButton

[void]$form.ShowDialog()
$form.Dispose()
