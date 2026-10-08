# Bonsai 2 27B - One-Click Windows Package

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue)](https://github.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)
[![Model](https://img.shields.io/badge/Model-Ternary%20Bonsai%202%2027B-orange)](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf)

A local, private, ChatGPT-style AI chat assistant running 100% on your own PC. Nothing is sent to the cloud.

Equipped with multimodal vision capabilities (drag-and-drop images) and an OpenAI-compatible API endpoint.

---

## Support the Project

<div align="center">

<a href="https://cpubyte-donate.blogspot.com/">
  <img src="https://img.shields.io/badge/Support%20the%20Project-%E2%9C%A8%20Donate-00C853?style=for-the-badge&logo=heart&logoColor=white" alt="Donate">
</a>

<p>
If this one-click package saved you time or helped you run local AI hassle-free,
please consider supporting the maintenance of this project.
</p>

</div>

Your support helps keep open-source tools updated and accessible.

---

## Features

* **True One-Click Launcher:** No Python, Conda, or complex CLI tools required. Simply run `START_BONSAI.bat`.
* **Fully Private / Local:** Binds to `127.0.0.1` locally. Prompts, files, and outputs never leave your machine.
* **Multimodal Vision:** Drag and drop images directly into the chat interface using the included mmproj vision tower.
* **Smart Hardware Detection:**

  * Automatically identifies NVIDIA (CUDA), AMD (ROCm/HIP), Vulkan, or CPU.
  * Automatically sizes model layer offloading to fit your free VRAM.
  * Automatically falls back to CPU if your GPU memory is insufficient.
* **Download Resumption:** Interrupted downloads resume automatically without restarting from the beginning.
* **Integrated Web Interface and API:**

  * Built-in web UI at `http://127.0.0.1:8080`
  * OpenAI-compatible API endpoint at `http://127.0.0.1:8080/v1`

---

## System Requirements

| Component           | Minimum                                  | Recommended                             |
| ------------------- | ---------------------------------------- | --------------------------------------- |
| Operating System    | Windows 10 (64-bit) / Windows 11         | Windows 11 (64-bit)                     |
| System RAM          | 8 GB                                     | 16 GB or more                           |
| Free Storage        | ~10 GB                                   | 15 GB or more (SSD recommended)         |
| GPU                 | Optional (runs on CPU)                   | NVIDIA RTX / AMD Radeon with 8 GB+ VRAM |
| Internet Connection | Required for first-time download (~8 GB) | Offline after initial setup             |

---

## Quick Start Guide

### 1. Download and Extract

1. Download this repository as a ZIP archive (or clone it using Git).
2. Right-click the ZIP archive → **Properties** → check **"Unblock"** (if visible) → click **OK**.
3. Extract the entire folder to any location on your drive, for example:

   * `C:\Bonsai2-27B`
   * `D:\Bonsai`

> **Note:** Do not run files directly from inside the ZIP preview window.

### 2. Run the Launcher

Open the extracted folder and double-click:

```cmd
START_BONSAI.bat
```

### 3. First Run Setup

* The script detects your system hardware automatically.
* It downloads the matching llama.cpp runtime and model weights (~7.9 GB total).
* Once loading completes, your default browser opens automatically to:

```text
http://127.0.0.1:8080
```

> **Note:** Keep the terminal window open while chatting. Closing the window shuts down the local server.

---

## Configuration and Tuning (`config.ps1`)

You can open `config.ps1` in Notepad to adjust default behaviors:

| Parameter            |   Default | Description                                                                                           |
| -------------------- | --------: | ----------------------------------------------------------------------------------------------------- |
| `$Port`              |    `8080` | Port for the web chat and API. Change if port 8080 is in use.                                         |
| `$Quant`             | `"PQ2_0"` | `"PQ2_0"` (7.21 GB, faster prompt processing) or `"PTQ1_0"` (5.95 GB, smaller footprint).             |
| `$ContextOverride`   |       `0` | `0` dynamically sizes context based on RAM (8K to 131K). Set manually (e.g. `4096`) if low on memory. |
| `$GpuOverride`       |  `"auto"` | Force a backend: `"auto"`, `"cuda"`, `"vulkan"`, `"hip"`, or `"cpu"`.                                 |
| `$GpuLayersOverride` |       `0` | `0` auto-fits layers to your free VRAM. Set to `99` to force all layers onto the GPU.                 |
| `$Threads`           |       `0` | CPU execution threads (`0` uses all available logical cores).                                         |

---

## Troubleshooting

### Windows SmartScreen Warning

If Windows displays:

> Windows protected your PC

Click **More info** and select **Run anyway**.

The script is an open-source PowerShell script that does not require administrative privileges or make system-wide changes.

### Download Fails or Stalls

Double-click:

```text
START_BONSAI.bat
```

again.

The built-in downloader will resume where it left off instead of restarting the download from the beginning.

### GPU Out of Memory / Startup Crash

Integrated GPUs or graphics cards with low VRAM cannot store a 27B model completely.

The launcher automatically detects the failure and configures CPU fallback mode:

```text
bin\.backend_choice
```

Alternatively, open `config.ps1` and set:

```powershell
$GpuOverride = "cpu"
```

### Port 8080 Is Already in Use

Open `config.ps1` and change:

```powershell
$Port = 8080
```

to another available port, such as:

```powershell
$Port = 8085
```

The web interface will then be available at:

```text
http://127.0.0.1:8085
```

---

## Directory Structure

```text
└── Bonsai2-27B-OneClick/
    ├── START_BONSAI.bat     # Main execution script
    ├── installer.ps1        # Hardware detector, installer, and server runner
    ├── config.ps1           # User settings file
    ├── README.md            # Documentation
    ├── .gitignore           # Ignores downloaded models and binaries
    ├── bin/                 # Generated: contains the llama runtime executables
    └── models/              # Generated: contains the downloaded GGUF files
```

---

## Credits and Licenses

* **Model:** Ternary Bonsai 2 27B by PrismML (Apache 2.0 license).
* **Runtime:** llama.cpp (PrismML fork).
* **Architecture:** Based on the official PrismML Bonsai-demo architecture.

---

## Support

If you find this project useful, consider supporting its continued development:

<div align="center">

<a href="https://cpubyte-donate.blogspot.com/">
  <img src="https://img.shields.io/badge/%E2%9C%A8%20DONATE%20%2F%20SUPPORT-00C853?style=for-the-badge&logo=heart&logoColor=white" alt="Donate / Support">
</a>

</div>

Thank you for supporting open-source local AI.
