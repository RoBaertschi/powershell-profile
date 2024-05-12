$hasInternet = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
  Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module -Name Terminal-Icons

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

Invoke-Expression (&starship init powershell)

function Update-Profile {
  if (-not $Global:hasInternet) {
    Write-Host "Skipping profile update check due to Github.com not responding in 1 second." -ForegroundColor Yellow
    return
  }

  try {
    $url = "https://raw.githubusercontent.com/RoBaertschi/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    $oldhash = Get-FileHash $profile
    Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
    $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
    if ($newhash.Hash -ne $oldhash.Hash) {
      Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $profile -Force
      Write-Host "Profile has been updated. Please restart your shell to reflect changes." -ForegroundColor Magenta
    }
  }
  catch {
    Write-Error "Unable to check for `$profile updates"
  }
  finally {
    Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
  }
}
Update-Profile

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function prompt {
  if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}

$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString();

function Test-CommandExists {
  param (
    $command
  )
  $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
  return $exists
}

$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists pvim) { 'pvim' }
elseif (Test-CommandExists vim) { 'vim' }
elseif (Test-CommandExists vi) { 'vi' }
elseif (Test-CommandExists code) { 'code' }
elseif (Test-CommandExists notepad++) { 'notepad++' }
else { 'notepad' }
        
Set-Alias -Name vim -Value $EDITOR
function Edit-Profile {
  vim $PROFILE.CurrentUserAllHosts
}

function touch($file) { "" | Out-File $file -Encoding ascii }
function ff($name) {
  Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output "$($_.Directory)\$($_)"
  }
}

function Get-Pub-IP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function uptime {
  if ($PSVersionTable.PSVersion.Major -eq 5) {
    Get-WmiObject win32_operatingsystem | Select-Object @{Name = 'LastBootUpTime'; Expression = { $_.ConverttoDateTime($_.lastbootuptime) } } | Format-Table -HideTableHeaders
  }
  else {
    net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
  }
}

function reload-profile {
  & $profile
}