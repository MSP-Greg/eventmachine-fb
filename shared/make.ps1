<#
PowerShell script for compiling all so files needed for fat binary gems

This script is utility script, and should not require changes for any gems

Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities
#>

# delete everything in gem directory
if ( Test-Path -Path $dir_gem -PathType Container) {
  Remove-Item -Path $dir_gem -Recurse -Force
}

#———————————————————————————————————————————————————————— Download & Process Repo
Write-Host "Cloning $repo_name..." -ForegroundColor $fc
#git clone -q --depth=5 --branch=v$tag $url_repo $dir_gem
git.exe clone -q --depth=5 --branch=master $url_repo $dir_gem

# Typically for patches, etc
Repo-Changes

# Copy fat binary rb files if used
foreach ($ext in $exts) {
  $fn = $ext.so + '.rb'
  if ( Test-Path -Path $dir_ps\$fn -PathType Leaf) {
    Copy-Item -Path $dir_ps\$fn -Destination $dir_gem\$dest_so\$fn -Force
  }
}

# Copy Rakefile_wintest if it exists
if ( Test-Path -Path ./Rakefile_wintest -PathType Leaf) {
  Copy-Item -Path $dir_ps\Rakefile_wintest -Destination $dir_gem -Force
}

foreach ($r_arch in $r_archs) {

  [string[]]$so_dests = @()

  if ($r_arch -eq 'x64-mingw32')
        { $suf = '-x64' ; $dk = $DK64w ; $plat = 'x64-mingw32' }
   else { $suf = ''     ; $dk = $DK32w ; $plat = 'x86-mingw32' }

  # Update MSYS2 base files (toolchain & base-devel)
  $env:ruby_version = "24$suf"
  Check-SetVars
  Check-Update
 
  foreach ($ruby in $rubies) {
    # Loop if ruby version does not exist
    if( !( Test-Path -Path $dir_ruby$ruby$suf  -PathType Container) ) {
      $foreach.MoveNext | Out-Null }
   
    # Set up path with Ruby bin
    $env:path = "$dir_ruby$ruby$suf\bin;"

    # Add build system bin folders
    $env:path += if ($ruby -ge '24') { "$msys2\$mingw\bin;$msys2\usr\bin;" }
                                else { "$dk\mingw\bin;$dk\bin;"            }

    # Add base items
    $env:path += $base_path
    
    # match Appveyor variable for use in appveyor_setup.ps1
    $env:ruby_version = "$ruby$suf"

    # Out info to console
    Write-Host "`n$($dash * 75) ruby$ruby$suf" -ForegroundColor $fc
    Check-SetVars
    ruby.exe -v
    Write-Host RubyGems (gem --version)

    Pre-Compile

    if ($abi_digits -eq 2) { $abi_vers = $abi_vers -replace "\.0\z", "" }
    
    $dest = "$dir_gem\$dest_so\$abi_vers"
    New-Item -Path $dest -ItemType Directory 1> $null
    $so_dests += $dest
    foreach ($ext in $exts) {
      $so = $ext.so
      $src_dir = "$dir_gem\tmp\$r_arch\$so\$abi_vers"
      New-Item -Path $src_dir -ItemType Directory 1> $null
      Push-Location -Path $src_dir
      Write-Host "`n$($dash * 50)" Compiling ruby$ruby$suf $ext.so -ForegroundColor $fc
      if ($env:b_config) {
        Write-Host "options:$($env:b_config.replace("--", "`n   --"))" -ForegroundColor $fc
      }
      # Invoke-Expression needed due to spaces in $env:b_config
      iex "ruby.exe -I. $dir_gem\$($ext.conf) $env:b_config"
      if ($isRI2) { make -j2 } else { make }

      $fn = $so + '.so'
      Write-Host Creating $dest_so\$abi_vers\$fn
      Copy-Item -Path $fn -Destination $dest\$fn -Force
      Pop-Location
    }
  }
  # Strip all *.so files
  [string[]]$sos = Get-ChildItem -Include *.so -Path $dir_gem\$dest_so -Recurse | select -expand fullname
  foreach ($so in $sos) {
    &"$msys2\$mingw\bin\strip.exe" --strip-unneeded -p $so
  }

  # package gem
  Write-Host "`n$($dash * 60)" Packaging Gem $plat -ForegroundColor $fc
  $env:path = $dir_ruby + "25-x64\bin;$base_path"
  ruby.exe $dir_ps\package_gem.rb $plat

  # remove so folders
  foreach ($so_dest in $so_dests) { Remove-Item  -Path $so_dest -Recurse -Force }
}

#————————————————————————————————————————————————————————— save gems if appveyor
if ($in_av) {
  Write-Host "`n$($dash * 60)" Saving gems as artifacts -ForegroundColor $fc
  $fn = $dir_gem + '/' + $gem_name + '-' + $env:gem_vers + '-x86-mingw32.gem'
  Push-AppveyorArtifact $fn
  $fn = $dir_gem + '/' + $gem_name + '-' + $env:gem_vers + '-x64-mingw32.gem'
  Push-AppveyorArtifact $fn
}
