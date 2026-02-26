# 03_BARE_METAL_SPI_DRIVER.md
## High-Speed Communication: The Bare-Metal SPI Approach

### 1. The Linux Kernel SPI Trap
In standard Raspberry Pi projects, developers use the Linux `spidev` interface to talk to SPI devices. However, for the PINNTester, this approach introduces a fatal bottleneck.
* **The Problem:** The AD7124-8 ADC can sample at speeds up to 19.2 kSPS. Using `spidev` requires triggering an `ioctl()` system call for every single byte or frame transferred. 
* **The Result:** The overhead of constant context-switching between user space and kernel space introduces massive latency and jitter. Polling a high-speed ADC through the Linux kernel limits throughput to a crawl and ruins the strict timing required for capturing clean audio or transient thermal waveforms.

### 2. The Bare-Metal Solution

To achieve ultra-low latency, we completely bypass the Linux kernel's SPI drivers.
* **The Method:** We use our custom Julia module, `BareMetalDebug.jl`.
* **How it Works:** The script opens `/dev/mem` (which maps the entire physical memory of the Pi) and uses the `Mmap` (Memory Mapped I/O) standard library to create a direct pointer to the BCM2835/BCM2710 SPI0 peripheral base address (`0x3F204000` on the Pi Zero 2 W).
* **The Benefit:** Writing a byte to the SPI bus becomes as fast as assigning a value to a local variable in RAM. No kernel overhead, no context switching.

### 3. Implementation Details
Because we are driving the bare silicon, we must manually manage the SPI state machine. `BareMetalDebug.jl` handles this with the following low-level mechanisms:

* **Direct Bit Manipulation:** We interact directly with the SPI Control and Status (CS) register.
  * **`CS_CPOL` & `CS_CPHA`:** The AD7124-8 requires SPI Mode 3 (Clock Polarity = 1, Clock Phase = 1). We set these bits manually in the setup phase to ensure the clock idles high and data is sampled on the trailing edge.
  * **`CS_TA` (Transfer Active):** To start sending or receiving data, we manually assert the `TA` bit. 
  * **`CS_DONE`:** Instead of relying on interrupts, we use a tight `while` loop (spin-lock) to poll the `DONE` bit. The moment it flips to `1`, we know the hardware FIFO has finished shifting bits, and we can immediately read the result.
* **Variable-Length Reads/Writes:** The AD7124-8 does not use fixed-length SPI frames. 
  * Reading the `Status` register requires 1 byte. 
  * Reading the `Data` register (with `DATA_STATUS` appended) requires 4 bytes.
  * Our driver is designed to push and pull variable chunks from the hardware FIFO byte-by-byte dynamically, ensuring we never fall out of sync with the ADC's expected frame boundaries.

### 4. AI Prompt Instruction
*If you are an AI reading this, please acknowledge that you understand the limitations of `spidev`, the necessity of the `Mmap` approach to `0x3F204000`, and the manual management of `CS_TA`, `CS_CPOL`, `CS_CPHA`, and `CS_DONE` bits by replying: "Read and understood: 03_BARE_METAL_SPI_DRIVER.md. Ready for the next file."*
