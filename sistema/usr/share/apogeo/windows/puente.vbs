' Apogeo · Windows escondido: el «escritorio» de tu cuenta. Abre el puente (puente.ps1) sin que salga ninguna ventana
' de consola y se queda mientras dura.
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Apogeo\puente.ps1""", 0, True
