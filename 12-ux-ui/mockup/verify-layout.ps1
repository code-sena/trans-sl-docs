# Comprueba los mockups de layout/ sin abrir el navegador.
# Uso:  powershell -ExecutionPolicy Bypass -File verify-layout.ps1
# Sale con codigo 1 si encuentra algun problema, para poder usarlo en CI.
# ASCII solamente: Windows PowerShell 5.1 lee los archivos sin BOM como ANSI.
param([string]$Layout = (Join-Path $PSScriptRoot 'layout'))

$ErrorActionPreference = 'Stop'
$problemas = New-Object System.Collections.Generic.List[string]
function Fallo([string]$m) { $script:problemas.Add($m) }

if (-not (Test-Path -LiteralPath $Layout)) { Write-Error "No existe $Layout"; exit 1 }
$shared = Join-Path $Layout '_shared'
$paginas = Get-ChildItem -LiteralPath $Layout -Directory | Where-Object { $_.Name -ne '_shared' }

# 1. Archivos compartidos que toda pagina necesita
$obligatorios = @(
  'support.js', 'theme.css', 'theme-boot.js', 'image-slot.js', 'session.js',
  'a11y.css', 'a11y.js', 'responsive.css', 'boot-check.js',
  'SiteHeader.dc.html', 'SiteFooter.dc.html',
  'vendor\react.production.min.js', 'vendor\react-dom.production.min.js',
  'vendor\babel.min.js', 'vendor\lucide.min.js',
  'fonts\nunito-sans.css'
)
foreach ($f in $obligatorios) {
  if (-not (Test-Path -LiteralPath (Join-Path $shared $f))) { Fallo "falta _shared\$f" }
}

# 2. Rol de cada pantalla (ERF6.1): el administrador solo ve estas tres
$admin = @('view-usage-statistics', 'view-admin-dashboard', 'train-recognition-model')
$usuario = @('translate-signs', 'view-alphabet', 'view-translation-history', 'view-achievements')

foreach ($p in $paginas) {
  $ruta = Join-Path $p.FullName 'index.html'
  if (-not (Test-Path -LiteralPath $ruta)) { Fallo "$($p.Name): no tiene index.html"; continue }
  $html = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)

  # 2.1 Cabecera de la pagina
  if ($html -notmatch '<title>[^<]+</title>') { Fallo "$($p.Name): sin <title>" }
  if ($html -notmatch '<html lang="es">') { Fallo "$($p.Name): sin lang=es" }
  if ($html -notmatch '<noscript>') { Fallo "$($p.Name): sin aviso <noscript>" }
  foreach ($dep in 'session.js', 'support.js', 'a11y.css', 'a11y.js', 'responsive.css', 'boot-check.js') {
    if ($html -notmatch [regex]::Escape($dep)) { Fallo "$($p.Name): no carga $dep" }
  }

  # 2.2 Nada se pide a la red: ni runtime, ni iconos, ni fuentes
  foreach ($m in [regex]::Matches($html, '(src|href)="(https?:)?//[^"]+"')) {
    Fallo "$($p.Name): recurso externo $($m.Value)"
  }

  # 2.3 Guardia de rol
  if ($admin -contains $p.Name -and $html -notmatch '__tsGuardRole\("admin"\)') { Fallo "$($p.Name): falta la guardia de administrador" }
  if ($usuario -contains $p.Name -and $html -notmatch '__tsGuardRole\("user"\)') { Fallo "$($p.Name): falta la guardia de usuario" }

  # 2.4 Enlaces internos y archivos compartidos que cita
  foreach ($m in [regex]::Matches($html, '\.\./([a-z0-9-]+)/index\.html')) {
    $destino = Join-Path $Layout ($m.Groups[1].Value + '\index.html')
    if (-not (Test-Path -LiteralPath $destino)) { Fallo "$($p.Name): enlace roto a $($m.Groups[1].Value)" }
  }
  foreach ($m in [regex]::Matches($html, '\.\./_shared/([^"''\)\s]+)')) {
    $destino = Join-Path $shared ($m.Groups[1].Value -replace '/', '\')
    if (-not (Test-Path -LiteralPath $destino)) { Fallo "$($p.Name): cita _shared/$($m.Groups[1].Value), que no existe" }
  }

  # 2.5 Decision del equipo: alfabeto de 26 letras, A-Z
  $alfabetoConEnye = 'ABCDEFGHIJKLMN' + [string][char]0x00D1
  if ($html.Contains('27 letras') -or $html.Contains($alfabetoConEnye)) { Fallo "$($p.Name): quedo la enye o las 27 letras" }

  # 2.6 Toda imagen necesita texto alternativo
  $sinAlt = [regex]::Matches($html, '[<]img(?![^>]*\balt=)[^>]*[>]')
  if ($sinAlt.Count -gt 0) { Fallo "$($p.Name): $($sinAlt.Count) imagen(es) sin alt" }
}

# 3. Las imagenes que citan las paginas y los componentes existen
$fuentes = @($paginas | ForEach-Object { Join-Path $_.FullName 'index.html' }) +
           @(Get-ChildItem -LiteralPath $shared -Filter '*.dc.html' | ForEach-Object { $_.FullName })
foreach ($f in $fuentes) {
  $t = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($t, 'assets/([^"''\)\s]+)')) {
    $img = Join-Path $shared ('assets\' + $m.Groups[1].Value)
    if (-not (Test-Path -LiteralPath $img)) { Fallo "$(Split-Path $f -Leaf): falta la imagen $($m.Groups[1].Value)" }
  }
}

Write-Output ('paginas: {0}   problemas: {1}' -f $paginas.Count, $problemas.Count)
foreach ($p in $problemas) { Write-Output ("  - " + $p) }
if ($problemas.Count -gt 0) { exit 1 }
