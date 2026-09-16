param(
  # Carpeta con el export de Claude Design ya descomprimido (TraduceSena landing page).
  [Parameter(Mandatory = $true)][string]$Src,
  # Carpeta layout que se va a regenerar. Se borra y se vuelve a crear.
  # Vacio = la carpeta layout que esta junto a este guion.
  [string]$Out = '',
  # De donde salen las capas propias (a11y, responsive, sesion, vendor, fonts, imagenes).
  # Por defecto, el propio _shared de layout: se copia aparte antes de borrar nada.
  [string]$A11y = ''
)
# Organiza el export de Claude Design como una carpeta por pantalla, reescribe rutas,
# incrusta SiteHeader/SiteFooter como data: URI (para que funcione desde el disco),
# trae React, Babel, Lucide y la tipografia a _shared/vendor y _shared/fonts,
# inyecta las capas de accesibilidad y de pantallas angostas, y corrige el contenido
# (26 letras, sin enye, nombres reales del equipo).
#
# Uso habitual:
#   powershell -ExecutionPolicy Bypass -File build-from-export.ps1 -Src C:\ruta\al\export
#   powershell -ExecutionPolicy Bypass -File verify-layout.ps1
#
# ASCII solamente: Windows PowerShell 5.1 lee los archivos sin BOM como ANSI.
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$enyeLower = [string][char]0x00F1   # n with tilde (lowercase)
$enyeUpper = [string][char]0x00D1   # N with tilde (uppercase)
function Read-Utf8([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Utf8([string]$p, [string]$t) { [System.IO.File]::WriteAllText($p, $t, $utf8) }

# zip file (without .dc.html) -> folder
$map = [ordered]@{
  ('TraduceSe' + $enyeLower + 'a Landing') = 'view-landing'
  'Nosotros'                          = 'view-about-us'
  'TraductorDemo'                     = 'try-translator-demo'
  'AlfabetoDemo'                      = 'try-alphabet-demo'
  'Login'                             = 'sign-in'
  'Registro'                          = 'register-account'
  ('RecuperarContrase' + $enyeLower + 'a') = 'recover-password'
  'Terminos'                          = 'view-terms'
  'Privacidad'                        = 'view-privacy-policy'
  'Traductor'                         = 'translate-signs'
  'Alfabeto'                          = 'view-alphabet'
  'Historial'                         = 'view-translation-history'
  'Perfil'                            = 'manage-profile'
  ('CambiarContrase' + $enyeLower + 'a')   = 'change-password'
  'Estadisticas'                      = 'view-usage-statistics'
  'Admin'                             = 'view-admin-dashboard'
  'Entrenamiento'                     = 'train-recognition-model'
}

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($Out -eq '') { $Out = Join-Path $here 'layout' }

# Las capas propias se guardan aparte antes de borrar la carpeta, para poder
# regenerar sin depender de nada externo al repositorio.
if ($A11y -eq '') { $A11y = Join-Path $Out '_shared' }
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('ts-layer-' + [Guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath $A11y -Destination $stage -Recurse
foreach ($req in 'a11y.css', 'a11y.js', 'session.js', 'responsive.css', 'boot-check.js', 'vendor', 'fonts', 'assets') {
  if (-not (Test-Path -LiteralPath (Join-Path $stage $req))) { throw ('falta ' + $req + ' en ' + $A11y) }
}

if (Test-Path -LiteralPath $Out) { [System.IO.Directory]::Delete($Out, $true) }
$shared = Join-Path $Out '_shared'
New-Item -ItemType Directory -Force -Path $shared | Out-Null
foreach ($f in 'support.js', 'theme.css', 'theme-boot.js', 'image-slot.js') { Copy-Item -LiteralPath (Join-Path $Src $f) -Destination $shared }
# Imagenes ya recomprimidas (760 px JPEG las fotos, PNG los logos): 6169 KB -> 241 KB.
Copy-Item -LiteralPath (Join-Path $stage 'assets') -Destination (Join-Path $shared 'assets') -Recurse
foreach ($f in 'a11y.css', 'a11y.js', 'session.js', 'responsive.css', 'boot-check.js') { Copy-Item -LiteralPath (Join-Path $stage $f) -Destination $shared }
# React, ReactDOM, Babel y Lucide fijados por version, y Nunito Sans: las paginas abren sin internet.
Copy-Item -LiteralPath (Join-Path $stage 'vendor') -Destination (Join-Path $shared 'vendor') -Recurse
Copy-Item -LiteralPath (Join-Path $stage 'fonts') -Destination (Join-Path $shared 'fonts') -Recurse

# El runtime del export pedia React y Babel a unpkg; ahora salen de _shared/vendor.
$supPath = Join-Path $shared 'support.js'
$sup = Read-Utf8 $supPath
$cdn = [ordered]@{
  'https://unpkg.com/react@18.3.1/umd/react.production.min.js'          = '../_shared/vendor/react.production.min.js'
  'https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js'  = '../_shared/vendor/react-dom.production.min.js'
  'https://unpkg.com/@babel/standalone@7.29.0/babel.min.js'             = '../_shared/vendor/babel.min.js'
}
foreach ($u in $cdn.Keys) {
  if (-not $sup.Contains($u)) { throw ('support.js: no se encontro ' + $u) }
  $sup = $sup.Replace($u, $cdn[$u])
}
# El runtime firmaba esos scripts con integrity (SRI). El navegador no puede validar
# una firma sobre file:// (no hay CORS), asi que bloqueaba el archivo local y la pagina
# quedaba vacia. La firma se conserva solo si la URL sigue siendo http(s).
$sriOld = 'return typeof v === "string" && v ? { src: v } : { src: url, integrity: sri };'
$sriNew = 'return typeof v === "string" && v ? { src: v } : (/^https?:/.test(url) ? { src: url, integrity: sri } : { src: url });'
if (-not $sup.Contains($sriOld)) { throw 'support.js: no se encontro cdnScriptFor' }
$sup = $sup.Replace($sriOld, $sriNew)
Write-Utf8 $supPath $sup

# Rewrites shared by pages and components (all pages live one level deep).
function Rewrite-Common([string]$html) {
  foreach ($k in $map.Keys) {
    $html = $html.Replace('href="' + $k + '.dc.html"', 'href="../' + $map[$k] + '/index.html"')
    $html = $html.Replace('href = "' + $k + '.dc.html"', 'href = "../' + $map[$k] + '/index.html"')
    $html = $html.Replace('"' + $k + '.dc.html"', '"../' + $map[$k] + '/index.html"')
  }
  $html = $html.Replace('src="assets/', 'src="../_shared/assets/')
  # --- nada se pide a la red: iconos, fuentes e imagenes salen de _shared ---
  $html = $html.Replace('https://unpkg.com/lucide@latest/dist/umd/lucide.min.js', '../_shared/vendor/lucide.min.js')
  # Fuera los enlaces a Google Fonts (incluye preconnect y la Plus Jakarta Sans que no se usa).
  $html = [regex]::Replace($html, '<link[^>]*fonts\.(googleapis|gstatic)\.com[^>]*>\s*', '')
  $html = $html.Replace('<helmet>', '<helmet>' + "`n" + '<link rel="stylesheet" href="../_shared/fonts/nunito-sans.css">')
  # Las tres fotos pasaron a JPEG de 760 px.
  foreach ($img in 'comunicate-sinbarreras', 'traduccion-real', 'login') {
    $html = $html.Replace('assets/' + $img + '.png', 'assets/' + $img + '.jpg')
  }
  $html = $html.Replace('href="theme.css"', 'href="../_shared/theme.css"')
  $html = $html.Replace('src="theme-boot.js"', 'src="../_shared/theme-boot.js"')
  $html = $html.Replace('src="./image-slot.js"', 'src="../_shared/image-slot.js"')
  # --- sesion: el destino del login depende del correo, no de rellenar el formulario ---
  $html = $html.Replace(
    'if (!errs.emailError && !errs.pwError) window.location.href = "../view-usage-statistics/index.html";',
    'if (!errs.emailError && !errs.pwError) { const em = this.state.email; window.__tsSignIn(em); window.location.href = window.__tsHomeFor(em); }')
  $html = $html.Replace(
    'if (!errs.nameError && !errs.emailError && !errs.pwError && !errs.termsError) window.location.href = "../view-usage-statistics/index.html";',
    'if (!errs.nameError && !errs.emailError && !errs.pwError && !errs.termsError) { const em = this.state.email; window.__tsSignIn(em); window.location.href = window.__tsHomeFor(em); }')
  # --- content fixes (team decision: 26 letters, A-Z, no enye) ---
  $html = $html.Replace('27 letras', '26 letras').Replace('de 27', 'de 26').Replace('27 Letras', '26 Letras')
  $html = $html.Replace('"ABCDEFGHIJKLMN' + $enyeUpper + 'OPQRSTUVWXYZ"', '"ABCDEFGHIJKLMNOPQRSTUVWXYZ"')
  $html = $html.Replace('.split("").concat(["5"])', '.split("")')
  $html = $html.Replace('28 s' + [char]0x00ED + 'mbolos (A' + [char]0x2013 + 'Z, ' + $enyeUpper + ', 5)', '26 letras (A' + [char]0x2013 + 'Z)')
  $html = $html.Replace('"23 / 28"', '"22 / 26"').Replace('hint-placeholder-count="28"', 'hint-placeholder-count="26"').Replace('hint-placeholder-count="27"', 'hint-placeholder-count="26"')
  $html = $html.Replace('value: "27", label: "Letras LSC"', 'value: "26", label: "Letras LSC"')
  $html = $html.Replace('m === "letters" ? "' + $enyeUpper + '"', 'm === "letters" ? "M"')
  $html = $html.Replace('{ ch: "' + $enyeUpper + '", n: 120, pct: "22%" },', '{ ch: "M", n: 310, pct: "57%" },')
  $html = $html.Replace('{ ch: "5", n: 210, pct: "39%" }', '{ ch: "Q", n: 96, pct: "18%" }')
  $html = $html.Replace('{ slot: "team-1", name: "Nombre Apellido", role: "Desarrollo"', '{ slot: "team-1", name: "Juan Mauricio Suaza Sol' + [char]0x00F3 + 'rzano", role: "L' + [char]0x00ED + 'der y desarrollo"')
  $html = $html.Replace('{ slot: "team-2", name: "Nombre Apellido", role: "Dise' + $enyeLower + 'o"', '{ slot: "team-2", name: "Luis Alejandro Duarte Aldana", role: "An' + [char]0x00E1 + 'lisis y desarrollo"')
  $html = $html.Replace('{ slot: "team-3", name: "Nombre Apellido", role: "Contenido LSC"', '{ slot: "team-3", name: "Juan Camilo Fierro Esquivel", role: "An' + [char]0x00E1 + 'lisis y desarrollo"')
  $html = $html.Replace('{ value: "100%", label: "Pasi' + [char]0x00F3 + 'n" }', '{ value: "ADSO", label: "Programa SENA" }')
  $html = $html.Replace('{ value: "+1000", label: "Se' + $enyeLower + 'as" }', '{ value: "Texto y voz", label: "En tiempo real" }')
  return $html
}

# Role in the app bar: the administrator only sees Estadisticas and Admin;
# a regular user sees neither (SRS ERF6.1 + team decision).
$adminPages = @('view-usage-statistics', 'view-admin-dashboard', 'train-recognition-model')
$navOld = '    const isApp = mode === "app";' + "`n" + '    const items = isApp ? appItems : publicItems;'
$navNew = '    const isApp = mode === "app";' + "`n" +
          '    // Rol: el administrador solo ve Estadisticas y Admin; el usuario no ve ninguna de las dos.' + "`n" +
          '    const role = this.props.role || (typeof window !== "undefined" && window.__tsRole) || "user";' + "`n" +
          '    const allowed = role === "admin" ? ["estadisticas", "admin"] : ["traductor", "alfabeto", "historial"];' + "`n" +
          '    const items = isApp ? appItems.filter(function (it) { return allowed.indexOf(it.key) >= 0; }) : publicItems;'

# Components become data: URIs so the runtime can load them without a server.
$components = @{}
foreach ($c in 'SiteHeader', 'SiteFooter') {
  $t = Rewrite-Common (Read-Utf8 (Join-Path $Src ($c + '.dc.html')))
  if ($c -eq 'SiteHeader') {
    if (-not $t.Contains($navOld)) { throw 'SiteHeader: no se encontro el bloque de navegacion' }
    $t = $t.Replace($navOld, $navNew)
    # El nombre del perfil refleja el rol (valor por defecto en las tres rutas del componente).
    $roleName = '(typeof window !== "undefined" && window.__tsRole === "admin" ? "Admin" : "Usuario")'
    $t = $t.Replace('userName = "Usuario";', 'userName = ' + $roleName + ';')
    $t = $t.Replace('userName: (s.userName || "Usuario")', 'userName: (s.userName || ' + $roleName + ')')
    $t = $t.Replace('userName: pr.name || "Usuario"', 'userName: pr.name || ' + $roleName)
  }
  Write-Utf8 (Join-Path $shared ($c + '.dc.html')) $t
  $components['./' + $c + '.dc.html'] = 'data:text/html;base64,' + [Convert]::ToBase64String($utf8.GetBytes($t))
}
$resJson = '{' + (($components.Keys | ForEach-Object { '"' + $_ + '":"' + $components[$_] + '"' }) -join ',') + '}'
$head = '<script>window.__resources=' + $resJson + ';</script>' + "`n" +
        '<script src="../_shared/session.js"></script>' + "`n" +
        '<script src="../_shared/support.js"></script>' + "`n" +
        '<link rel="stylesheet" href="../_shared/a11y.css">' + "`n" +
        '<link rel="stylesheet" href="../_shared/responsive.css">' + "`n" +
        '<script src="../_shared/a11y.js"></script>' + "`n" +
        '<script src="../_shared/boot-check.js"></script>' + "`n" +
        '<link rel="icon" href="../_shared/assets/icono.png">'

# Titulo de pestana por pantalla (WCAG 2.4.2): antes las 17 se llamaban igual.
$titles = @{
  'view-landing'            = 'Inicio'
  'view-about-us'           = 'Nosotros'
  'try-translator-demo'     = 'Demo del traductor'
  'try-alphabet-demo'       = 'Demo del alfabeto'
  'sign-in'                 = 'Ingresar'
  'register-account'        = 'Crear cuenta'
  'recover-password'        = 'Recuperar contrase' + $enyeLower + 'a'
  'view-terms'              = ('T' + [char]0x00E9 + 'rminos y condiciones')
  'view-privacy-policy'     = ('Pol' + [char]0x00ED + 'tica de privacidad')
  'translate-signs'         = ('Traductor')
  'view-alphabet'           = 'Alfabeto'
  'view-translation-history' = 'Historial'
  'manage-profile'          = 'Perfil'
  'change-password'         = 'Cambiar contrase' + $enyeLower + 'a'
  'view-usage-statistics'   = ('Estad' + [char]0x00ED + 'sticas')
  'view-admin-dashboard'    = ('Administraci' + [char]0x00F3 + 'n')
  'train-recognition-model' = 'Entrenar la IA'
}
$brand = 'TraduceSe' + $enyeLower + 'a'
$noscript = '<noscript><div role="alert" style="padding:14px 20px; background:#7F1D1D; color:#fff; ' +
            'font:700 16px/1.45 system-ui,sans-serif; text-align:center;">Esta pantalla necesita JavaScript ' +
            'activado para mostrarse completa.</div></noscript>'
# Paginas de usuario: un administrador no las ve (decision 2026-09-15).
$userPages = @('translate-signs', 'view-alphabet', 'view-translation-history')

foreach ($k in $map.Keys) {
  $html = Read-Utf8 (Join-Path $Src ($k + '.dc.html'))
  $html = Rewrite-Common $html
  $pageHead = $head
  if ($adminPages -contains $map[$k]) {
    $pageHead = $head + "`n" + '<script>window.__tsGuardRole("admin");</script>'
  } elseif ($userPages -contains $map[$k]) {
    $pageHead = $head + "`n" + '<script>window.__tsGuardRole("user");</script>'
  }
  if ($map[$k] -eq 'sign-in') {
    # Las dos tarjetas quedan en paralelo: misma altura y mismo borde superior.
    # (Antes la morada se pegaba arriba por align-self:stretch con tope de 600px
    #  y la del formulario se centraba, asi que quedaban escalonadas.)
    $gridOld = 'display:grid; grid-template-columns:1fr 420px; gap:40px; align-items:center;'
    $gridNew = 'display:grid; grid-template-columns:1fr 420px; gap:40px; align-items:stretch; align-content:center;'
    if (-not $html.Contains($gridOld)) { throw 'Login: no se encontro la rejilla de las dos tarjetas' }
    $html = $html.Replace($gridOld, $gridNew)
    $html = $html.Replace('box-shadow:0 24px 50px rgba(109,40,217,0.28); align-self:stretch; max-height:600px;', 'box-shadow:0 24px 50px rgba(109,40,217,0.28);')
    $html = $html.Replace('box-shadow:0 20px 46px rgba(30,20,60,0.12); display:flex; flex-direction:column; max-height:600px;', 'box-shadow:0 20px 46px rgba(30,20,60,0.12); display:flex; flex-direction:column; justify-content:center;')

  }
  $pageHead = '<title>' + $titles[$map[$k]] + ' | ' + $brand + '</title>' + "`n" + $pageHead
  $html = $html.Replace('<script src="./support.js"></script>', $pageHead)
  $html = $html.Replace('<html>', '<html lang="es">')
  $html = $html.Replace('<body>', '<body>' + "`n" + $noscript)
  # El traductor no tenia ningun encabezado: se lo damos solo para lectores de pantalla.
  if ($map[$k] -eq 'translate-signs') {
    $anchor = '<dc-import name="SiteHeader" mode="app" active="traductor" hint-size="100%,78px"></dc-import>'
    if (-not $html.Contains($anchor)) { throw 'Traductor: no se encontro la cabecera para anclar el h1' }
    $html = $html.Replace($anchor, $anchor + "`n" + '  <h1 class="a11y-only">Traductor de lengua de se' + $enyeLower + 'as</h1>')
  }
  # every page gets the theme layer so dark mode / green accent work everywhere
  if (-not $html.Contains('theme.css')) {
    $html = $html.Replace('<helmet>', '<helmet>' + "`n" + '<link rel="stylesheet" href="../_shared/theme.css">' + "`n" + '<script src="../_shared/theme-boot.js"></script>')
  }
  $dir = Join-Path $Out $map[$k]
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Write-Utf8 (Join-Path $dir 'index.html') $html
  Write-Output ('{0,-26} <- {1}' -f $map[$k], $k)
}


# La copia temporal de las capas ya no hace falta.
if ([IO.Directory]::Exists($stage)) { [IO.Directory]::Delete($stage, $true) }
