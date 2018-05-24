# PowerShell script setting base variables for EventMachine fat binary gem
# Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities

New-Variable -Name gem_name -Value 'eventmachine' -Option ReadOnly, AllScope -Scope Script
New-Variable -Name url_repo -Value 'https://github.com/eventmachine/eventmachine.git'  -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— make info
New-Variable -Name dest_so  -Value 'lib' -Option ReadOnly, AllScope -Scope Script
New-Variable -Name exts     -Value @(
  @{ 'conf' = 'ext/extconf.rb'                ; 'so' = 'rubyeventmachine'  },
  @{ 'conf' = 'ext/fastfilereader/extconf.rb' ; 'so' = 'fastfilereaderext' }
) -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— ruby versions
[string[]]$rubies  = '25', '24', '23', '22', '21', '200'
#———————————————————————————————————————————————————————————————— archs to compile
[string[]]$r_archs = 'x64-mingw32', 'i386-mingw32'

New-Variable -Name tag      -Value $env:gem_vers             -Option ReadOnly, AllScope -Scope Script
New-Variable -Name dir_gem  -Value "$PSScriptRoot/$gem_name" -Option ReadOnly, AllScope -Scope Script
New-Variable -Name dir_ps   -Value $PSScriptRoot             -Option ReadOnly, AllScope -Scope Script

#———————————————————————————————————————————————————————————————— repo changes
function Repo-Changes {
  Push-Location $dir_gem
  iex "$msys2/usr/bin/patch.exe -p1 -N --no-backup-if-mismatch -i ../EM_2018-05-25.patch"
  Pop-Location
}

#———————————————————————————————————————————————————————————————— pre compile
function Pre-Compile {
  Check-OpenSSL
  Write-Host Compiling With $env:SSL_VERS
}

#———————————————————————————————————————————————————————————————— Run-Tests
function Run-Tests {
  gem update test-unit -N --user-install
  ruby -v
  rake -N -R norakefiles | Tee-Object -Variable test_results
  ruby -v
  test_unit
}

. ./shared/appveyor_setup.ps1
  ./shared/make.ps1
  ./shared/test.ps1
