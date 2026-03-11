@echo off
"C:\\Program Files\\Java\\jdk-21\\bin\\java" ^
  --class-path ^
  "C:\\Users\\ahmed\\.gradle\\caches\\modules-2\\files-2.1\\com.google.prefab\\cli\\2.1.0\\aa32fec809c44fa531f01dcfb739b5b3304d3050\\cli-2.1.0-all.jar" ^
  com.google.prefab.cli.AppKt ^
  --build-system ^
  cmake ^
  --platform ^
  android ^
  --abi ^
  arm64-v8a ^
  --os-version ^
  23 ^
  --stl ^
  c++_shared ^
  --ndk-version ^
  27 ^
  --output ^
  "C:\\Users\\ahmed\\AppData\\Local\\Temp\\agp-prefab-staging4496024651440447990\\staged-cli-output" ^
  "C:\\Users\\ahmed\\.gradle\\caches\\8.13\\transforms\\d4e58177c062d995cfa6ba745aa5a2fc\\transformed\\jetified-games-frame-pacing-2.1.3\\prefab"
