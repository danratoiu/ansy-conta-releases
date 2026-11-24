param([switch] $VerificaCatalog)
$ErrorActionPreference = 'Stop'
$catalogPath = Join-Path $PSScriptRoot 'latest.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$address = [uri]$catalog.url
if (!$address.IsAbsoluteUri -or $address.Scheme -ne 'https' -or $address.UserInfo) { throw 'Catalogul cere o adresă HTTPS fără date de autentificare.' }
if ($catalog.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Amprenta SHA-256 lipsește sau este invalidă.' }
$temporary = [IO.Path]::GetTempFileName()
try {
    Write-Host "Verific instalatorul $($catalog.version). Așteaptă descărcarea pentru controlul SHA-256..."
    try { Invoke-WebRequest -UseBasicParsing -Uri $address -OutFile $temporary -TimeoutSec 180 -Headers @{'Cache-Control'='no-cache'} }
    catch { throw "Instalatorul nu poate fi descărcat de la $address. Încarcă fișierul la adresa exactă înainte de publicarea latest.json. Detalii: $($_.Exception.Message)" }
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    if ($actual -ne $catalog.sha256) { throw 'SHA-256 diferă: fișierul de pe GitHub nu este instalatorul din acest pachet. Nu publica latest.json.' }
    if ($VerificaCatalog) {
        $published = Invoke-RestMethod -Uri ('https://raw.githubusercontent.com/danratoiu/ansy-conta-releases/main/latest.json?verify=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Headers @{'Cache-Control'='no-cache'} -TimeoutSec 30
        if ($published.version -ne $catalog.version -or $published.url -ne $catalog.url -or $published.sha256 -ne $catalog.sha256) { throw 'Catalogul public nu corespunde pachetului local. Verifică publicarea latest.json și repetă după expirarea cache-ului GitHub.' }
        Write-Host 'OK: catalog public și instalator verificate. Actualizarea este disponibilă.'
    } else { Write-Host 'OK: instalator public verificat. Poți încărca acum latest.json în rădăcina depozitului, ramura main.' }
} finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
