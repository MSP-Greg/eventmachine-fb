# PowerShell script for updating MSYS2 / MinGW, installing OpenSSL and other packages
# Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities

#————————————————————————————————————————————————————————————————————————————————— Make-Const
# Readonly, available in all session scripts
function Make-Const($N, $V) {
  New-Variable -Name $N -Value $V -Option ReadOnly, AllScope -Scope Script
}

#————————————————————————————————————————————————————————————————————————————————— Constants
if ($env:APPVEYOR) {
  Make-Const dflt_ruby 'C:\ruby25-x64'
  Make-Const in_av     $true
  
  # MinGW & Base Ruby
  Make-Const msys2    'C:\msys64'
  Make-Const dir_ruby 'C:\Ruby'

  # DevKit paths
  Make-Const DK32w    'C:\Ruby23\DevKit'
  Make-Const DK64w    'C:\Ruby23-x64\DevKit'
  
  # Folder for storing downloaded packages
  Make-Const pkgs     "$PSScriptRoot/../packages"

  # Use simple base path without all Appveyor additions
  Make-Const base_path 'C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;C:\Program Files\Git\cmd;'
  
  Make-Const 7z        "$env:ProgramFiles\7-Zip\7z.exe"
  Make-Const fc        'Yellow'
} else {
  . $PSScriptRoot\local_paths.ps1
}

if( !(Test-Path -Path $pkgs -PathType Container) ) { New-Item -Path $pkgs -ItemType Directory 1> $null }

Make-Const dir_user  "$env:USERPROFILE\.gem\ruby\"
# Download locations
Make-Const ri1_pkgs  'https://dl.bintray.com/oneclick/OpenKnapsack'
Make-Const ri2_pkgs  'https://dl.bintray.com/larskanis/rubyinstaller2-packages'
Make-Const rubyloco  'https://dl.bintray.com/msp-greg/ruby_trunk'

# Misc
Make-Const SSL_CERT_FILE "$dflt_ruby\ssl\cert.pem"
Make-Const ks            'na.pool.sks-keyservers.net'
Make-Const dash          "$([char]0x2015)"
Make-Const wc            $(New-Object System.Net.WebClient)

New-Variable -Name isRI2    -Option AllScope -Scope Script  # true for Ruby >= 2.4
New-Variable -Name is64     -Option AllScope -Scope Script  # true for 64 bit
New-Variable -Name m        -Option AllScope -Scope Script  # MSYS2 package prefix
New-Variable -Name mingw    -Option AllScope -Scope Script  # mingw32 or mingw64
New-Variable -Name abi_vers -Option AllScope -Scope Script  # ruby ABI vers, like '2.3.0'
New-Variable -Name gem_dflt -Option AllScope -Scope Script  # Gem.default_dir
New-Variable -Name gem_user -Option AllScope -Scope Script  # Gem.user_dir
New-Variable -Name dk_b     -Option AllScope -Scope Script  # DevKit folder 

New-Variable -Name need_refresh -Value $true -Option AllScope -Scope Script
New-Variable -Name ssl_vhash    -Value @{}   -Option AllScope -Scope Script

#—————————————————————————————————————————————————————————————————————————————— Check-SetVars
# assumes path is already set
function Check-SetVars {
  $isRI2 = $env:ruby_version -ge '24'         -Or  $env:ruby_version -eq '_trunk'
  $is64  = $env:ruby_version.EndsWith('-x64') -Or  $env:ruby_version -eq '_trunk'

  if ($is64) { $m = 'mingw-w64-x86_64-' ; $mingw = 'mingw64' }
    else     { $m = 'mingw-w64-i686-'   ; $mingw = 'mingw32' }

  if ( !($isRI2) ) {
# Write-Host "Setting b_config to -- --with-opt-include=$DKu/mingw/include"  -ForegroundColor $fc
    $env:SSL_CERT_FILE = $SSL_CERT_FILE
  } else {
# Write-Host "Setting b_config to -- --use-system-libraries"  -ForegroundColor $fc
    $env:b_config = '-- --use-system-libraries'    
  }

  $t = (&ruby.exe -e "STDOUT.write Gem.default_dir + '|' + Gem.user_dir" | Out-String).Trim()
  $gem_dflt, $gem_user = $t.Split('|')
  $env:path += $gem_user.Replace('/', '\') + "\bin"
  $abi_vers = $gem_dflt.Split('/')[-1]
}

#—————————————————————————————————————————————————————————————————————————————— Check-OpenSSL
function Check-OpenSSL {
  Check-SetVars

  # Set OpenSSL versions - 2.4 uses standard MinGW 1.0.2 package
  $openssl = if ($env:ruby_version -eq '_trunk') { 'openssl-1.1.0.h' } # trunk
         elseif ($env:ruby_version -lt '20')     { 'openssl-1.0.0o'  } # 1.9.3
         elseif ($env:ruby_version -lt '22')     { 'openssl-1.0.1l'  } # 2.0, 2.1, 2.2
         elseif ($env:ruby_version -lt '24')     { 'openssl-1.0.2j'  } # 2.3
         elseif ($env:ruby_version -lt '25')     { 'openssl-1.0.2o'  } # 2.4
         else                                    { 'openssl-1.1.0.h' } # 2.5
         
  if (!$isRI2) {
    #————————————————————————————————————————————————————————————————————————— RubyInstaller
    if ($is64) { $DKw = $DK64w ; $86_64 = 'x64' ; $dk_b = 'x86_64-w64-mingw32' }
    else       { $DKw = $DK32w ; $86_64 = 'x86' ; $dk_b = 'i686-w64-mingw32'   }

    $DKu = $DKw.Replace('\', '/')
    if ($ssl_vhash[$86_64] -ne $openssl) {
      Write-Host $openssl - Retrieving and installing -ForegroundColor $fc
      # Install it
      if ($is64) { DevKit-Package $openssl 64
          } else { DevKit-Package $openssl 32 }
      # Set hash to indicate it's loaded
      $ssl_vhash[$86_64] = $openssl
    } else {
      Write-Host $openssl - Already installed -ForegroundColor $fc
    }

    $env:SSL_CERT_FILE = $SSL_CERT_FILE
    $env:OPENSSL_CONF  = "$DKu/mingw/ssl/openssl.cnf"
    $env:SSL_VERS = (&"$DKu/mingw/$dk_b/bin/openssl.exe" version | Out-String).Trim()
  } else {
    #————————————————————————————————————————————————————————————————————————— RubyInstaller2
    if ($is64) { $key = '77D8FA18' ; $uri = $rubyloco ; $mingw = 'mingw64' }
      else     { $key = 'BE8BF1C5' ; $uri = $ri2_pkgs ; $mingw = 'mingw32' }

    if ($ssl_vhash[$mingw] -ne $openssl) {
      Write-Host $openssl - Retrieving and installing -ForegroundColor $fc
      $t = $openssl
      if ($env:ruby_version.StartsWith('24')) {
        &"$msys2\usr\bin\pacman.exe" -S --noconfirm --noprogressbar $($m + 'openssl')
      } else {
        $openssl = "$m$openssl-1-any.pkg.tar.xz"
        if( !(Test-Path -Path $pkgs/$openssl -PathType Leaf) ) {
          $wc.DownloadFile("$uri/$openssl"    , "$pkgs/$openssl")
        }
        if( !(Test-Path -Path $pkgs/$openssl.sig -PathType Leaf) ) {
          $wc.DownloadFile("$uri/$openssl.sig", "$pkgs/$openssl.sig")
        }
        Push-Location -Path $msys2\usr\bin
        $t1 = "pacman-key -r $key --keyserver $ks && pacman-key -f $key && pacman-key --lsign-key $key"
        &"$msys2\usr\bin\bash.exe" -lc $t1 2> $null
        Pop-Location

        &"$msys2\usr\bin\pacman.exe" -Rdd --noconfirm --noprogressbar $($m + 'openssl')
        &"$msys2\usr\bin\pacman.exe" -Udd --noconfirm --noprogressbar --force $pkgs/$openssl
      }
      $ssl_vhash[$mingw] = $t
    } else {
      Write-Host $openssl - Already installed -ForegroundColor $fc
    }
    $env:SSL_VERS = (&"$msys2\$mingw\bin\openssl.exe" version | Out-String).Trim()
  }
}

#—————————————————————————————————————————————————————————————————————————————— Check-Update
function Check-Update {
  Check-SetVars
  if ($isRI2) {
    Write-Host "$($dash * 65) Updating MSYS2 / MinGW base-devel" -ForegroundColor $fc
    $s = if ($need_refresh) { '-Sy' } else { '-S' }
    try   { &"$msys2\usr\bin\pacman.exe" $s --noconfirm --needed --noprogressbar base-devel 2> $null }
    catch { Write-Host 'Cannot update base-devel' }
    Write-Host "$($dash * 65) Updating MSYS2 / MinGW toolchain" -ForegroundColor $fc
    try   { &"$msys2\usr\bin\pacman.exe" -S --noconfirm --needed --noprogressbar $($m + 'toolchain') 2> $null }
    catch { Write-Host 'Cannot update toolchain' }
    $need_refresh = $false
  }
}

#—————————————————————————————————————————————————————————————————————————————— DevKit-Package
# $pkg parameter is <name-version>
# $b parameter should be 32, 64, or null for both
function DevKit-Package($pkg, $b) {
  $bits = if ($b -eq 32 -Or $b -eq 64) { @($b) } else { @(32,64) }
  foreach ($bit in $bits) {
    if ($bit -eq 32) { 
             $DKw = $DK32w ; $86_64 = 'x86' ; $dk_b = 'i686-w64-mingw32'   }
      else { $DKw = $DK64w ; $86_64 = 'x64' ; $dk_b = 'x86_64-w64-mingw32' }

    Write-Host DevKit - $pkg $bit bit - Retrieving and Installing... -ForegroundColor $fc
    # Download & upzip into DK folder
    $pkg_i = $pkg + '-' + $86_64 + '-windows.tar.lzma'
    if( !(Test-Path -Path $pkgs/$pkg_i -PathType Leaf) ) {
      $wc.DownloadFile("$ri1_pkgs/$86_64/$pkg_i", "$pkgs/$pkg_i")
    }
    $t = '-o' + $pkgs
    &$7z e -y $pkgs\$pkg_i $t 1> $null
    $pkg_i = $pkg_i -replace "\.lzma\z", ""
    $p = "-o$DKw\mingw\$dk_b"
    &$7z x -y $pkgs\$pkg_i $p 1> $null
  }
}

#—————————————————————————————————————————————————————————————————————————————— MSYS2-Package
function MSYS2-Package($pkg) {
  Check-SetVars
  $s = if ($need_refresh) { '-Sy' } else { '-S' }
  try   { &"$msys2\usr\bin\pacman.exe" $s --noconfirm --needed --noprogressbar $m$pkg }
  catch { Write-Host "Cannot install/update $pkg package" }
  if (!$ri2 -And $pkg -eq 'ragel') { $env:path += ";$msys2\$mingw\bin" }
  $need_refresh = $false
}

#——————————————————————————————————————————————————————————————————————————————————————— Main
# Update MSYS2 / MinGW or install MinGW packages passed as parameters
# Pass --update to update MSYS2 / MinGW
# Pass --strip with 2nd argument of array, strips all so files, can't be used with
#  other args        
# Pass openssl updates to correct version
# Pass <package> package

$need_refresh = $true                    # used to run pacman y option only once

if ($args[0]) {
  switch ( $args[0] ) {
    '--strip' {
      foreach ($arg in $args[1]) {
        &"$msys2\$mingw\bin\strip.exe" --strip-unneeded -p $arg
      }
    }
    default {
      foreach ($arg in $args) {
        switch ( $arg ) {
          '--update' {
            Check-Update
          }
          'openssl' {
            Write-Host "$($dash * 65) Checking OpenSSL"
            Check-OpenSSL
          }
          default {
            Write-Host "$($dash * 65) Checking Package: $arg"
            MSYS2-Package $arg
          }
        }
      }
    }
  }
}