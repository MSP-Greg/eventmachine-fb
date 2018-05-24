# PowerShell script setting base variables for EventMachine fat binary gem
# Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities

New-Variable -Name gem_name -Value 'puma' -Option ReadOnly, AllScope -Scope Script
New-Variable -Name url_repo -Value 'https://github.com/puma/puma.git' -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— make info
New-Variable -Name dest_so  -Value 'lib\puma' -Option ReadOnly, AllScope -Scope Script
New-Variable -Name exts -Value @(
  @{ 'conf' = 'ext/puma_http11/extconf.rb' ; 'so' = 'puma_http11'  }
) -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— ruby versions
[string[]]$rubies  = '25', '24', '23', '22'
#———————————————————————————————————————————————————————————————— archs to compile
[string[]]$r_archs = 'x64-mingw32', 'i386-mingw32'

New-Variable -Name tag      -Value $env:gem_vers             -Option ReadOnly, AllScope -Scope Script
New-Variable -Name dir_gem  -Value "$PSScriptRoot/$gem_name" -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— repo changes
function Repo-Changes {
  Push-Location $dir_gem
  iex "$msys2/usr/bin/patch.exe -p1 -N --no-backup-if-mismatch -i ../helper.patch"
  Pop-Location
}

#———————————————————————————————————————————————————————————————— pre compile
function Pre-Compile {
  Check-OpenSSL
  Write-Host Compiling With $env:SSL_VERS
}

#———————————————————————————————————————————————————————————————— Run-Tests
function Run-Tests {
  gem update  minitest -N
  gem install minitest-retry rack -N
  if ( !($in_av) ) { $env:APPVEYOR = 1 }
  ruby -v
  rake | Tee-Object -Variable test_results
  ruby -v
  minitest
  if ( !($in_av) ) { Remove-Item Env:APPVEYOR }
}

. ./appveyor_setup.ps1
#./make.ps1
./test.ps1
