# 06_PROJECT_SCRIPTS_LIBRARY.md
## The PINNTester Codebase Index

This file documents the stable, proven Julia scripts that make up the PINNTester's current capabilities. The AI should reference these as the "Gold Standard" templates for future development.

### 1. Core Driver Library (`src/`)
* **`BareMetalDebug.jl`:** The foundational SPI driver. Uses `Mmap` on `/dev/mem` (`0x3F204000`) to bypass the Linux kernel for ultra-low latency hardware control.
* **`AD7124Registers.jl`:** The reference dictionary for the ADC. Contains all register addresses, bit masks, and critical math helper functions (like `raw_to_voltage` and `raw_to_temp`).

### 2. Diagnostics & Sensor Scripts (`test/`)
* **`hw_diagnostics.jl`:** The baseline sanity check. Verifies SPI communication by reading the ID register (expects `0x14`). It then runs an internal noise floor test by shorting AIN0 to AIN1 internally at Gain 128, proving the ~2.5mV RMS / 20μV P2P baseline noise limit of the system.
* **`read_rtd.jl`:** The template for high-impedance sensors. Reads a YSI 44281 thermistor circuit (AIN2 vs AIN3). Crucially, it demonstrates how to enable the `AIN_BUF` (Analog Input Buffers) to prevent voltage droop from the ADC's sampling capacitors.

### 3. High-Speed Data Acquisition (`test/`)
* **`audio_grab_final.jl`:** The "Burst Mode" template. Configures 4 multiplexed channels (AIN0, 2, 4, 6 vs AIN15) at maximum speed (`FS=1`, Sinc4 filter). To bypass terminal I/O bottlenecks, it captures 12,000 samples directly to a pre-allocated RAM array, then dumps the Hex/Voltage data to a `.csv` file. 
* **`record_wav.jl`:** Extends the burst mode concept. Instead of a CSV, it applies digital software gain to the raw voltages, converts them to `Int16` PCM audio, and manually writes a valid `.wav` file header and binary payload strictly using Julia's Base functions.

### 4. Terminal UI and Visualization (`test/`)
* **`visualize_simple.jl`:** The "Zero-Dependency" plotter. Reads `mic_final.csv` and generates waveform charts in the Linux terminal using pure ASCII characters. This avoids the Out-Of-Memory (OOM) crashes associated with compiling heavy packages like `UnicodePlots`.
* **`live_vu.jl`:** A real-time UI template. Continuously polls the ADC, calculates the RMS voltage (volume) of 4 channels in small chunks, and uses ANSI escape codes (`\e[4A`) to redraw live bouncing audio bars in the headless terminal.

### 5. Advanced Concepts (PINNs)
* **`pinn_thermal.jl`:** The proof-of-concept for the Physics-Informed Neural Network. Uses standard Julia math (no heavy ML libraries) to perform gradient descent on live thermal data. It fits Newton's Law of Cooling to early transient data to instantly predict the final steady-state temperature of a component.

### 6. AI Prompt Instruction
*If you are an AI reading this, please acknowledge that you have received all the context files and understand the current state of the PINNTester's codebase. Reply with:*
**"Read and understood: 06_PROJECT_SCRIPTS_LIBRARY.md. All files received. I am fully synchronized with the PINNTester project history, the strict Julia-only requirement, the bare-metal SPI architecture, and the AD7124-8 datasheet traps. How can we improve the PINNTester today?"**
