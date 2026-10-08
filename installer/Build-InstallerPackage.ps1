param(
    [string]$OutputZipPath = (Join-Path $PSScriptRoot "dist\NoitaWaves-Installer.zip"),
    [string]$OutputExePath = (Join-Path $PSScriptRoot "dist\NoitaWavesInstaller.exe")
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$zipFullPath = [System.IO.Path]::GetFullPath($OutputZipPath)
$exeFullPath = [System.IO.Path]::GetFullPath($OutputExePath)
$workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("noita-waves-package-" + [guid]::NewGuid().ToString("N"))
$packageRoot = Join-Path $workDirectory "NoitaWaves-Installer"
$exePackageRoot = Join-Path $workDirectory "NoitaWaves-Executable"
$payloadDirectory = Join-Path $packageRoot "payload\mods\noita-arena-singleplayer"

try {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot "mod.xml") -PathType Leaf)) {
        throw "Run this script from the Noita Waves repository; mod.xml was not found."
    }

    [System.IO.Directory]::CreateDirectory($payloadDirectory) | Out-Null
    foreach ($item in @(
        "init.lua",
        "mod.xml",
        "menu_banner_background.png",
        "menu_banner_overlay.png",
        "README.md",
        "files"
    )) {
        $source = Join-Path $repositoryRoot $item
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Required mod payload item was not found: $item"
        }
        Copy-Item -LiteralPath $source -Destination $payloadDirectory -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-NoitaWaves.ps1") -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-NoitaWaves.bat") -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "README.txt") -Destination $packageRoot
    [System.IO.Directory]::CreateDirectory($exePackageRoot) | Out-Null
    $embeddedPayloadArchive = Join-Path $exePackageRoot "NoitaWaves-Mod.zip"
    Compress-Archive -Path (Join-Path $payloadDirectory "*") -DestinationPath $embeddedPayloadArchive -CompressionLevel Optimal
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-NoitaWaves.ps1") -Destination $exePackageRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-NoitaWaves.bat") -Destination $exePackageRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "README.txt") -Destination $exePackageRoot

    foreach ($output in @($zipFullPath, $exeFullPath)) {
        $outputDirectory = Split-Path -Parent $output
        if (-not (Test-Path -LiteralPath $outputDirectory)) {
            [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
        }
    }
    foreach ($output in @($zipFullPath, $exeFullPath)) {
        if (Test-Path -LiteralPath $output) {
            Remove-Item -LiteralPath $output -Force
        }
    }
    Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipFullPath -CompressionLevel Optimal

    $iexpress = Join-Path $env:WINDIR "System32\iexpress.exe"
    if (-not (Test-Path -LiteralPath $iexpress -PathType Leaf)) {
        throw "Windows IExpress was not found at $iexpress; the ZIP package was created, but the EXE could not be built."
    }

    $files = @(Get-ChildItem -LiteralPath $exePackageRoot -File -Recurse)
    $sourceLines = New-Object 'System.Collections.Generic.List[string]'
    $stringLines = New-Object 'System.Collections.Generic.List[string]'
    for ($index = 0; $index -lt $files.Count; $index++) {
        $relativePath = $files[$index].FullName.Substring($exePackageRoot.Length + 1)
        $relativePath = $relativePath -replace '/', '\'
        $sourceLines.Add("%FILE$index%=")
        $stringLines.Add("FILE$index=`"$relativePath`"")
    }

    $sedPath = Join-Path $workDirectory "NoitaWavesInstaller.sed"
    $sed = @(
        "[Version]"
        "Class=IEXPRESS"
        "SEDVersion=3"
        "[Options]"
        "PackagePurpose=InstallApp"
        "ShowInstallProgramWindow=0"
        "HideExtractAnimation=1"
        "UseLongFileName=1"
        "InsideCompressed=1"
        "CAB_FixedSize=0"
        "CAB_ResvCodeSigning=0"
        "RebootMode=N"
        "InstallPrompt="
        "DisplayLicense="
        "FinishMessage="
        "TargetName=$exeFullPath"
        "FriendlyName=Noita Waves Mod Installer"
        "AppLaunched=Install-NoitaWaves.bat"
        "PostInstallCmd=<None>"
        "AdminQuietInstCmd="
        "UserQuietInstCmd="
        "SourceFiles=SourceFiles"
        "[SourceFiles]"
        "SourceFiles0=$exePackageRoot"
        "[SourceFiles0]"
    ) + $sourceLines.ToArray() + @("[Strings]") + $stringLines.ToArray()
    Set-Content -LiteralPath $sedPath -Value $sed -Encoding ASCII

    $build = Start-Process -FilePath $iexpress -ArgumentList @("/N", "/Q", $sedPath) -Wait -PassThru
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exeFullPath -PathType Leaf)) {
        throw "IExpress failed to create the installer executable (exit code $($build.ExitCode))."
    }

    Write-Output "Created installer executable: $exeFullPath"
    Write-Output "Created installer ZIP: $zipFullPath"
} finally {
    if (Test-Path -LiteralPath $workDirectory) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force
    }
}
