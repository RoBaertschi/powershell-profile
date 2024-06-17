$hasInternet = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
  Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module -Name Terminal-Icons

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}


function Update-Profile {
  if (-not $Global:hasInternet) {
    Write-Host "Skipping profile update check due to Github.com not responding in 1 second." -ForegroundColor Yellow
    return
  }

  try {
    $url = "https://raw.githubusercontent.com/RoBaertschi/powershell-profile/master/Microsoft.PowerShell_profile.ps1"
    $oldhash = Get-FileHash $profile
    Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
    $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
    if ($newhash.Hash -ne $oldhash.Hash) {
      Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $profile -Force
      Write-Host "Profile has been updated. Please restart your shell to reflect changes." -ForegroundColor Magenta
    }
  }
  catch {
    Write-Error "Unable to check for `$profile updates. Error: $_"
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

function reload {
  & $profile
}

function unzip($file) {
  Write-Output("Extracting", $file, "to", $pwd)
  $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
  Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function hb {
  if ($args.Lenght -eq 0) {
    Write-Error "No file path specified."
    return
  }

  $FilePath = $args[0]

  if (Test-Path $FilePath) {
    $Content = Get-Content $FilePath -Raw
  }
  else {
    Wirte-Error "File path does not exist."
    return
  }

  $uri = "http://bin.chirstitus.com/documents"
  try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
    $hasteKey = $response.key
    $url = "http://bin.christitus.com/$hasteKey"
    Write-Output $url
  }
  catch {
    Write-Error "Failed to upload the document. Error: $_"
  }
}

function df {
  Get-Volume
}

function sed($file, $find, $replace) {
  (Get-Content $file).Replace("$find", $replace) | Set-Content $file
}

function which($name) {
  Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
  Set-Item -Force -Path "env:$name" -Value $value
}

function pkill($name) {
  Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
  Get-Process $name
}

function head() {
  params($Path, $n = 10)
  Get-Content $Path -Head $n
}


function tail() {
  params($Path, $n = 10)
  Get-Content $Path -Tail $n
}

function n {
  param($name)
  New-Item -ItemType "file" -Path . -Name $name
}

function mkcd($dir) {
  mkdir $dir -Force
  Set-Location $dir
}

function ep() { vim $PROFILE }

function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }


function gcom {
  git add .
  git commit -m "$args"
}
function lazyg {
  git add .
  git commit -m "$args"
  git push
}

function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns { Clear-DnsClientCache }

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
  Command   = 'Yellow'
  Parameter = 'Green'
  String    = 'DarkCyan'
}

oh-my-posh init pwsh --config "https://raw.githubusercontent.com/RoBaertschi/powershell-profile/master/robaertschi.omp.toml" | Invoke-Expression

if (Get-Command fzf -ErrorAction SilentlyContinue) {
  Import-Module PSFzf


  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

  Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
}
else {
  try {
    winget install -e -id junegunn.fzf
    Write-Host "fzf installed successfully. Initializing..." 
    Install-Module -Name PSFzf -Force -SkipPublisherCheck
    Import-Module PSFzf


    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
      -PSReadlineChordReverseHistory 'Ctrl+r'

    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
  }
  catch {
    Write-Error "Failed to install fzf. Error: $_"
  }
}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
  if (-not (Test-Path -Path "${env:LOCALAPPDATA}\nvim")) {
    git clone "https://github.com/robaertschi/nvim-kickstart" "${env:LOCALAPPDATA}\nvim"
  }
}


if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& {
      $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell --cmd cd | Out-String)
    })
}
else {
  try {
    winget install -e -id ajeetdsouza.zoxide
    Write-Host "zoxide installed successfully. Initializing..." 
    Invoke-Expression (& {
        $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell --cmd cd | Out-String)
      })
  }
  catch {
    Write-Error "Failed to install zoxide. Error: $_"
  }
}


#34de4b3d-13a8-4540-b76d-b9e8d3851756 PowerToys CommandNotFound module

Import-Module "C:\Program Files\PowerToys\WinUI3Apps\..\WinGetCommandNotFound.psd1"
#34de4b3d-13a8-4540-b76d-b9e8d3851756
