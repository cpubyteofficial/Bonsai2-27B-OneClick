============================================================================
 BONSAI 2 27B  -  ONE-CLICK WINDOWS PACKAGE
 Local ChatGPT-style AI chat that runs 100% on YOUR PC. Nothing is sent
 to the cloud. Model by PrismML (Apache 2.0), based on Qwen3.8 27B.
============================================================================

HOW TO RUN (ONE CLICK)
----------------------
1. Right-click the downloaded ZIP -> Properties -> check "Unblock" -> OK
   (if you see this option; this avoids the Windows security warning)
2. Extract the WHOLE folder anywhere (e.g. Desktop or D:\)
   Do NOT run anything from inside the ZIP preview window.
3. Open the extracted folder and DOUBLE-CLICK:

        START_BONSAI.bat

4. First run only:
   - Detects your hardware automatically (GPU or CPU - both fine)
   - Downloads the AI runtime (~20-600 MB) and the model (~7.9 GB)
     from GitHub + HuggingFace. On a normal connection this is
     10-40 minutes. Interrupted? Just double-click again - it RESUMES.
5. When "Server is ready!" appears, your browser opens the chat at

        http://127.0.0.1:8080

6. Chat! You can also drag & drop images into the chat (vision).
7. Next runs: just double-click START_BONSAI.bat again - no downloads,
   the chat opens in seconds after the model loads (1-3 min).

REQUIREMENTS
------------
- Windows 10 (64-bit) or Windows 11
- ~10 GB free disk space
- 8 GB RAM minimum, 16 GB+ recommended (context size adapts to your RAM)
- GPU is OPTIONAL. No GPU or a small GPU (e.g. integrated graphics)?
  It uses your CPU: works everywhere, but expect a few tokens per
  second. Have a big NVIDIA/AMD card? It is detected and used
  automatically for much higher speed.
- Internet connection for the first download only. Chat is offline.

IF WINDOWS SHOWS A SECURITY WARNING
-----------------------------------
"Windows protected your PC" -> click "More info" -> "Run anyway".
This appears because the script is unsigned, not because it is unsafe.
Everything it does is visible in installer.ps1 (plain text, no installers,
no admin rights, nothing installed outside its own folder).
To fully uninstall: delete the folder. Done.

TIPS FOR THE WEB CHAT
---------------------
- Click the LIGHTBULB in the message box to pick a Reasoning effort
  (Off / Low / Medium / High). Lower = much faster answers on CPU.
- Answers stream token by token; the first token takes longest.
- The console window must STAY OPEN while you chat. Closing it stops
  the AI (nothing breaks - start it again anytime).
- Free OpenAI-compatible API for your own apps: http://127.0.0.1:8080/v1

TUNING (optional - open config.ps1 in Notepad)
----------------------------------------------
- $Port              change 8080 if something else uses it
- $Quant             "PTQ1_0" = 2 GB smaller model file (5.95 GB), same
                     quality family; PQ2_0 (default) reads prompts faster
- $ContextOverride   force a context size, e.g. 4096 if you are low on RAM
- $Threads           limit CPU threads (0 = use all cores)
- $GpuOverride       force "cuda" / "vulkan" / "hip" / "cpu"
- $GpuLayersOverride leave 0 = auto (recommended): the runtime fits model
                     layers to your GPU's free memory; only set 99 if your
                     GPU has ~10 GB+ VRAM

TROUBLESHOOTING
---------------
- Download failed / stalls -> run START_BONSAI.bat again (resume),
  check antivirus or corporate firewall for github.com / huggingface.co
- "Port 8080 already in use" -> change $Port in config.ps1
- "GPU out of memory" / ErrorOutOfDeviceMemory at startup -> integrated
  graphics and small-VRAM GPUs cannot hold a 27B model. The launcher
  auto-fits GPU layers to your VRAM and, if the GPU still cannot help,
  switches to the pure CPU runtime BY ITSELF and remembers that choice
  (stored in bin\.backend_choice). Next launches go straight to CPU.
  Delete that file to let the GPU try again, or set $GpuOverride = "cpu"
  in config.ps1 to decide yourself. CPU mode is just slower (a few
  tokens per second).
- PC runs out of memory -> close other apps; set $ContextOverride = 4096
- Very slow answers on CPU -> that is normal for a 27B on CPU; try
  Reasoning effort "Off", shorter questions, or the PTQ1_0 quant
- Crashed on load -> update Windows; make sure you have 8+ GB RAM free

WHAT IS INSIDE THIS FOLDER
--------------------------
START_BONSAI.bat    <- double-click this (the only file you ever need)
installer.ps1       <- the automatic installer/launcher (PowerShell)
config.ps1          <- optional settings
README.txt          <- this file
bin\                <- created at first run: the AI runtime
models\             <- created at first run: the 7.9 GB model files

CREDITS / LICENSES
------------------
Model  : Ternary Bonsai 2 27B by PrismML - https://prismml.com
         https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf (Apache 2.0)
Runtime: llama.cpp (PrismML fork) - https://github.com/PrismML-Eng/llama.cpp
Based on: the official PrismML Bonsai-demo setup flow
This package only downloads and launches the above; all rights belong
to their respective authors. Runs locally, binds to 127.0.0.1 only.
