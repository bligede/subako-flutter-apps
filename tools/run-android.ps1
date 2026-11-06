param(
    [ValidateSet('demo','development','emulator')][string]$Environment = 'demo',
    [switch]$Build,
    [string]$FlutterSdk
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = if ($FlutterSdk) { Join-Path $FlutterSdk 'bin\flutter.bat' } else { (Get-Command flutter).Source }
$flavor = if ($Environment -eq 'demo') { 'demo' } else { 'development' }
$defineArgs = if ($Environment -eq 'demo') { @('--dart-define=SUBAKO_FIREBASE_ENABLED=false') }
    elseif ($Environment -eq 'emulator') { @('--dart-define-from-file=config/emulator.example.json') }
    else {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.local\firebase-development.json'))) {
            throw 'Konfigurasi lokal belum tersedia. Baca docs/DEVELOPMENT-SETUP.md.'
        }
        @('--dart-define-from-file=.local/firebase-development.json')
    }
Push-Location -LiteralPath $projectRoot
try {
    & $flutterCommand pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency Flutter gagal dipulihkan.' }
    if ($Build) { & $flutterCommand build apk --debug --flavor $flavor @defineArgs }
    else { & $flutterCommand run --flavor $flavor @defineArgs }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter gagal. Periksa output di atas.' }
} finally { Pop-Location }
