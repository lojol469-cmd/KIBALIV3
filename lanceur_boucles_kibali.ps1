# ============================================================
#  LANCEUR BOUCLES KIBALI - SAFE MODE
#  Ne tue QUE les processus llama-server et rag_server_fast
#  Ne touche JAMAIS a VSCode, python general, ou autres
# ============================================================
$LLAMA = "C:\Users\BELIKANON\AppData\Local\Microsoft\WinGet\Packages\ggml.llamacpp_Microsoft.Winget.Source_8wekyb3d8bbwe\llama-server.exe"
$ROOT  = "D:\CPT_Analysis_Studio_PORTABLE"
$PY    = "$ROOT\environment\python.exe"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  KIBALI - LANCEUR SAFE MODE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# FONCTION : Tuer uniquement les processus KIBALI connus
# ------------------------------------------------------------
function Kill-KibaliProcess($port, $serviceName, $expectedProcessPattern) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if (-not $conn) { return }
        
        foreach ($c in $conn) {
            $pid = $c.OwningProcess
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if (-not $proc) { continue }
            
            # SECURITE : Ne tuer QUE si le processus correspond au pattern attendu
            $isSafeToKill = $false
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $pid" -ErrorAction Stop).CommandLine
                if ($cmdLine -and $cmdLine -match $expectedProcessPattern) {
                    $isSafeToKill = $true
                }
            } catch {}
            
            if ($isSafeToKill) {
                Write-Host "  [KILL] $serviceName : $($proc.ProcessName) (PID $pid) sur port $port" -ForegroundColor Yellow
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            } else {
                Write-Host "  [SKIP] Port $port occupe par $($proc.ProcessName) (PID $pid) - NON KIBALI, ignore" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  [WARN] Impossible de liberer port $port : $_" -ForegroundColor Yellow
    }
}

function Test-Port($port) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        return ($conn -ne $null)
    } catch { return $false }
}

function Wait-LLMReady($port, $maxSeconds = 90) {
    $elapsed = 0
    while ($elapsed -lt $maxSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/v1/models" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    return $false
}

function Wait-HttpReady($port, $path, $maxSeconds = 90) {
    $elapsed = 0
    while ($elapsed -lt $maxSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port$path" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    return $false
}

# ------------------------------------------------------------
# 0. NETTOYAGE CIBLE (safe)
# ------------------------------------------------------------
Write-Host "[0/5] Nettoyage des ports (safe)" -ForegroundColor Yellow
Kill-KibaliProcess 8080 "Qwen3-8B"   "Qwen3-8B"
Kill-KibaliProcess 8081 "Qwen3-0.6B" "Qwen3-0.6B"
Kill-KibaliProcess 8082 "BGE-M3"     "bge-m3"
Kill-KibaliProcess 8765 "RAG Server" "rag_server_fast"
Write-Host "  [OK] Nettoyage termine" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# 1. QWEN3-8B
# ------------------------------------------------------------
Write-Host "[1/4] Qwen3-8B (LLM) port 8080..." -ForegroundColor Yellow
$modelPath = Join-Path $ROOT "models\Qwen3-8B-Q4_K_M.gguf"
if (Test-Path $modelPath) {
    Start-Process -FilePath $LLAMA -ArgumentList @("-m", $modelPath, "--jinja", "--port", "8080", "-ngl", "999", "-c", "8192", "-fa", "on", "-b", "512", "-ub", "512") -WindowStyle Minimized -ErrorAction SilentlyContinue
    Write-Host "  [..] Chargement (peut prendre 60s)..." -ForegroundColor Yellow
    if (Wait-LLMReady 8080 90) {
        Write-Host "  [OK] Qwen3-8B pret" -ForegroundColor Green
    } else {
        Write-Host "  [KO] Timeout apres 90s" -ForegroundColor Red
    }
} else {
    Write-Host "  [KO] Modele introuvable : $modelPath" -ForegroundColor Red
}

# ------------------------------------------------------------
# 2. QWEN3-0.6B
# ------------------------------------------------------------
Write-Host ""
Write-Host "[2/4] Qwen3-0.6B (Routeur) port 8081..." -ForegroundColor Yellow
$modelPath = Join-Path $ROOT "models\Qwen3-0.6B-Q4_K_M.gguf"
if (Test-Path $modelPath) {
    Start-Process -FilePath $LLAMA -ArgumentList @("-m", $modelPath, "--jinja", "--port", "8081", "-ngl", "999", "-c", "2048") -WindowStyle Minimized -ErrorAction SilentlyContinue
    Write-Host "  [..] Chargement..." -ForegroundColor Yellow
    if (Wait-LLMReady 8081 60) {
        Write-Host "  [OK] Qwen3-0.6B pret" -ForegroundColor Green
    } else {
        Write-Host "  [KO] Timeout" -ForegroundColor Red
    }
} else {
    Write-Host "  [KO] Modele introuvable : $modelPath" -ForegroundColor Red
}

# ------------------------------------------------------------
# 3. BGE-M3
# ------------------------------------------------------------
Write-Host ""
Write-Host "[3/4] BGE-M3 (Embeddings) port 8082..." -ForegroundColor Yellow
$modelPath = Join-Path $ROOT "models\bge-m3-Q4_K_M.gguf"
if (Test-Path $modelPath) {
    Start-Process -FilePath $LLAMA -ArgumentList @("-m", $modelPath, "--embeddings", "--port", "8082", "-ngl", "999", "-c", "512") -WindowStyle Minimized -ErrorAction SilentlyContinue
    Write-Host "  [..] Chargement..." -ForegroundColor Yellow
    if (Wait-LLMReady 8082 60) {
        Write-Host "  [OK] BGE-M3 pret" -ForegroundColor Green
    } else {
        Write-Host "  [KO] Timeout" -ForegroundColor Red
    }
} else {
    Write-Host "  [KO] Modele introuvable : $modelPath" -ForegroundColor Red
}

# ------------------------------------------------------------
# 4. RAG SERVER
# ------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] RAG Server port 8765..." -ForegroundColor Yellow
$ragScript = Join-Path $ROOT "rag_server_fast.py"
if (Test-Path $ragScript) {
    Start-Process -FilePath $PY -ArgumentList @($ragScript) -WorkingDirectory $ROOT -WindowStyle Minimized -ErrorAction SilentlyContinue
    Write-Host "  [..] Chargement FAISS (peut prendre 60s)..." -ForegroundColor Yellow
    if (Wait-HttpReady 8765 "/docs_status" 90) {
        Write-Host "  [OK] RAG Server pret" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] RAG Server timeout (peut etre encore en chargement)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [KO] rag_server_fast.py introuvable" -ForegroundColor Red
}

# ------------------------------------------------------------
# 5. ETAT FINAL
# ------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ETAT FINAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$checks = @(
    @{Name="Qwen3-8B";   Port=8080; Path="/v1/models"},
    @{Name="Qwen3-0.6B"; Port=8081; Path="/v1/models"},
    @{Name="BGE-M3";     Port=8082; Path="/v1/models"},
    @{Name="RAG Server"; Port=8765; Path="/docs_status"}
)

$allOK = $true
foreach ($c in $checks) {
    if (Test-Port $c.Port) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$($c.Port)$($c.Path)" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            $namePad = $c.Name.PadRight(15)
            Write-Host "  [OK] $namePad Port $($c.Port) - HTTP $($r.StatusCode)" -ForegroundColor Green
        } catch {
            $namePad = $c.Name.PadRight(15)
            Write-Host "  [..] $namePad Port $($c.Port) - Port ouvert, HTTP pas pret" -ForegroundColor Yellow
        }
    } else {
        $namePad = $c.Name.PadRight(15)
        Write-Host "  [KO] $namePad Port $($c.Port) - NON DEMARRE" -ForegroundColor Red
        $allOK = $false
    }
}

# VRAM
Write-Host ""
Write-Host "--- VRAM GPU ---" -ForegroundColor Yellow
try {
    $vram = & nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null
    if ($vram) {
        $parts = ($vram -split ",") | ForEach-Object { $_.Trim() }
        Write-Host "  VRAM : $($parts[0]) / $($parts[1]) MB" -ForegroundColor Cyan
        Write-Host "  Temperature : $($parts[2]) C" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  nvidia-smi non disponible" -ForegroundColor Gray
}

Write-Host ""
if ($allOK) {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  TOUS LES MOTEURS PRETS" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Lance : .\environment\python.exe KIBALI_MOTEUR_V3_FAST.py" -ForegroundColor Cyan
} else {
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  CERTAINS MOTEURS NE SONT PAS DEMARRES" -ForegroundColor Yellow
    Write-Host "  Verifie les logs ci-dessus" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
}
Write-Host ""