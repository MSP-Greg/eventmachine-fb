# PowerShell script setting base variables for EventMachine fat binary gem
# Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities

. ./shared/appveyor_setup.ps1

Make-Const gem_name  'eventmachine'
Make-Const repo_name 'eventmachine'
Make-Const url_repo  'https://github.com/eventmachine/eventmachine.git'

#———————————————————————————————————————————————————————————————— make info
Make-Const dest_so  'lib'
Make-Const exts     @(
  @{ 'conf' = 'ext/extconf.rb'                ; 'so' = 'rubyeventmachine'  },
  @{ 'conf' = 'ext/fastfilereader/extconf.rb' ; 'so' = 'fastfilereaderext' }
)

#———————————————————————————————————————————————————————————————— ruby versions
[string[]]$rubies  = '25', '24', '23', '22', '21', '200'
#———————————————————————————————————————————————————————————————— archs to compile
[string[]]$r_archs = 'x64-mingw32', 'i386-mingw32'

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
  gem update rake test-unit -N --user-install
  ruby -v
  rake -N -R norakefiles -f Rakefile_wintest | Tee-Object -Variable test_results
  ruby -v
  test_unit
}

#———————————————————————————————————————————————————————————————— Below for all repos
# below is independent of gem
Make-Const tag      $env:gem_vers
Make-Const dir_gem  "$PSScriptRoot\$repo_name"
Make-Const dir_ps   $PSScriptRoot

./shared/make.ps1
./shared/test.ps1
exit $ttl_errors_fails
