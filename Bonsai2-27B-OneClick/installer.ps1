# ============================================================================
#  Bonsai 2 27B - One-Click Windows Installer + Launcher
#  Based on PrismML's official Bonsai-demo (https://github.com/PrismML-Eng/Bonsai-demo)
#  Model: prism-ml/Ternary-Bonsai-2-27B-gguf (Apache 2.0)
#  Runtime: PrismML llama.cpp fork prebuilt binaries (required - stock
#           llama.cpp / Ollama cannot load Bonsai 2 files).
#
#  What this script does (all automatic, no admin rights, nothing installed
#  system-wide, everything stays inside this folder):
#    1. Detects your hardware (NVIDIA / AMD / Vulkan / CPU)
#    2. Downloads the matching llama.cpp runtime (~20-600 MB, once)
#    3. Downloads the Bonsai 2 27B model + vision tower (~7.9 GB, once)
#    4. Starts a local chat server and opens http://127.0.0.1:8080
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
} catch { }
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

$Root = $PSScriptRoot
Set-Location $Root

# ---------------------------------------------------------------------------
# Load user settings
# ---------------------------------------------------------------------------
. (Join-Path $Root "config.ps1")

function Show-Banner {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host "    BONSAI 2 27B  -  local AI chat, one click" -ForegroundColor Cyan
    Write-Host "    27B multimodal model in a ~7.9 GB package (Apache 2.0)" -ForegroundColor DarkCyan
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Step($msg)   { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)     { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)   { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Exit-WithWait($msg) {
    Write-Fail $msg
    Write-Host ""
    Read-Host "Press ENTER to close this window"
    exit 1
}

Show-Banner

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
Write-Step "Checking your system ..."

if ($env:OS -ne "Windows_NT") {
    Exit-WithWait "This package is for Windows only."
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Exit-WithWait "Windows PowerShell 5.0 or newer is required (Windows 10/11 have it built in)."
}

$Arch = $env:PROCESSOR_ARCHITECTURE
if ($Arch -eq "ARM64") {
    $WinArch = "arm64"
    Write-Warn2 "Windows ARM64 detected: CPU build will be used (no GPU builds available for ARM64)."
} else {
    $WinArch = "x64"
    Write-Ok "Windows x64 detected."
}

# Free disk space on the drive this folder lives on
$FreeGB = 999
try {
    if ($Root -like "\\\\*") {
        Write-Warn2 "Folder is on a network share - skipping disk space check."
    } else {
        $Drive = Get-PSDrive -Name ($Root.Substring(0,1)) -ErrorAction Stop
        $FreeGB = [Math]::Floor($Drive.Free / 1GB)
    }
} catch { }
if ($FreeGB -lt 9) {
    Exit-WithWait ("Not enough disk space: {0} GB free on {1}: - about 9 GB is needed for the model + runtime." -f $FreeGB, $Root.Substring(0,1))
}
if ($FreeGB -ne 999) { Write-Ok ("Disk space: {0} GB free (need ~9 GB)." -f $FreeGB) }

# System RAM
try {
    $RamGB = [Math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
} catch {
    $RamGB = 16
}
Write-Ok ("System RAM: {0} GB." -f $RamGB)
if ($RamGB -lt 8) {
    Write-Warn2 "Less than 8 GB RAM: the 27B model will struggle. Consider closing other apps."
}

# Download tool: curl.exe ships with Windows 10 (1803+) and Windows 11
$Curl = $null
foreach ($c in @("$env:SystemRoot\System32\curl.exe", (Get-Command curl.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue))) {
    if ($c -and (Test-Path $c)) { $Curl = $c; break }
}
if (-not $Curl) {
    Write-Warn2 "curl.exe not found - downloads will use PowerShell fallback (slower, no resume)."
}

# Remembers a GPU->CPU fallback across runs (written automatically when the
# GPU cannot fit the model). Delete this file to let the GPU try again.
$MarkerFile = Join-Path $Root "bin\.backend_choice"

# ---------------------------------------------------------------------------
# 1. GPU auto-detection
# ---------------------------------------------------------------------------
Write-Step "Detecting GPU (auto) ..."

$GpuType = $null
$CudaTag = "12.4"

if ($GpuOverride -ne "auto") {
    $GpuType = $GpuOverride.ToLowerInvariant()
    if ($GpuType -notin @("cuda", "vulkan", "hip", "cpu")) {
        Exit-WithWait "config.ps1: `$GpuOverride must be auto / cuda / vulkan / hip / cpu."
    }
    Write-Ok "GPU backend forced by config: $GpuType"
} elseif ($WinArch -eq "arm64") {
    $GpuType = "cpu"
} else {
    # NVIDIA: detect through nvidia-smi (driver reports its CUDA capability)
    $Smi = $null
    foreach ($p in @(
        (Get-Command nvidia-smi -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        "$env:SystemRoot\System32\nvidia-smi.exe"
    )) {
        if ($p -and (Test-Path $p)) { $Smi = $p; break }
    }
    if ($Smi) {
        # nvidia-smi may print driver warnings on stderr; PS 5.1 + EAP=Stop
        # would turn that into a fatal NativeCommandError and misdetect CPU.
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $out = & $Smi 2>&1 | Out-String
            if ($out -match 'CUDA(?:\s+UMD)?\s+Version:\s+(\d+)\.(\d+)') {
                $major = [int]$Matches[1]; $minor = [int]$Matches[2]
                if (($major -gt 13) -or ($major -eq 13 -and $minor -ge 3)) {
                    $CudaTag = "13.3"; $GpuType = "cuda"
                } elseif (($major -gt 12) -or ($major -eq 12 -and $minor -ge 4)) {
                    $CudaTag = "12.4"; $GpuType = "cuda"
                } else {
                    Write-Warn2 "NVIDIA GPU found but driver CUDA ($major.$minor) is older than 12.4 - falling back to CPU. Update your NVIDIA driver for GPU speed."
                    $GpuType = "cpu"
                }
            } else {
                $GpuType = "cpu"
            }
        } catch { $GpuType = "cpu" }
        $ErrorActionPreference = $prevEap
    }

    if ($GpuType -eq "cuda") {
        Write-Ok "NVIDIA GPU detected -> CUDA $CudaTag build."
    } else {
        # AMD HIP/ROCm SDK
        $HipPath = $null
        if ($env:HIP_PATH -and (Test-Path $env:HIP_PATH)) { $HipPath = $env:HIP_PATH }
        if (-not $HipPath) {
            foreach ($candidate in @("$env:ProgramFiles\AMD\ROCm\*\bin\hipcc.exe", "$env:ProgramFiles\AMD\ROCm\bin\hipcc.exe")) {
                $found = Get-Item $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $HipPath = $found.DirectoryName; break }
            }
        }
        if (-not $HipPath) {
            $hipCmd = Get-Command hipcc -ErrorAction SilentlyContinue
            if ($hipCmd) { $HipPath = Split-Path $hipCmd.Source }
        }
        if ($HipPath) {
            $GpuType = "hip"
            Write-Ok "AMD HIP/ROCm SDK detected -> HIP build."
        } elseif (Get-Command vulkaninfo -ErrorAction SilentlyContinue) {
            $GpuType = "vulkan"
            Write-Ok "Vulkan detected -> Vulkan build (GPU layers auto-fitted to your VRAM)."
        } else {
            $GpuType = "cpu"
            Write-Ok "No GPU stack detected -> CPU build (works everywhere, just slower)."
        }
    }
}

# A previous run already proved the GPU cannot fit the model? Then skip the
# failed GPU attempt entirely and go straight to the saved (CPU) backend.
if ($GpuOverride -eq "auto" -and (Test-Path $MarkerFile)) {
    try {
        $saved = (Get-Content $MarkerFile -First 1 -ErrorAction Stop).Trim()
        $parts = $saved -split '\|', 2
        $savedBackend = $parts[0]
        $savedReason  = if ($parts.Count -gt 1) { $parts[1] } else { "GPU could not fit the model" }
        if ($savedBackend -eq "cpu" -and $GpuType -ne "cpu") {
            Write-Warn2 "Switching to CPU mode remembered from a previous run: $savedReason"
            Write-Host "  (delete bin\.backend_choice to let the GPU try again)" -ForegroundColor DarkGray
            $GpuType = "cpu"
        }
    } catch { }
}

# ---------------------------------------------------------------------------
# 2. Runtime binaries (small download, once)
# ---------------------------------------------------------------------------
function Expand-ZipSafe($ZipPath, $DestDir) {
    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zipObj = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $hasTopDir = $false
        foreach ($e in $zipObj.Entries) { if ($e.FullName -match '^[^/]+/') { $hasTopDir = $true; break } }
        $zipObj.Dispose()
        if ($hasTopDir) {
            $tmpEx = Join-Path $env:TEMP ("bonsai_ex_" + [System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $tmpEx -Force | Out-Null
            Expand-Archive -Path $ZipPath -DestinationPath $tmpEx -Force
            Get-ChildItem -Path $tmpEx | Move-Item -Destination $DestDir -Force
            Remove-Item -Path $tmpEx -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
        }
    } catch {
        Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
    }
}

# Run curl without letting its stderr output kill the script.
# curl writes its progress meter to stderr (that is normal, not an error),
# but Windows PowerShell 5.1 wraps redirected/captured native stderr lines
# into NativeCommandError records, and under $ErrorActionPreference = "Stop"
# the very first progress line would terminate the whole script. Temporarily
# relaxing the preference makes stderr harmless; success/failure is judged
# by the curl exit code, which is reliable.
function Invoke-CurlSafe([string[]]$CurlArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Curl @CurlArgs
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Download-File($Url, $Dest, $Description) {
    Write-Host "    Downloading $Description ..." -ForegroundColor Gray
    Write-Host "      from: $Url" -ForegroundColor DarkGray
    $ok = $false
    if ($Curl) {
        for ($i = 1; $i -le 3; $i++) {
            # -# = compact progress bar; stderr stays uncaptured and harmless
            $code = Invoke-CurlSafe @("-L","-#","--fail","--connect-timeout","30","--retry","2","-C","-","-o",$Dest,$Url)
            if ($code -eq 0) { $ok = $true; break }
            if ($code -eq 33 -or $code -eq 416) {
                # range not supported / already complete: try one fresh download
                Remove-Item -Path $Dest -Force -ErrorAction SilentlyContinue
                $code2 = Invoke-CurlSafe @("-L","-#","--fail","--connect-timeout","30","-o",$Dest,$Url)
                if ($code2 -eq 0) { $ok = $true }
                break
            }
            Write-Warn2 "Download attempt $i failed (curl exit $code), retrying ..."
            Start-Sleep -Seconds 3
        }
    } else {
        for ($i = 1; $i -le 3; $i++) {
            try {
                Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
                $ok = $true; break
            } catch {
                Write-Warn2 "Download attempt $i failed: $($_.Exception.Message)"
                Start-Sleep -Seconds 3
            }
        }
    }
    if (-not $ok) { Exit-WithFailLocal $Description }
}

function Exit-WithFailLocal($what) {
    Write-Fail "Download failed: $what"
    Write-Host "  - Check your internet connection" -ForegroundColor Yellow
    Write-Host "  - Corporate networks / antivirus may block github.com or huggingface.co" -ForegroundColor Yellow
    Write-Host "  - Simply run START_BONSAI.bat again to resume" -ForegroundColor Yellow
    Read-Host "Press ENTER to close this window"
    exit 1
}

# Make sure the runtime for a given backend is present; returns its bin dir.
# (The Vulkan package contains the acceleration layer; the small CPU base
# package provides the shared executables it is installed on top of.)
function Ensure-Runtime([string]$Backend) {
    $bin = Join-Path $Root "bin\$Backend"
    if (Test-Path (Join-Path $bin "llama-server.exe")) {
        Write-Ok "Runtime already installed (bin\$Backend)."
        return $bin
    }
    if (Test-Path $bin) { Remove-Item -Path $bin -Recurse -Force }
    New-Item -ItemType Directory -Path $bin -Force | Out-Null

    $Assets = @()
    if ($Backend -eq "cuda") {
        $Assets += @(
            @{ n = "llama-$ReleaseTag-bin-win-cuda-$CudaTag-x64.zip"; d = "CUDA runtime package" },
            @{ n = "cudart-llama-bin-win-cuda-$CudaTag-x64.zip";      d = "NVIDIA CUDA libraries" }
        )
    } elseif ($Backend -eq "hip") {
        $Assets += @{ n = "llama-$ReleaseTag-bin-win-hip-radeon-x64.zip"; d = "AMD HIP runtime package" }
    } elseif ($Backend -eq "vulkan") {
        Write-Host "    (Vulkan mode = CPU base package + Vulkan acceleration layer)" -ForegroundColor DarkGray
        $Assets += @(
            @{ n = "llama-$ReleaseTag-bin-win-cpu-x64.zip";    d = "base runtime package (shared executables)" },
            @{ n = "llama-$ReleaseTag-bin-win-vulkan-x64.zip"; d = "Vulkan acceleration package" }
        )
    } else {
        $Assets += @{ n = "llama-$ReleaseTag-bin-win-cpu-$WinArch.zip"; d = "CPU runtime package" }
    }

    foreach ($asset in $Assets) {
        $zipPath = Join-Path $env:TEMP $asset.n
        Download-File "$ReleaseBase/$($asset.n)" $zipPath $asset.d
        Write-Host "    Extracting $($asset.n) ..." -ForegroundColor Gray
        Expand-ZipSafe $zipPath $bin
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path (Join-Path $bin "llama-server.exe"))) {
        Exit-WithWait "Runtime download failed - llama-server.exe missing. Run START_BONSAI.bat again."
    }
    Set-Content -Path (Join-Path $bin ".llama_release") -Value $ReleaseTag
    Write-Ok "Runtime ready in bin\$Backend\"
    return $bin
}

Write-Step "Preparing the AI runtime (backend: $GpuType) ..."
$BinDir = Ensure-Runtime $GpuType
$env:Path = "$BinDir;$env:Path"

# ---------------------------------------------------------------------------
# 3. Model download (once, ~7.9 GB, supports resume if interrupted)
# ---------------------------------------------------------------------------
Write-Step "Preparing Bonsai 2 27B model (quant: $Quant) ..."

if ($Quant -eq "PTQ1_0") {
    $ModelFile  = "Ternary-Bonsai-2-27B-PTQ1_0.gguf"
    $ModelBytes = 5946648928
} else {
    $Quant = "PQ2_0"
    $ModelFile  = "Ternary-Bonsai-2-27B-PQ2_0.gguf"
    $ModelBytes = 7206168928
}
$MmprojFile  = "Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf"
$MmprojBytes = 629246976

$ModelsDir = Join-Path $Root "models"
if (-not (Test-Path $ModelsDir)) { New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null }

$ModelPath  = Join-Path $ModelsDir $ModelFile
$MmprojPath = Join-Path $ModelsDir $MmprojFile

function Test-FileComplete($Path, $ExpectedBytes) {
    if (-not (Test-Path $Path)) { return $false }
    $len = (Get-Item $Path).Length
    # full size, or within 0.1% (safe against metadata rounding)
    return ($len -ge [int64]($ExpectedBytes * 0.999))
}

if (Test-FileComplete $ModelPath $ModelBytes) {
    Write-Ok "Model already downloaded: $ModelFile"
} else {
    Write-Host "    The model is a one-time ~7 GB download. If it is interrupted," -ForegroundColor Yellow
    Write-Host "    just double-click START_BONSAI.bat again - it resumes where it stopped." -ForegroundColor Yellow
    Download-File "$ModelBase/$ModelFile" $ModelPath "$ModelFile (~7 GB)"
    if (-not (Test-FileComplete $ModelPath $ModelBytes)) {
        Write-Warn2 "Model file size looks incomplete, resuming download once more ..."
        Download-File "$ModelBase/$ModelFile" $ModelPath "$ModelFile (~7 GB, resume)"
        if (-not (Test-FileComplete $ModelPath $ModelBytes)) {
            Exit-WithWait "Model download did not complete. Run START_BONSAI.bat again to resume."
        }
    }
    Write-Ok "Model downloaded: $ModelFile"
}

if (Test-FileComplete $MmprojPath $MmprojBytes) {
    Write-Ok "Vision tower already downloaded: $MmprojFile"
} else {
    Download-File "$ModelBase/$MmprojFile" $MmprojPath "$MmprojFile (0.6 GB, enables image input)"
    if (-not (Test-FileComplete $MmprojPath $MmprojBytes)) {
        Write-Warn2 "Vision tower incomplete - continuing with text-only chat. Re-run START_BONSAI.bat later to fix."
    } else {
        Write-Ok "Vision tower downloaded (image input enabled)."
    }
}

# ---------------------------------------------------------------------------
# 4. Launch local server + open web chat
# ---------------------------------------------------------------------------
# Port already in use?
try {
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -UseBasicParsing
    Write-Warn2 "Something already answers on port $Port - is Bonsai already running?"
    Write-Host "  Open http://127.0.0.1:$Port in your browser, or change `$Port in config.ps1." -ForegroundColor Yellow
    Read-Host "Press ENTER to close this window"
    exit 0
} catch { }

# Context size: RAM-tiered default (same tiers as the official demo)
if ($ContextOverride -and $ContextOverride -ne 0) {
    $Ctx = "$ContextOverride"
} else {
    if ($RamGB -le 11)      { $Ctx = "8192" }
    elseif ($RamGB -le 23)  { $Ctx = "16384" }
    elseif ($RamGB -le 35)  { $Ctx = "32768" }
    elseif ($RamGB -le 71)  { $Ctx = "65536" }
    else                    { $Ctx = "131072" }
    # CPU mode keeps the KV cache in system RAM: keep it modest below 16 GB
    if ($GpuType -eq "cpu" -and $RamGB -lt 16 -and [int]$Ctx -gt 8192) { $Ctx = "8192" }
}

# GPU offload policy:
#   - CPU backend  -> -ngl 0 (explicit)
#   - GPU backends -> omit -ngl entirely: the runtime then auto-fits the
#     number of GPU layers to the FREE VRAM it actually has.
#     (Forcing "-ngl 99" would disable that auto-fit and crash with
#     ErrorOutOfDeviceMemory on integrated graphics / small-VRAM GPUs.)
#   - $GpuLayersOverride > 0 -> force that many layers (power users only)
$Ngl = $null
if ($GpuType -eq "cpu") { $Ngl = "0" }

$NglText = "auto (fitted to your GPU memory)"
if ($GpuType -eq "cpu") { $NglText = "0 (CPU only)" }
if ($GpuLayersOverride -gt 0) { $NglText = "$GpuLayersOverride (forced by config)" }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor DarkCyan
Write-Host "   Model file : $ModelFile"
Write-Host "   Backend    : $GpuType"
Write-Host "   GPU offload: $NglText"
Write-Host "   Context    : $Ctx tokens"
Write-Host "   Web chat   : http://127.0.0.1:$Port"
Write-Host "   API        : http://127.0.0.1:$Port/v1 (OpenAI-compatible)"
Write-Host ""
if ($GpuType -eq "cpu") {
    Write-Host "   CPU mode: first answer can take a while (prompt reading" -ForegroundColor Yellow
    Write-Host "   is the slow part). Short questions work best. Expect a" -ForegroundColor Yellow
    Write-Host "   few tokens per second on a typical PC." -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
}
Write-Host "   Keep this window OPEN while chatting." -ForegroundColor Cyan
Write-Host "   To stop: close this window or press Ctrl+C." -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor DarkCyan
Write-Host ""

Write-Step "Starting server (loading the model can take 1-3 minutes) ..."

# Build a properly quoted command line (paths may contain spaces)
function Quote-Arg($a) {
    $s = "$a"
    if ($s -match '[\s"]') { return '"' + ($s -replace '(\\*)"', '$1$1\"') + '"' }
    return $s
}

function New-BonsaiArgs([string]$Mode, [string]$CtxSize) {
    # $Mode: "gpu" = use the detected backend, "cpu" = force CPU-only offload
    $a = @(
        "-m", $ModelPath,
        "--host", $HostAddress,
        "--port", "$Port",
        "-fa", "on",
        "-c", $CtxSize,
        "--temp", "1.0",
        "--top-p", "0.95",
        "--top-k", "20",
        "--min-p", "0.05",
        "--jinja"
    )
    if ($Mode -eq "cpu") {
        $a += @("-ngl", "0")
    } elseif ($GpuLayersOverride -gt 0) {
        $a += @("-ngl", "$GpuLayersOverride")
    } elseif ($Ngl) {
        $a += @("-ngl", $Ngl)
    }
    # else: omit -ngl -> the runtime auto-fits GPU layers to free VRAM
    if ($Threads -and $Threads -ne 0) { $a += @("--threads", "$Threads") }
    if (Test-Path $MmprojPath) { $a += @("--mmproj", $MmprojPath) }
    if ($ExtraArgs) { $a += $ExtraArgs }
    return $a
}

function Start-BonsaiServer([string[]]$ArgsArray) {
    $ServerExe = Join-Path $BinDir "llama-server.exe"
    $ArgLine = ($ArgsArray | ForEach-Object { Quote-Arg $_ }) -join " "
    return (Start-Process -FilePath $ServerExe -ArgumentList $ArgLine -NoNewWindow -PassThru)
}

function Wait-BonsaiReady($Proc, [int]$SecondsMax) {
    # Poll every second so a crashed server is noticed almost immediately
    $deadline = (Get-Date).AddSeconds($SecondsMax)
    $slept = 0
    while ((Get-Date) -lt $deadline) {
        if ($Proc.HasExited) { return $false }
        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -UseBasicParsing
            return $true
        } catch { }
        Start-Sleep -Seconds 1
        $slept++
        if (($slept % 30) -eq 0) { Write-Host "    ... still loading ($slept s)" -ForegroundColor DarkGray }
    }
    return $false
}

# --- Attempt 1: detected backend (GPU layers auto-fitted to VRAM) ---
$ServerArgs = New-BonsaiArgs "gpu" $Ctx
$proc = Start-BonsaiServer $ServerArgs
$Ready = Wait-BonsaiReady $proc 600

# --- Attempt 2: automatic CPU fallback ---
# If the GPU backend dies during startup it is almost always a VRAM
# problem (typical on integrated graphics). Switch to the pure CPU
# runtime (no GPU code in play at all) and remember the choice, so the
# next launches do not repeat the failed GPU attempt.
if (-not $Ready -and $proc.HasExited -and $GpuType -ne "cpu") {
    Write-Host ""
    Write-Warn2 "The $GpuType backend could not load the 27B model - your GPU does not have enough memory for it."
    Write-Host "  This is common with integrated graphics. Switching to the CPU runtime" -ForegroundColor Yellow
    Write-Host "  (works everywhere, a bit slower). This choice will be remembered." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path (Join-Path $Root "bin") -Force | Out-Null
        Set-Content -Path $MarkerFile -Value "cpu|the GPU ($GpuType) could not fit the 27B model"
    } catch { }
    Start-Sleep -Seconds 1

    $BinDir = Ensure-Runtime "cpu"        # downloads the ~18 MB CPU package only if needed
    $env:Path = "$BinDir;$env:Path"

    $CtxRetry = $Ctx
    if ($RamGB -lt 16 -and [int]$Ctx -gt 8192) { $CtxRetry = "8192" }   # KV cache must fit in RAM too
    $ServerArgs = New-BonsaiArgs "cpu" $CtxRetry
    $proc = Start-BonsaiServer $ServerArgs
    $Ready = Wait-BonsaiReady $proc 600
    if ($Ready) {
        $Ctx = $CtxRetry
        $NglText = "0 (CPU mode - the GPU did not have enough memory)"
    }
}

if ($Ready) {
    Write-Ok "Server is ready!"
    if ($AutoOpenBrowser) {
        try { Start-Process "http://127.0.0.1:$Port" } catch { }
        Write-Ok "Web chat opened in your browser: http://127.0.0.1:$Port"
    } else {
        Write-Ok "Open http://127.0.0.1:$Port in your browser to chat."
    }
    Write-Host ""
    Write-Host "  TIP: in the chat box, click the lightbulb to pick a Reasoning" -ForegroundColor DarkCyan
    Write-Host "  effort (Off/Low/Medium/High). Lower = faster answers." -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  This window must stay open while you chat." -ForegroundColor Cyan
    Write-Host ""
} else {
    if ($proc.HasExited) {
        $ec = ""
        try { if ($proc.WaitForExit(1000)) { $ec = "$($proc.ExitCode)" } } catch { }
        $ecText = ""
        if ($ec -ne "") { $ecText = " (exit code $ec)" }
        Exit-WithWait "The server exited during startup$ecText. Usually a memory problem - close other apps, or set `$ContextOverride = 4096 in config.ps1 and try again."
    }
    Write-Warn2 "Server did not answer within 10 minutes - it may still be loading."
    Write-Host "  You can also open http://127.0.0.1:$Port manually in a minute." -ForegroundColor Yellow
}

# Stay in foreground while the server runs; window close / Ctrl+C stops it.
try { Wait-Process -Id $proc.Id -ErrorAction SilentlyContinue } catch { }
Write-Host ""
Write-Host "  Server stopped. Bye!" -ForegroundColor DarkCyan
