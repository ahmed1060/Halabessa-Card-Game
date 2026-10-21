param(
    [Parameter(Mandatory = $true)][string]$JavaHome,
    [string]$CacheRoot = "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1"
)
$ErrorActionPreference = 'Stop'
$checkoutRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$qaRoot = Join-Path $checkoutRoot 'build/native-manifest-qa'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
function CachedJar([string]$group, [string]$artifact, [string]$version) {
    $folder = Join-Path $CacheRoot "$group/$artifact/$version"
    $jars = @(Get-ChildItem -LiteralPath $folder -Filter '*.jar' -Recurse -File)
    if ($jars.Count -ne 1) { throw "Expected one cached $group/$artifact/$version jar; no downloads are performed." }
    return $jars[0].FullName
}
$dependencies = @(
    @('com.android.tools.build', 'manifest-merger', '31.10.1'),
    @('com.android.tools', 'common', '31.10.1'),
    @('com.android.tools', 'annotations', '31.10.1'),
    @('com.android.tools', 'sdk-common', '31.10.1'),
    @('com.android.tools', 'sdklib', '31.10.1'),
    @('com.android.tools', 'repository', '31.10.1'),
    @('com.android.tools', 'dvlib', '31.10.1'),
    @('com.android.tools.layoutlib', 'layoutlib-api', '31.10.1'),
    @('com.google.guava', 'guava', '33.3.1-jre'),
    @('com.google.guava', 'failureaccess', '1.0.2'),
    @('com.google.code.gson', 'gson', '2.11.0'),
    @('org.jetbrains.kotlin', 'kotlin-stdlib', '2.1.0')
)
$classpath = ($dependencies | ForEach-Object { CachedJar $_[0] $_[1] $_[2] }) -join [IO.Path]::PathSeparator
& (Join-Path $JavaHome 'bin/javac.exe') -classpath $classpath -d $qaRoot (Join-Path $PSScriptRoot 'NativeManifestQa.java')
if ($LASTEXITCODE -ne 0) { throw 'QA helper compilation failed.' }
& (Join-Path $JavaHome 'bin/java.exe') -classpath "$qaRoot$([IO.Path]::PathSeparator)$classpath" NativeManifestQa $checkoutRoot
if ($LASTEXITCODE -ne 0) { throw 'Android manifest merger rejected the QA inputs.' }
Push-Location $checkoutRoot
try {
node (Join-Path $PSScriptRoot 'verify_native_entrypoints.mjs') (Join-Path $qaRoot 'merged-fixed.xml')
if ($LASTEXITCODE -ne 0) { throw 'Merged launcher check failed.' }
node --input-type=module -e "import {readFileSync} from 'node:fs'; import {launcherActivities} from './tool/verify_native_entrypoints.mjs'; const baseline=launcherActivities(readFileSync('./build/native-manifest-qa/merged-baseline.xml','utf8')); if(baseline.length!==2)throw Error('Negative control must reproduce two launchers: '+JSON.stringify(baseline)); console.log('Negative control launchers:',baseline);"
if ($LASTEXITCODE -ne 0) { throw 'Negative-control check failed.' }
} finally { Pop-Location }
