param([switch]$Check)

# Deterministic size exports of the approved artwork, not a new logo design.
# Uses Windows' built-in image encoder; no paid services or extra dependencies.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$masterPath = Join-Path $projectRoot 'assets/images/branding/halabessa-lantern-icon-v1.png'
$master = [System.Drawing.Image]::FromFile($masterPath)
$exports = [System.Collections.Generic.List[object]]::new()

function Add-Export([string]$Path, [int]$Size, [double]$Scale = 1.0) {
    $exports.Add(@{ Path = $Path; Size = $Size; Scale = $Scale })
}

try {
    if ($master.Width -ne $master.Height) { throw 'Logo master must be square.' }

    Add-Export 'web/icons/halabessa-lantern-192-v1.png' 192
    Add-Export 'web/icons/halabessa-lantern-512-v1.png' 512
    Add-Export 'web/icons/halabessa-lantern-maskable-192-v1.png' 192 0.72
    Add-Export 'web/icons/halabessa-lantern-maskable-512-v1.png' 512 0.72
    Add-Export 'web/icons/halabessa-lantern-apple-touch-v1.png' 180
    Add-Export 'web/icons/halabessa-lantern-favicon-16-v1.png' 16
    Add-Export 'web/icons/halabessa-lantern-favicon-32-v1.png' 32
    # Keep the conventional fallback for clients requesting /favicon.png.
    Add-Export 'web/favicon.png' 32

    $densities = @{ mdpi = 1; hdpi = 1.5; xhdpi = 2; xxhdpi = 3; xxxhdpi = 4 }
    foreach ($density in $densities.Keys) {
        Add-Export "android/app/src/main/res/mipmap-$density/ic_launcher.png" ([int](48 * $densities[$density]))
        # Adaptive foreground is 108dp. Padding keeps the emblem inside the
        # central safe zone under circular, squircle and OEM launcher masks.
        Add-Export "android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png" ([int](108 * $densities[$density])) 0.64
    }

    $catalogPath = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $catalog = Get-Content -LiteralPath (Join-Path $projectRoot "$catalogPath/Contents.json") -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        if (!$entry.filename) { continue }
        $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x'))
        Add-Export "$catalogPath/$($entry.filename)" ([int]$size)
    }

    foreach ($export in ($exports | Sort-Object { $_.Path } -Unique)) {
        $path = Join-Path $projectRoot $export.Path
        if (!$Check) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            # RGB PNGs, no alpha: required for the iOS marketing/app icon.
            $bitmap = [System.Drawing.Bitmap]::new($export.Size, $export.Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#3B274C'))
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $edge = [int][Math]::Round($export.Size * $export.Scale)
                $inset = [int][Math]::Floor(($export.Size - $edge) / 2)
                $destination = [System.Drawing.Rectangle]::new($inset, $inset, $edge, $edge)
                $graphics.DrawImage($master, $destination, 0, 0, $master.Width, $master.Height, [System.Drawing.GraphicsUnit]::Pixel)
                $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $graphics.Dispose()
                $bitmap.Dispose()
            }
        }
        $image = [System.Drawing.Image]::FromFile($path)
        try {
            if ($image.Width -ne $export.Size -or $image.Height -ne $export.Size) {
                throw "Incorrect icon dimensions: $($export.Path)"
            }
            if ([System.Drawing.Image]::IsAlphaPixelFormat($image.PixelFormat)) {
                throw "Unexpected alpha channel: $($export.Path)"
            }
        } finally { $image.Dispose() }
    }
    Write-Output "Verified $((@($exports | Sort-Object { $_.Path } -Unique)).Count) correctly sized, opaque PNG icons."
} finally { $master.Dispose() }
