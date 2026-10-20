$ErrorActionPreference = 'SilentlyContinue'
$ROOT = "D:\CPT_Analysis_Studio_PORTABLE"
$LLAMA = "C:\Users\BELIKANON\AppData\Local\Microsoft\WinGet\Packages\ggml.llamacpp_Microsoft.Winget.Source_8wekyb3d8bbwe\llama-server.exe"

Write-Host "🧹 [1/3] Nettoyage des anciens processus..." -ForegroundColor Red
Stop-Process -Name "llama-server" -Force
Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object { $_.CommandLine -match "rag_server_fast|KIBALI_MOTEUR|terminal_server" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Seconds 2

Write-Host "🚀 [2/3] Lancement de Qwen3-8B (GPU 16K)..." -ForegroundColor Cyan
$modelPath = Join-Path $ROOT "models\Qwen3-8B-Q4_K_M.gguf"
Start-Process -FilePath $LLAMA -ArgumentList @("-m", $modelPath, "--jinja", "--port", "8080", "-ngl", "999", "-c", "16384", "-fa", "on") -WindowStyle Minimized
Write-Host "     [..] Chargement en VRAM (20s)..." -ForegroundColor Gray
Start-Sleep -Seconds 20

Write-Host "🔍 [3/3] Lancement du serveur RAG et de Flutter..." -ForegroundColor Cyan
Start-Process -FilePath "$ROOT\environment\python.exe" -ArgumentList @("$ROOT\rag_server_fast.py") -WorkingDirectory $ROOT -WindowStyle Minimized
Start-Sleep -Seconds 5
Set-Location "$ROOT\KibaliFlutter"
flutter run -d windows