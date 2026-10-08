# ============================================================================
#  Bonsai 2 27B - One-Click Windows Package :: USER SETTINGS
#  You normally do NOT need to touch anything here.
#  Just double-click START_BONSAI.bat and wait for your browser to open.
# ============================================================================

# ---- Server ----
$Port            = 8080          # Web chat will be at http://127.0.0.1:8080
$HostAddress     = "127.0.0.1"   # Keep 127.0.0.1 = only this PC can connect (private!)
$AutoOpenBrowser = $True         # Open the web chat automatically when ready

# ---- Model ----
# $Quant: "PQ2_0" (7.21 GB, default - faster prompt processing, recommended)
#         "PTQ1_0" (5.95 GB - smaller footprint, slightly slower prompt processing)
$Quant = "PQ2_0"

# ---- Performance ----
# $ContextOverride: 0 = auto (sized from your RAM: 8K..131K tokens)
#                   or set an explicit number, e.g. 8192
$ContextOverride = 0

# $Threads: 0 = auto (use all CPU cores), or set e.g. 8
$Threads = 0

# $GpuOverride: "auto" = detect automatically (NVIDIA CUDA / AMD / Vulkan / CPU)
#               or force one of: "cuda", "vulkan", "hip", "cpu"
#               Tip: if your GPU cannot fit the 27B model, set "cpu".
#               The launcher also remembers CPU mode by itself after a
#               failed GPU start (stored in bin\.backend_choice).
$GpuOverride = "auto"

# $GpuLayersOverride: 0 = auto (RECOMMENDED - the runtime fits model layers
#                          to the memory your GPU actually has; if the GPU is
#                          too small the launcher switches to CPU by itself)
#                     e.g. 99 = force ALL layers on GPU (only sensible for
#                     GPUs with ~10 GB+ VRAM; forces ignore of auto-fit)
$GpuLayersOverride = 0

# ---- Advanced ----
# Extra arguments passed to llama-server, e.g. @("--no-webui")
$ExtraArgs = @()

# ---- Downloads (do not change unless you know why) ----
$ModelRepo   = "prism-ml/Ternary-Bonsai-2-27B-gguf"
$ReleaseTag  = "prism-b10743-adfffbe"
$ReleaseBase = "https://github.com/PrismML-Eng/llama.cpp/releases/download/$ReleaseTag"
$ModelBase   = "https://huggingface.co/$ModelRepo/resolve/main"
