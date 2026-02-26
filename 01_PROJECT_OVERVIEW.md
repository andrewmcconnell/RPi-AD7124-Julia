# 00_PROJECT_OVERVIEW.md
## Project Name: The PINNTester

### 1. The Mission
The "PINNTester" is a next-generation, high-precision measurement and diagnostic tool. It moves beyond standard multimeters by combining ultra-precise analog-to-digital conversion with Physics-Informed Neural Networks (PINNs) and modern control theory (`ControlSystems.jl`). 

The ultimate goal is to create an "oracle" for electronics technicians and roboticists—a device that doesn't just measure voltage, but can estimate hidden circuit parameters (R, L, C values), predict thermal steady-states in real-time using Newton's Law of Cooling, and act as the central brain/observer for 6-axis robotics control loops.

### 2. Hardware Stack

* **Host Device:** Raspberry Pi Zero 2 W.
* **OS:** Headless Debian Linux (aarch64) with a 2GB Swapfile.
* **ADC:** Analog Devices EVAL-AD7124-8-PMDZ. 
  * A 24-bit, 8-channel (or 16 single-ended) low-noise, low-power Sigma-Delta ADC.
  * Programmable Gain Amplifier (PGA) from Gain 1 to 128.
  * Internal 2.5V reference.
* **Connection:** Hardware SPI bus.

### 3. Software Stack
* **Language:** Julia v1.12 (running natively on the Pi).
* **Driver Architecture:** Custom "Bare-Metal" SPI driver (`BareMetalDebug.jl`). We completely bypass the standard Linux `spidev` kernel drivers by using `Mmap` to read and write directly to the BCM2835/BCM2710 peripheral memory addresses (`0x3F204000`). This ensures ultra-low latency for high-speed ADC polling.
* **Dependencies:** Strictly limited to lightweight, standard Julia libraries (e.g., `DelimitedFiles`, `Statistics`, `Mmap`). 
* **Constraint:** Heavy packages (like `Plots.jl` or `UnicodePlots`) cause Out-Of-Memory (OOM) kernel crashes on the Pi Zero 2 W during parallel precompilation. All visualization must be done via lightweight ASCII text plotters or by exporting `.csv`/`.wav` files to a host PC.

### 4. Current State & Achievements
The core hardware and driver layers are 100% validated and stable.
1. **Low-Level Comms:** Flawless bare-metal SPI reads/writes (verified via ADC ID `0x14`).
2. **Noise Floor Validation:** Achieved ~2.5mV RMS noise floor and ~20μV peak-to-peak noise using internal shorted inputs at Gain 128.
3. **High-Impedance Sensors:** Successfully read a YSI 44281 thermistor circuit (3kΩ/6kΩ network) using the ADC's internal input buffers.
4. **Audio Multiplexing:** Successfully multiplexed 4 electret microphones across 4 channels at ~760 Samples Per Second (SPS) per channel, saving to both CSV arrays and generating playable `.wav` files.
5. **Real-Time UI:** Created a live, 4-channel ASCII "VU Meter" in the Linux terminal for real-time acoustic monitoring.

### 5. AI Prompt Instruction
*If you are an AI reading this, please acknowledge that you understand the PINNTester's mission, hardware, and software stack by replying: "Read and understood: 00_PROJECT_OVERVIEW.md. Ready for the next file."*
