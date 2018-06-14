<#
PowerShell script for testing of fat binary gems

This script is utility script, and should not require changes for any gems

Code by MSP-Greg, see https://github.com/MSP-Greg/appveyor-utilities
#>

New-Variable -Name test_results     -Value ''  -Option AllScope -Scope Script
New-Variable -Name test_summary     -Value ''  -Option AllScope -Scope Script
New-Variable -Name r_arch           -Value ''  -Option AllScope -Scope Script
New-Variable -Name first_arch       -Value ''  -Option AllScope -Scope Script
New-Variable -Name gem_suf          -Value ''  -Option AllScope -Scope Script
New-Variable -Name gem_full         -Value ''  -Option AllScope -Scope Script

$dt = Get-Date -UFormat "%Y-%m-%d_%H-%M"

function Get-MS {
  if ($test_summary -match "(?m)^Finished in (\d+\.\d{3})" ) {
    return [int]([float]$matches[1] * 1000)
  } else { return $null}
}

function AV-Test($outcome) {
  if ($outcome -eq 'Failed') {
    Add-AppveyorTest -Name "Ruby$ruby$suf" -Outcome 'Failed' `
      -StdOut $test_results.replace("`n", "`r`n") -Framework "ruby" `
      -FileName $gem_full
  } else {
    $oc = if ($outcome -eq 0) {'Passed'} else {'Failed'}
    $ms = Get-MS
    Add-AppveyorTest -Name "Ruby$ruby$suf" -Outcome $oc -Duration $ms `
      -StdOut $test_results.replace("`n", "`r`n") -Framework "ruby" `
      -FileName $gem_full
  }
}

# minitest result parser
function minitest {
  if ($test_summary -eq '') {
    $test_summary   = " Runs  Asserts  Fails  Errors  Skips  Ruby"
    $test_summary += "`n                                                  $r_arch"
    $first_arch = $r_arch
  }
  if ( $r_arch -ne $first_arch) {
    $test_summary += "`n                                                  $r_arch"
    $first_arch = $r_arch
  }

  $results = ($test_results -match "(?m)^\d+ runs.+ skips" | Out-String)

  if ($results) {
    $ary = ($results -replace "[^\d]+", ' ').Trim().Split(' ')
    $errors_fails = [int]$ary[2] + [int]$ary[3]
    # if ($in_av) { AV-Test $errors_fails }
    $ttl_errors_fails += $errors_fails
    $ary += @("Ruby$ruby$suf") + $ruby_v
    $test_summary += "`n{0,4:n}    {1,4:n}   {2,4:n}    {3,4:n}    {4,4:n}   {5,-11} {6,-15} ({7}" -f $ary
  } else {
    # if ($in_av) { AV-Test 'Failed' }
    ttl_errors_fails += 1000
    $ary = @("Ruby$ruby$suf") + $ruby_v
    $test_summary += "`ntesting aborted?                      {0,-11} {1,-15} ({2}}" -f $ary
  }
}

# test-unit results parser
function test_unit {
  if ($test_summary -eq '') {
    $test_summary    = "Tests  Asserts  Fails  Errors  Pend  Omitted  Notes  Ruby"
    $test_summary += "`n                                                                 $r_arch"
    $first_arch = $r_arch
  }
  if ( $r_arch -ne $first_arch) {
    $test_summary += "`n                                                                 $r_arch"
    $first_arch = $r_arch
  }
  $results = ($test_results -match "(?m)\d+ tests.+ notifications" | Out-String)
  if ($results) {
    $ary = ($results -replace "[^\d]+", ' ').Trim().Split(' ')
    $errors_fails = [int]$ary[2] + [int]$ary[3]
    # if ($in_av) { AV-Test $errors_fails }
    $ttl_errors_fails += $errors_fails
    $ary += @("Ruby$ruby$suf") + $ruby_v
    $test_summary += "`n{0,4:n}    {1,4:n}   {2,4:n}    {3,4:n}   {4,4:n}    {5,4:n}   {6,4:n}    {7,-11} {8,-15} ({9}" -f $ary
  } else {
    # if ($in_av) { AV-Test 'Failed' }
    $ary = @("Ruby$ruby$suf") + $ruby_v
    $ttl_errors_fails += 1000
    $test_summary += "`ntesting aborted?                                     {0,-11} {1,-15} ({2}" -f $ary
  }
Write-Host ttl_errors_fails $ttl_errors_fails
}

foreach ($r_arch in $r_archs) {
  if ($r_arch -eq 'x64-mingw32') { $suf = '-x64' ; $gem_suf = '-x64-mingw32' }
                            else { $suf = ''     ; $gem_suf = '-x86-mingw32' }

  $gem_full = $gem_name + '-' + $env:GEM_VERS + $gem_suf

  $fn = $dir_gem + '/' + $gem_full + '.gem'
  
  foreach ($ruby in $rubies) {
    # Loop if ruby version does not exist
    if( !(Test-Path -Path $dir_ruby$ruby$suf -PathType Container) ) { $foreach.MoveNext | Out-Null }

    # Set up path with Ruby bin
    $env:path =  "$dir_ruby$ruby$suf\bin;" + $base_path
    $env:ruby_version = "$ruby$suf"
    Check-SetVars

    Write-Host "`n$($dash * 75) Testing Ruby$ruby$suf" -ForegroundColor $fc
    if ( !($in_av) ) { gem uninstall $gem_name -x -a }
    gem install $fn -Nl

    # Find where gem was installed - default or user
    $rake_dir = $gem_dflt + '/gems/' + $gem_full
    if ( !(Test-Path -Path $rake_dir -PathType Container) ) {
      $rake_dir = "$gem_user/gems/$gem_full"
      if ( !(Test-Path -Path $rake_dir -PathType Container) ) { continue }
    }
    $ruby_v = [regex]::split( (ruby.exe -v | Out-String).Replace(" [$r_arch]", '').Trim(), ' \(')
    Push-Location $rake_dir
    Run-Tests
    Pop-Location
  }
}

Write-Host "`n$($dash * 75) Test Summary" -ForegroundColor $fc
Write-Host $test_summary
Write-Host ($dash * 88) -ForegroundColor $fc
