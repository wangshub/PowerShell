# Powershell dotfiles

## Installation

```Powershell
Install-Module -Name oh-my-posh -Force
Install-Module PSColors -Force
Install-Module posh-git -Force
Install-Module -Name Terminal-Icons -Force

# Install Az Predictor
# https://www.thomasmaurer.ch/2021/02/az-predictor-module-azure-powershell-predictions/
# Install PowerShell >= 7.2
Install-Module PSReadline -AllowPrerelease -Force
Install-Module -Name Az.Tools.Predictor
Import-Module Az.Tools.Predictor -RequiredVersion 0.2.0
Enable-AzPredictor -AllSession
Set-PSReadLineOption -PredictionViewStyle ListView

winget install JanDeDobbeleer.OhMyPosh
```