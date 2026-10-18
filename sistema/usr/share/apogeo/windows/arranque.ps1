# Apogeo · Windows escondido · lo que corre como SISTEMA desde que se enciende (tarea «Apogeo-Arranque»).
#  1. Trae la nota de Apogeo (EFI\apogeo\puente.json, en la partición de arranque) a C:\Apogeo\estado\puente.json y
#     la borra de allí (si luego enciendes Windows a mano, no vuelve a abrir el juego).
#  2. Espera a que el puente (la sesión) pida volver (C:\Apogeo\estado\volver): apunta tus juegos de Windows en
#     EFI\apogeo\juegos.json para que Apogeo los enseñe en su consola y reinicia (el orden de arranque vuelve a Apogeo).
$ErrorActionPreference = 'Continue'
$Base = 'C:\Apogeo'
$Estado = Join-Path $Base 'estado'
New-Item -ItemType Directory -Force -Path $Estado | Out-Null
Start-Transcript -Path (Join-Path $Estado 'arranque.log') -Force | Out-Null

function Con-Arranque([scriptblock]$Hacer) {
    # Monta la partición de arranque en una letra libre, hace lo que toque y la desmonta
    $letra = [char[]]'SRQPONMLKJ' | Where-Object { -not (Test-Path "$($_):\") } | Select-Object -First 1
    if (-not $letra) { return }
    mountvol "$($letra):" /s | Out-Null
    try { & $Hacer "$($letra):\EFI\apogeo" }
    finally { mountvol "$($letra):" /d | Out-Null }
}

# ---------- 1. La nota de Apogeo ----------
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Estado 'puente.json'), (Join-Path $Estado 'volver')
Con-Arranque {
    param($dir)
    $nota = Join-Path $dir 'puente.json'
    if (Test-Path $nota) {
        Copy-Item -Force $nota (Join-Path $Estado 'puente.json')
        Remove-Item -Force $nota
    }
}
# El puente (la sesión) espera a esto para leer la nota
Set-Content -Path (Join-Path $Estado 'listo') -Value (Get-Date -Format o)

# ---------- Tus juegos de Windows ----------
function Exes([string]$dir) {
    # Los .exe del juego (sin instaladores ni herramientas), para saber cuándo se cierra
    if (-not (Test-Path $dir)) { return @() }
    Get-ChildItem -Path $dir -Filter *.exe -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(?i)setup|install|unins|crash|report|redist|vc_|dxsetup|helper|launcher|easyanticheat|be(service|launcher)|cleanup|touchup' } |
        Sort-Object Length -Descending | Select-Object -First 4 | ForEach-Object { $_.Name }
}

function Juegos {
    $lista = @()
    # Riot (Valorant, League of Legends)
    $rc = 'C:\ProgramData\Riot Games\RiotClientInstalls.json'
    if (Test-Path $rc) {
        $cliente = (Get-Content $rc -Raw | ConvertFrom-Json).rc_default
        foreach ($p in @(
            @{ id = 'valorant'; nombre = 'VALORANT'; producto = 'valorant'; proceso = 'VALORANT-Win64-Shipping.exe' },
            @{ id = 'league'; nombre = 'League of Legends'; producto = 'league_of_legends'; proceso = 'League of Legends.exe' })) {
            if (Test-Path "C:\ProgramData\Riot Games\Metadata\$($p.producto).live") {
                $lista += [ordered]@{ id = $p.id; name = $p.nombre; proceso = $p.proceso
                    lanzar = "`"$cliente`" --launch-product=$($p.producto) --launch-patchline=live" }
            }
        }
    }
    # Epic Games Launcher
    $man = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path $man) {
        foreach ($f in Get-ChildItem $man -Filter *.item) {
            $m = Get-Content $f.FullName -Raw | ConvertFrom-Json
            if ($m.bIsApplication -eq $false -or -not $m.AppName) { continue }
            $lista += [ordered]@{ id = "epic-$($m.AppName)"; name = $m.DisplayName
                lanzar = "com.epicgames.launcher://apps/$($m.CatalogNamespace)%3A$($m.CatalogItemId)%3A$($m.AppName)?action=launch&silent=true"
                proceso = (@([IO.Path]::GetFileName($m.LaunchExecutable)) + (Exes $m.InstallLocation) | Select-Object -Unique) -join '|' }
        }
    }
    # EA app y Steam de Windows: por su carpeta de instalación
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\EA Games\*', 'HKLM:\SOFTWARE\EA Sports\*', 'HKLM:\SOFTWARE\WOW6432Node\EA Sports\*')) {
        foreach ($e in Get-ItemProperty $k -ErrorAction SilentlyContinue) {
            $dir = $e.'Install Dir'
            $exe = Exes $dir | Select-Object -First 1
            if ($dir -and $exe) {
                $lista += [ordered]@{ id = 'ea-' + ($e.PSChildName -replace '\W', '-').ToLower(); name = $e.PSChildName
                    lanzar = (Join-Path $dir $exe); proceso = (Exes $dir) -join '|' }
            }
        }
    }
    $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
    if ($steam -and (Test-Path "$steam\steamapps")) {
        foreach ($acf in Get-ChildItem "$steam\steamapps" -Filter appmanifest_*.acf) {
            $t = Get-Content $acf.FullName -Raw
            $id = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
            $nom = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value
            $dir = [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value
            if (-not $id -or $nom -match 'Redistributable|Steamworks|Proton') { continue }
            $lista += [ordered]@{ id = "steam-$id"; name = $nom; lanzar = "steam://rungameid/$id"
                proceso = (Exes "$steam\steamapps\common\$dir") -join '|'
                cover = "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$id/library_600x900.jpg" }
        }
    }
    return $lista
}

# ---------- 2. Volver a Apogeo cuando la sesión lo pida ----------
while (-not (Test-Path (Join-Path $Estado 'volver'))) { Start-Sleep -Seconds 1 }
try {
    $json = ConvertTo-Json -InputObject @(Juegos) -Depth 4
    Con-Arranque {
        param($dir)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir 'juegos.json'), $json, (New-Object Text.UTF8Encoding $false))
    }
} catch { Write-Output "juegos: $_" }
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Estado 'volver')
Stop-Transcript | Out-Null
Restart-Computer -Force
