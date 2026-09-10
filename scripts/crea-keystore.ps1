<#
    Crea la chiave con cui l'app verra' firmata per Play Store.

    ATTENZIONE, leggere prima di lanciare:
      - Chi possiede questo file puo' firmare aggiornamenti della tua app che i
        telefoni accettano come autentici.
      - Se lo perdi NON puoi piu' aggiornare l'app pubblicata: Google non
        sostituisce le chiavi. Si ricomincia da un'applicazione nuova, con un
        altro identificativo, e gli utenti installati restano fermi.
      => Appena finito: copia di sicurezza del file .jks e della password, in
         due posti diversi.

    Il keystore viene creato FUORI dalla cartella del progetto, cosi' non puo'
    finire su GitHub nemmeno per sbaglio. Il progetto lo raggiunge tramite
    android/key.properties, anch'esso escluso dal controllo di versione.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\scripts\crea-keystore.ps1
#>

$keytool  = "C:\Program Files\Android\Android Studio1\jbr\bin\keytool.exe"
$cartella = Join-Path $env:USERPROFILE "primes-firma"
$jks      = Join-Path $cartella "primes-release.jks"
$alias    = "primes"
$progetto = Split-Path -Parent $PSScriptRoot
$props    = Join-Path $progetto "android\key.properties"

if (-not (Test-Path $keytool)) {
    Write-Host "keytool non trovato in:" -ForegroundColor Red
    Write-Host "  $keytool" -ForegroundColor Red
    Write-Host "Cercalo con: Get-ChildItem 'C:\Program Files\Android' -Recurse -Filter keytool.exe" -ForegroundColor Yellow
    exit 1
}
if (Test-Path $jks) {
    Write-Host "Esiste gia' un keystore in $jks" -ForegroundColor Yellow
    Write-Host "Non lo tocco: se lo sovrascrivessi perderesti la firma dell'app." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Si apre una finestra di Windows: li' l'incolla funziona." -ForegroundColor Cyan
Write-Host "Scegli una password lunga e SALVALA SUBITO nel gestore di password." -ForegroundColor Cyan
Write-Host ""

$pwd = (Get-Credential -UserName primes -Message "Password del keystore (almeno 12 caratteri)").GetNetworkCredential().Password
Write-Host ("caratteri letti: {0}" -f $pwd.Length) -ForegroundColor DarkGray

if ($pwd.Length -lt 12) {
    Write-Host "Troppo corta (minimo 12). Non ho fatto niente." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $cartella | Out-Null

# La password passa a keytool tramite file e non sulla riga di comando: gli
# argomenti di un processo sono leggibili da chiunque sul sistema.
$tmp = Join-Path $env:TEMP ("kt-" + [guid]::NewGuid().ToString("N") + ".txt")
[IO.File]::WriteAllText($tmp, $pwd)

try {
    Write-Host "1/3  Genero la chiave (valida 10000 giorni)..." -ForegroundColor Cyan
    & $keytool -genkeypair -v `
        -keystore $jks `
        -alias $alias `
        -keyalg RSA -keysize 4096 -validity 10000 `
        -storepass:file $tmp -keypass:file $tmp `
        -dname "CN=PRIMES Drought-Alert, OU=Interreg IPA ADRION, O=PMG Tec, L=Ancona, C=IT"

    if (-not (Test-Path $jks)) {
        Write-Host "Generazione fallita." -ForegroundColor Red
        exit 1
    }

    Write-Host "2/3  Scrivo android\key.properties..." -ForegroundColor Cyan
    $contenuto = @(
        "# Generato da scripts\crea-keystore.ps1 - NON versionare questo file.",
        "storePassword=$pwd",
        "keyPassword=$pwd",
        "keyAlias=$alias",
        "storeFile=$($jks -replace '\\','/')"
    ) -join "`r`n"
    [IO.File]::WriteAllText($props, $contenuto)

    Write-Host "3/3  Impronta SHA-1 della chiave:" -ForegroundColor Cyan
    Write-Host ""
    & $keytool -list -v -keystore $jks -alias $alias -storepass:file $tmp |
        Select-String -Pattern "SHA1:|SHA256:"
    Write-Host ""
    Write-Host "OK - keystore creato in:" -ForegroundColor Green
    Write-Host "     $jks" -ForegroundColor Green
    Write-Host ""
    Write-Host "ADESSO: fanne una copia di sicurezza fuori da questo PC," -ForegroundColor Yellow
    Write-Host "        e salva la password nel gestore di password." -ForegroundColor Yellow
    Write-Host "Poi passa la riga SHA1 qui sopra a chi deve limitare la chiave API." -ForegroundColor Yellow
} finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
Write-Host ""
