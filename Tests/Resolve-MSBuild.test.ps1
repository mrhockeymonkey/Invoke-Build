
<#
.Synopsis
	Tests of Resolve-MSBuild.ps1

.Example
	Invoke-Build * Resolve-MSBuild.test.ps1
#>

. ./Shared.ps1

if (!($ProgramFiles = ${env:ProgramFiles(x86)})) {$ProgramFiles = $env:ProgramFiles}
$VS2017 = Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017"
$VSSetup = Get-Module VSSetup -ListAvailable

function Test-MSBuild([Parameter()]$Path) {
	if ($Path -notlike '*\MSBuild.exe') {Write-Error "Unexpected path $Path"}
	if (![System.IO.File]::Exists($Path)) {Write-Error "Missing file $Path"}
	$Path
}

# same as in the script
function Get-MSBuild15Path {
	if ([System.IntPtr]::Size -eq 8) {'MSBuild\15.0\Bin\amd64\MSBuild.exe'} else {'MSBuild\15.0\Bin\MSBuild.exe'}
}

task test15VSSetup -If $VS2017 {
	if (!$VSSetup) {Write-Warning 'VSSetup is not installed'}
	$r = Resolve-MSBuild 15.0
	Test-MSBuild $r
	assert ($r -like '*\15.0\*')
}

task test15Guess -If $VS2017 {
	. Set-Mock Get-MSBuild15VSSetup {}
	$r = Resolve-MSBuild 15.0
	Test-MSBuild $r
	assert ($r -like '*\15.0\*')
}

task test14 {
	$r = Resolve-MSBuild 14.0
	Test-MSBuild $r
	assert ($r -like '*\14.0\*')
}

task test40 {
	$r = Resolve-MSBuild 4.0
	Test-MSBuild $r
	assert ($r -like '*\Microsoft.NET\Framework*\v4.0.*\MSBuild.exe')
}

task testAll15 -If $VS2017 {
	$r = Resolve-MSBuild
	Test-MSBuild $r
	assert ($r -like '*\15.0\*')
}

task testAll14 {
	. Set-Mock Get-MSBuild15 {}
	$r = Resolve-MSBuild
	Test-MSBuild $r
	assert ($r -like '*\14.0\*')
}

task missingOld {
	($r = try {Resolve-MSBuild 1.0} catch {$_})
	assert (($r | Out-String) -like '*Cannot resolve MSBuild 1.0 :*Resolve-MSBuild.test.ps1:*')
}

task missingNew {
	($r = try {Resolve-MSBuild 15.1} catch {$_})
	assert (($r | Out-String) -like '*Cannot resolve MSBuild 15.1 :*Resolve-MSBuild.test.ps1:*')
}

task missing15 {
	. Set-Mock Get-MSBuild15 {}
	($r = try {Resolve-MSBuild 15.0} catch {$_})
	assert (($r | Out-String) -like '*Cannot resolve MSBuild 15.0 : *Resolve-MSBuild.test.ps1:*')
}

task invalidVersion {
	($r = try {Resolve-MSBuild invalid} catch {$_})
	assert (($r | Out-String) -like '*Cannot resolve MSBuild invalid :*"invalid"*Resolve-MSBuild.test.ps1:*')
}

task alias-of-Resolve-MSBuild {
	$r = @(Get-Command Resolve-MSBuild)[0]
	equals "$($r.CommandType)" Alias
}

task Get-MSBuild15VSSetup -If $VSSetup {
    . Set-Mock Select-VSSetupInstance {
        param($Product)
        if ($Product -eq '*') {
            $all
        }
        else {
            foreach ($_ in $all) {
                if ($_.Product -eq $Product) {
                    $_
                }
            }
        }
    }

	$all = @{Product = 'Microsoft.VisualStudio.Product.Enterprise'; InstallationPath = 'Enterprise'}
	($r = Resolve-MSBuild)
	equals $r "Enterprise\$(Get-MSBuild15Path)"

	$all = @{Product = 'Microsoft.VisualStudio.Product.Professional'; InstallationPath = 'Professional'}
	($r = Resolve-MSBuild)
	equals $r "Professional\$(Get-MSBuild15Path)"

	$all = @{Product = 'Microsoft.VisualStudio.Product.Community'; InstallationPath = 'Community'}
	($r = Resolve-MSBuild)
	equals $r "Community\$(Get-MSBuild15Path)"

	$all = @{Product = 'Microsoft.VisualStudio.Product.Something'; InstallationPath = 'Something'}
	($r = Resolve-MSBuild)
	equals $r "Something\$(Get-MSBuild15Path)"

	$all = @(
		@{Product = 'Microsoft.VisualStudio.Product.BuildTools'; InstallationPath = 'BuildTools'}
		@{Product = 'Microsoft.VisualStudio.Product.Community'; InstallationPath = 'Community'}
		@{Product = 'Microsoft.VisualStudio.Product.Enterprise'; InstallationPath = 'Enterprise'}
		@{Product = 'Microsoft.VisualStudio.Product.Professional'; InstallationPath = 'Professional'}
		@{Product = 'Microsoft.VisualStudio.Product.TeamExplorer'; InstallationPath = 'TeamExplorer'}
	)
	($r = Resolve-MSBuild)
	equals $r "Enterprise\$(Get-MSBuild15Path)"

	$all = @(
		@{Product = 'Microsoft.VisualStudio.Product.BuildTools'; InstallationPath = 'BuildTools'}
		@{Product = 'Microsoft.VisualStudio.Product.Community'; InstallationPath = 'Community'}
		@{Product = 'Microsoft.VisualStudio.Product.Professional'; InstallationPath = 'Professional'}
		@{Product = 'Microsoft.VisualStudio.Product.TeamExplorer'; InstallationPath = 'TeamExplorer'}
	)
	($r = Resolve-MSBuild)
	equals $r "Professional\$(Get-MSBuild15Path)"

	$all = @(
		@{Product = 'Microsoft.VisualStudio.Product.BuildTools'; InstallationPath = 'BuildTools'}
		@{Product = 'Microsoft.VisualStudio.Product.Community'; InstallationPath = 'Community'}
		@{Product = 'Microsoft.VisualStudio.Product.TeamExplorer'; InstallationPath = 'TeamExplorer'}
	)
	($r = Resolve-MSBuild)
	equals $r "Community\$(Get-MSBuild15Path)"

	$all = @(
		@{Product = 'Microsoft.VisualStudio.Product.BuildTools'; InstallationPath = 'BuildTools'}
		@{Product = 'Microsoft.VisualStudio.Product.TeamExplorer'; InstallationPath = 'TeamExplorer'}
	)
	($r = Resolve-MSBuild)
	equals $r "BuildTools\$(Get-MSBuild15Path)"
}

task Get-MSBuild15Guess {
	. Set-Mock Get-MSBuild15VSSetup {}
	. Set-Mock Test-Path {$true}
	. Set-Mock Resolve-Path {$all}

	$all = @{ProviderPath = '..\Enterprise\..'}
	($r = Resolve-MSBuild)
	equals $r '..\Enterprise\..'

	$all = @{ProviderPath = '..\Professional\..'}
	($r = Resolve-MSBuild)
	equals $r '..\Professional\..'

	$all = @{ProviderPath = '..\Community\..'}
	($r = Resolve-MSBuild)
	equals $r '..\Community\..'

	$all = @{ProviderPath = '..\Something\..'}
	($r = Resolve-MSBuild)
	equals $r '..\Something\..'

	$all = @(
		@{ProviderPath = '..\BuildTools\..'}
		@{ProviderPath = '..\Community\..'}
		@{ProviderPath = '..\Enterprise\..'}
		@{ProviderPath = '..\Professional\..'}
		@{ProviderPath = '..\TeamExplorer\..'}
	)
	($r = Resolve-MSBuild)
	equals $r '..\Enterprise\..'

	$all = @(
		@{ProviderPath = '..\BuildTools\..'}
		@{ProviderPath = '..\Community\..'}
		@{ProviderPath = '..\Professional\..'}
		@{ProviderPath = '..\TeamExplorer\..'}
	)
	($r = Resolve-MSBuild)
	equals $r '..\Professional\..'

	$all = @(
		@{ProviderPath = '..\BuildTools\..'}
		@{ProviderPath = '..\Community\..'}
		@{ProviderPath = '..\TeamExplorer\..'}
	)
	($r = Resolve-MSBuild)
	equals $r '..\Community\..'

	$all = @(
		@{ProviderPath = '..\BuildTools\..'}
		@{ProviderPath = '..\TeamExplorer\..'}
	)
	($r = Resolve-MSBuild)
	equals $r '..\BuildTools\..'
}
