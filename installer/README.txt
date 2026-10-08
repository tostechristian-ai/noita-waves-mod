Noita Waves Installer - v0.1.0-alpha.5

Run NoitaWavesInstaller.exe, or double-click Install-NoitaWaves.bat if using the ZIP package. Choose your Noita game folder if it is not detected automatically, then click Install Noita Waves.

The installer copies the same Noita Waves v0.1.0-alpha.5 game-mod payload into:
  <Noita game folder>\mods\noita-arena-singleplayer

It does not inject code into Noita, patch game files, or enable the mod automatically. After installation, start Noita, enable Noita Waves in the Mods menu, and choose it from New Game.

If that mod folder already exists, the installer moves it to a timestamped backup beside the new folder before installing.

This Windows installer uses built-in Windows PowerShell and does not need administrator access when the game folder is writable.

To rebuild the EXE and ZIP from the repository on Windows, run:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File installer\Build-InstallerPackage.ps1

The build outputs go into installer\dist. The EXE is a self-extracting Windows installer built with the Windows IExpress utility. Both the EXE and ZIP contain the same mod payload and installer scripts.

The EXE launches the included PowerShell installer directly; it does not depend on Command.com to launch the Windows batch wrapper.
