# Script de automatización para que el agente de IA instale Ghidra en Windows

$ErrorActionPreference = 'Stop'

# 1. Configuración de Rutas y Versiones
$installDir = "C:\Ghidra"
$jdkDownloadUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.12_7.msi"
$ghidraDownloadUrl = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.1.2_build/ghidra_11.1.2_PUBLIC_20240709.zip"

Write-Output "=== Iniciando instalación automatizada de Ghidra ==="

# Crear directorio de instalación si no existe
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force
}

# 2. Descargar e Instalar JDK 17
Write-Output "Descargando JDK 17..."
$jdkMsi = "$env:TEMP\OpenJDK17.msi"
Invoke-WebRequest -Uri $jdkDownloadUrl -OutFile $jdkMsi

Write-Output "Instalando JDK 17 de forma silenciosa..."
Start-Process msiexec.exe -ArgumentList "/i `"$jdkMsi`" /qn /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFile" -Wait

# Intentar detectar la ruta de instalación por defecto de Temurin
$jdkFolder = Get-ChildItem -Path "C:\Program Files\Eclipse Adoptium" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($jdkFolder) {
    $javaHomePath = $jdkFolder.FullName
    Write-Output "JDK detectado en: $javaHomePath"
    
    # Configurar Variables de Entorno del Sistema
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHomePath, "Machine")
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$javaHomePath\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$javaHomePath\bin", "Machine")
    }
}

# 3. Descargar y Extraer Ghidra
Write-Output "Descargando archivo ZIP de Ghidra..."
$ghidraZip = "$env:TEMP\ghidra.zip"
Invoke-WebRequest -Uri $ghidraDownloadUrl -OutFile $ghidraZip

Write-Output "Extrayendo Ghidra en $installDir..."
Expand-Archive -Path $ghidraZip -DestinationPath $installDir -Force

Write-Output "=== Instalación completada con éxito ==="
Write-Output "Para ejecutar Ghidra en modo Headless, el agente puede llamar a:"
Write-Output "$installDir\ghidra_*_PUBLIC\support\analyzeHeadless.bat"
