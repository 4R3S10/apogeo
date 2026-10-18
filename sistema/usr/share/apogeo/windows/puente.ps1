# Apogeo · Windows escondido · lo que ves al entrar en Windows (es el «escritorio» de tu cuenta: lo pone instalar.ps1).
#  - Con un juego en la nota de Apogeo: la pantalla de carga de Apogeo, se abre el juego y, cuando lo cierras, «Volviendo
#    a Apogeo» y de vuelta (lo hace la tarea Apogeo-Arranque).
#  - Para instalar juegos (o si enciendes Windows a mano): el escritorio de Windows de siempre con una pastilla «Volver a
#    Apogeo» abajo.
# Si el juego no aparece en 15 minutos (o algo falla), en vez de quedarse en negro deja elegir: escritorio o volver.
$ErrorActionPreference = 'Continue'
$Base = 'C:\Apogeo'
$Estado = Join-Path $Base 'estado'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing
Start-Transcript -Path (Join-Path $env:LOCALAPPDATA 'apogeo-puente.log') -Force | Out-Null

# La letra de Apogeo si está instalada (la pone instalar.ps1); si no, la de Windows
$Fuente = 'Segoe UI'
if ((New-Object System.Drawing.Text.InstalledFontCollection).Families | Where-Object { $_.Name -eq 'Bricolage Grotesque' }) {
    $Fuente = 'Bricolage Grotesque'
}

function Volver {
    New-Item -ItemType File -Force -Path (Join-Path $Estado 'volver') | Out-Null
}

function Ventana([string]$titulo, [string]$detalle) {
    # La pantalla de carga de Apogeo: a pantalla completa, encima de todo
    [xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStyle="None" ResizeMode="NoResize"
        WindowState="Maximized" Topmost="True" Background="#0B080D" ShowInTaskbar="False" Cursor="None">
  <Grid>
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
      <Image Source="$Base\logo.png" Width="96" Height="96" Margin="0,0,0,24"/>
      <TextBlock Name="Titulo" Foreground="#F1E6EA" FontFamily="$Fuente" FontSize="34" FontWeight="Bold" HorizontalAlignment="Center"/>
      <TextBlock Name="Detalle" Foreground="#9E9499" FontFamily="$Fuente" FontSize="16" Margin="0,10,0,22" HorizontalAlignment="Center"/>
      <ProgressBar IsIndeterminate="True" Width="260" Height="4" Foreground="#E0A9B4" Background="#1A1A1D" BorderThickness="0"/>
      <StackPanel Name="Botones" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,28,0,0" Visibility="Collapsed">
        <Button Name="Escritorio" Content="  Abrir el escritorio  " Margin="6" Padding="14,8" FontFamily="$Fuente" FontSize="15"/>
        <Button Name="Atras" Content="  Volver a Apogeo  " Margin="6" Padding="14,8" FontFamily="$Fuente" FontSize="15"/>
      </StackPanel>
    </StackPanel>
  </Grid>
</Window>
"@
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.FindName('Titulo').Text = $titulo
    $w.FindName('Detalle').Text = $detalle
    return $w
}

function Esperar([System.Windows.Window]$w, [scriptblock]$hasta, [int]$segundos) {
    # Deja que la ventana se pinte mientras se espera (sin congelarse)
    $fin = (Get-Date).AddSeconds($segundos)
    while ((Get-Date) -lt $fin) {
        if (& $hasta) { return $true }
        $w.Dispatcher.Invoke([action] {}, 'Background')
        Start-Sleep -Milliseconds 300
    }
    return $false
}

function Escritorio {
    # El escritorio de Windows de verdad: el explorador arranca como escritorio solo si es el «Shell» de la cuenta en ese
    # momento; luego se vuelve a dejar el puente para la próxima vez
    $clave = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty $clave -Name Shell -Value 'explorer.exe'
    Start-Process explorer.exe
    Start-Sleep -Seconds 8
    Set-ItemProperty $clave -Name Shell -Value "wscript.exe `"$Base\puente.vbs`""
    # La pastilla «Volver a Apogeo», abajo en el centro
    [xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" SizeToContent="WidthAndHeight">
  <Border Background="#E6211924" CornerRadius="22" Padding="6" BorderBrush="#33F1E6EA" BorderThickness="1">
    <StackPanel Orientation="Horizontal">
      <Image Source="$Base\logo.png" Width="30" Height="30" Margin="6,0,8,0"/>
      <Button Name="Atras" Content="  Volver a Apogeo  " Background="#E0A9B4" Foreground="#2A1C26" BorderThickness="0"
              FontFamily="$Fuente" FontSize="14" FontWeight="Bold" Padding="12,6" Cursor="Hand"/>
    </StackPanel>
  </Border>
</Window>
"@
    $p = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $p.Add_Loaded({
        $a = [System.Windows.SystemParameters]::WorkArea
        $p.Left = $a.Left + ($a.Width - $p.ActualWidth) / 2
        $p.Top = $a.Bottom - $p.ActualHeight - 16
    })
    $p.FindName('Atras').Add_Click({
        $p.FindName('Atras').IsEnabled = $false
        $p.FindName('Atras').Content = '  Volviendo…  '
        Volver
    })
    $p.ShowDialog() | Out-Null
}

# ---------- La nota de Apogeo (la trae la tarea de arranque) ----------
$nota = $null
$listo = Join-Path $Estado 'listo'
for ($i = 0; $i -lt 40 -and -not (Test-Path $listo); $i++) { Start-Sleep -Milliseconds 500 }
$f = Join-Path $Estado 'puente.json'
if (Test-Path $f) { $nota = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json }

if (-not $nota -or $nota.modo -ne 'juego') {
    Escritorio
    exit
}

# ---------- Un juego ----------
$w = Ventana "Abriendo $($nota.nombre)" 'Windows escondido · al cerrar el juego vuelves a Apogeo solo'
$w.Show()
$nombres = @($nota.proceso -split '\|' | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })
function Corriendo { if (-not $nombres) { return $false } ; return [bool](Get-Process -Name $nombres -ErrorAction SilentlyContinue) }

try {
    if ($nota.lanzar -match '^"([^"]+)"\s*(.*)$') { Start-Process -FilePath $Matches[1] -ArgumentList $Matches[2] }
    elseif ($nota.lanzar -match '^[a-z][a-z0-9+.-]*://') { Start-Process $nota.lanzar }
    else { Start-Process -FilePath $nota.lanzar -WorkingDirectory (Split-Path $nota.lanzar) }
} catch { Write-Output "lanzar: $_" }

# Hasta que el juego aparece (los lanzadores a veces se actualizan antes: hasta 15 minutos)
if (Esperar $w { Corriendo } 900) {
    $w.Hide()
    # Mientras juegas, nada; cuando ya no está (10 s seguidos), de vuelta
    $fuera = 0
    while ($fuera -lt 10) { Start-Sleep -Seconds 1; if (Corriendo) { $fuera = 0 } else { $fuera++ } }
    $w = Ventana 'Volviendo a Apogeo' ''
    $w.Show()
    $w.Dispatcher.Invoke([action] {}, 'Background')
    Volver
    Esperar $w { $false } 120 | Out-Null
} else {
    # No ha aparecido: que elijas
    $w.FindName('Titulo').Text = "$($nota.nombre) no se ha abierto"
    $w.FindName('Detalle').Text = 'Puedes abrir el escritorio para mirarlo o volver a Apogeo.'
    $w.FindName('Botones').Visibility = 'Visible'
    $w.Cursor = 'Arrow'
    $eleccion = $null
    $w.FindName('Escritorio').Add_Click({ $script:eleccion = 'escritorio'; $w.Close() })
    $w.FindName('Atras').Add_Click({ $script:eleccion = 'volver'; $w.Close() })
    $w.Hide(); $w.ShowDialog() | Out-Null
    if ($eleccion -eq 'escritorio') { Escritorio } else { Volver; Start-Sleep -Seconds 120 }
}
