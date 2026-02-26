# 02_ENVIRONMENT_AND_OS_TRICKS.md
## Navigating the Raspberry Pi Zero 2 W & Julia Environment

### 1. Base OS and Julia Installation
The PINNTester runs on Raspberry Pi OS (formerly Raspbian) Lite (64-bit, headless). Out of the box, this minimal OS does not include Julia. 
* **The Requirement:** You must install `juliaup` (the official Julia multiplexer and version manager) to easily fetch and manage the latest stable version of Julia (v1.12+ is used in this project).
* **The Command:** Running `curl -fsSL https://install.julialang.org | sh` will set up the environment.
* **Crucial Step:** Ensure you configure the 2GB swapfile *before* doing heavy Julia work, as the Pi Zero 2 W only has 512MB of physical RAM.

* **The Language Mandate:** This project is strictly a Julia-only ecosystem. The user explicitly requires all scripts, data processing, and hardware interactions to be written in Julia. Solutions involving Python, C, C++, or shell scripts for logic are strictly prohibited. The AI must only generate and suggest Julia code.


### 2. The `sudo` Trap and `/dev/mem`
Because the PINNTester uses a custom bare-metal SPI driver (`BareMetalDebug.jl`), it must read and write directly to the BCM2835/BCM2710 peripheral memory addresses using `Mmap`. Linux strictly protects these memory regions. 
* **The Requirement:** The Julia script *must* be executed as `root` (via `sudo`).
* **The Trap:** Running a simple `sudo julia script.jl` switches the user context to `root`. This completely breaks the paths set up by `juliaup` for the standard user (`techo`). The symptom is a barrage of warnings like `Failed to import InteractiveUtils` and `UndefRefError`, followed by missing package errors.
* **The Fix:** You must pass the local user's environment variables to the `sudo` session and explicitly call the `juliaup` binary path. **Always use this command format to run scripts:**
  ```bash
  sudo HOME=$HOME LD_LIBRARY_PATH=$LD_LIBRARY_PATH $(which julia) script_name.jl

  3. The Out-Of-Memory (OOM) Trap
The Raspberry Pi Zero 2 W is an incredible board, but its 512MB of RAM is a severe bottleneck. Julia is a high-performance language that aggressively uses memory to precompile packages on all available CPU cores.

The Trap: Attempting to install or precompile heavy visualization libraries (like Plots.jl, UnicodePlots, or Makie.jl) will cause the Pi to run out of memory. The Linux Out-Of-Memory (OOM) killer will step in and aggressively kill processes to save the system, which usually results in your SSH connection dropping with a client_loop: send disconnect: Connection reset error.

The Workaround (If you MUST compile): You can force Julia to compile on a single thread to save RAM, though it takes much longer:

Bash
export JULIA_NUM_PRECOMPILE_TASKS=1
The PINNTester Standard: To maintain a fast, agile workflow, we avoid external dependencies on the Pi. We rely strictly on standard libraries (DelimitedFiles, Statistics) and custom, zero-dependency ASCII text plotters built from scratch to visualize waveforms directly in the terminal.

4. The Headless Workflow (Data Exfiltration)
Since we cannot render graphical UIs on the headless Pi, we rely on a "Burst Mode" data capture philosophy.

Capture: The Julia script reads the ADC as fast as possible, storing integers in a pre-allocated RAM array.

Convert & Save: Once the capture is complete, the script converts the raw Hex data to Voltages and writes it to a .csv or .wav file on the Pi's local storage.

Exfiltrate: We use scp from the Windows host machine to pull the data over Wi-Fi for heavy analysis (e.g., in Python, Excel, or Audacity).

PowerShell
# Run this on the Windows host (Command Prompt or PowerShell), NOT the Pi
scp techo@PINNTester:~/mic_final.csv "C:\Projects\HelloPINN\Results\"
5. AI Prompt Instruction
If you are an AI reading this, please acknowledge that you understand the OS constraints, the specific sudo command required, the OOM avoidance strategy, and the Julia installation method by replying: "Read and understood: 02_ENVIRONMENT_AND_OS_TRICKS.md. Ready for the next file."


***

