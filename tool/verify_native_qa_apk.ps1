param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$JavaHome,
    [string]$AndroidSdk = "$env:LOCALAPPDATA/Android/sdk",
    [switch]$NormalEntry,
    [switch]$AudioQa
)
$ErrorActionPreference = 'Stop'
$checkout = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$apk = (Resolve-Path -LiteralPath $ApkPath).Path
$buildTools = Join-Path $AndroidSdk 'build-tools/35.0.0'
$badging = & (Join-Path $buildTools 'aapt.exe') dump badging $apk
if ($LASTEXITCODE -ne 0) { throw 'APK badging failed.' }
$badgingText = $badging -join "`n"
$expectedPackage = if ($AudioQa) { 'com.halabessa.game.audioqa' } else { 'com.halabessa.game' }
foreach ($pattern in @("package: name='$expectedPackage'", "sdkVersion:'24'", "targetSdkVersion:'36'",
        "launchable-activity: name='com.halabessa.game.MainActivity'",
        'android.permission.VIBRATE')) {
    if (-not $badgingText.Contains($pattern)) { throw "Missing APK contract: $pattern" }
}
if ($AudioQa -and -not $badgingText.Contains("application-label:'Halabessa Audio QA'")) {
    throw 'Expected the clearly labeled side-by-side Audio QA test app.'
}
$manifest = & (Join-Path $buildTools 'aapt.exe') dump xmltree $apk AndroidManifest.xml
if ($LASTEXITCODE -ne 0 -or @($manifest | Select-String 'android.intent.category.LAUNCHER').Count -ne 1) {
    throw 'Expected exactly one launcher category in the packaged manifest.'
}
& (Join-Path $buildTools 'zipalign.exe') -c -P 16 4 $apk
if ($LASTEXITCODE -ne 0) { throw 'APK ZIP alignment failed.' }
$priorJava = $env:JAVA_HOME
try {
    $env:JAVA_HOME = $JavaHome
    $signature = & (Join-Path $buildTools 'apksigner.bat') verify --verbose $apk
    if ($LASTEXITCODE -ne 0 -or -not (($signature -join "`n") -match 'v2 scheme.*true')) {
        throw 'APK signature verification failed.'
    }
} finally { $env:JAVA_HOME = $priorJava }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
function EntryBytes($entry) {
    if ($null -eq $entry) { throw 'Missing APK entry.' }
    $stream = $entry.Open()
    $memory = [IO.MemoryStream]::new()
    try { $stream.CopyTo($memory); return ,$memory.ToArray() }
    finally { $stream.Dispose(); $memory.Dispose() }
}
function BytesHash([byte[]]$bytes) {
    $digest = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($digest.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $digest.Dispose() }
}
try {
    $libraries = @($archive.Entries | Where-Object { $_.FullName -match '^lib/[^/]+/[^/]+\.so$' })
    $abis = @($libraries | ForEach-Object { $_.FullName.Split('/')[1] } | Sort-Object -Unique)
    if ($abis.Count -ne 1 -or $abis[0] -ne 'arm64-v8a') { throw 'This QA APK must be ARM64-only.' }
    foreach ($name in @('libunity.so', 'libil2cpp.so', 'libflutter.so', 'libmain.so')) {
        if ($null -eq $archive.GetEntry("lib/arm64-v8a/$name")) { throw "Missing $name" }
    }
    $elfResults = @()
    foreach ($entry in $libraries) {
        [byte[]]$bytes = EntryBytes $entry
        if ([BitConverter]::ToString($bytes, 0, 6) -ne '7F-45-4C-46-02-01' -or
                [BitConverter]::ToUInt16($bytes, 18) -ne 183) { throw "Expected little-endian ARM64 ELF: $($entry.FullName)" }
        $offset = [BitConverter]::ToUInt64($bytes, 32)
        $size = [BitConverter]::ToUInt16($bytes, 54)
        $count = [BitConverter]::ToUInt16($bytes, 56)
        if ($size -lt 56 -or $offset + [uint64]$size * $count -gt $bytes.Length) { throw 'Invalid ELF program headers.' }
        $loads = 0
        for ($i = 0; $i -lt $count; $i++) {
            $header = [int]($offset + $i * $size)
            if ([BitConverter]::ToUInt32($bytes, $header) -ne 1) { continue }
            $loads++
            $fileOffset = [BitConverter]::ToUInt64($bytes, $header + 8)
            $virtual = [BitConverter]::ToUInt64($bytes, $header + 16)
            $alignment = [BitConverter]::ToUInt64($bytes, $header + 48)
            if ($alignment -lt 16384 -or $fileOffset % 16384 -ne $virtual % 16384) {
                throw "ELF 16 KB alignment failed: $($entry.FullName), PT_LOAD $i, alignment $alignment"
            }
        }
        if ($loads -eq 0) { throw 'Expected loadable ELF segments.' }
        $elfResults += [pscustomobject]@{ file = $entry.FullName; loadSegments = $loads; sha256 = (BytesHash $bytes) }
    }
    [byte[]]$metadata = EntryBytes ($archive.GetEntry('assets/bin/Data/Managed/Metadata/global-metadata.dat'))
    $metadataText = [Text.Encoding]::UTF8.GetString($metadata)
    foreach ($marker in @('UNITY_CARD_FEEL_READY', 'HAND_SELECTION', 'VISUAL_CONTACT', 'VISUAL_ACTION_COMPLETE')) {
        if (-not $metadataText.Contains($marker)) { throw "Missing current native protocol: $marker" }
    }
    $exportMetadata = Join-Path $checkout 'build/unity-native-qa-2026-10-22/android/unityLibrary/src/main/assets/bin/Data/Managed/Metadata/global-metadata.dat'
    if ((BytesHash $metadata) -ne (Get-FileHash -LiteralPath $exportMetadata).Hash.ToLowerInvariant()) {
        throw 'Packaged metadata differs from the fresh native export.'
    }
    [byte[]]$kernel = EntryBytes ($archive.GetEntry('assets/flutter_assets/kernel_blob.bin'))
    $kernelText = [Text.Encoding]::UTF8.GetString($kernel)
    $preview = $kernelText.Contains('tool/option_b_preview.dart')
    $selectedAudioVerified = $false
    if ($AudioQa) {
        [byte[]]$selectionBytes = EntryBytes ($archive.GetEntry('assets/flutter_assets/assets/audio/defaults/2026-10-24/selection.json'))
        $selection = [Text.Encoding]::UTF8.GetString($selectionBytes) | ConvertFrom-Json
        $routes = @($selection.bundledFiles.PSObject.Properties)
        if ($routes.Count -ne 16) { throw 'Expected all 16 selected audio routes.' }
        foreach ($route in $routes) {
            $relative = [string]$route.Value
            if ($relative -notmatch '^audio/defaults/2026-10-24/[a-z0-9-]+\.wav$') { throw 'Unexpected selected audio path.' }
            [byte[]]$packagedSound = EntryBytes ($archive.GetEntry("assets/flutter_assets/assets/$relative"))
            $sourcePath = Join-Path $checkout "assets/$relative"
            if ((BytesHash $packagedSound) -ne (Get-FileHash -LiteralPath $sourcePath).Hash.ToLowerInvariant()) {
                throw "Selected sound differs from reviewed bytes: $($route.Name)"
            }
        }
        $selectedAudioVerified = $true
    }
    if ($NormalEntry) {
        if ($preview -or -not ($kernelText.Contains('lib/main.dart') -or
                $kernelText.Contains('package:halabessa/main.dart'))) {
            throw 'Expected the normal app entrypoint without the offline QA target.'
        }
    } elseif (-not $preview) {
        throw 'Expected the explicit offline QA entrypoint.'
    }
    [pscustomobject]@{
        apk = $apk; bytes = (Get-Item -LiteralPath $apk).Length
        sha256 = (Get-FileHash -LiteralPath $apk).Hash.ToLowerInvariant()
        packageId = $expectedPackage; minSdk = 24; targetSdk = 36
        launcherCount = 1; abi = 'arm64-v8a'
        signatureVerified = $true; zip16KbAligned = $true; elf16KbAligned = $true
        currentProtocolVerified = $true; offlineQaEntrypoint = $preview
        normalEntrypoint = [bool]$NormalEntry; deviceTested = $false
        selectedAudioVerified = $selectedAudioVerified
        libraries = $elfResults
    } | ConvertTo-Json -Depth 5
} finally { $archive.Dispose() }
