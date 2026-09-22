$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install the Flutter SDK, run `flutter doctor`, then retry.'
}

Push-Location $projectRoot
try {
    flutter pub get
    flutter build web --release --base-href /

    # Deliberately deploy Hosting only. Firebase Functions requires the Blaze
    # plan, while the project's server work lives in Supabase Edge Functions.
    npx --yes firebase-tools@latest deploy --only hosting --project halabessa-card-game1 --non-interactive
}
finally {
    Pop-Location
}
