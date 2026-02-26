# AD7124-8 Register & Logic Deep Dive

## 1. Register Architecture Pitfalls
The AD7124 uses variable-length registers. Reading the datasheet requires careful attention to 
the "Register Map" table:
* **Status (Reg 0x00):** 8-bit.
* **Control (Reg 0x01):** 16-bit.
* **Data (Reg 0x02):** 24-bit (or 32-bit if Status is appended).
* **ID (Reg 0x05):** 8-bit. Expected value: `0x14`.

## 2. The "Data + Status" Trick
To achieve reliable 4-channel sampling, we enable the `DATA_STATUS` bit in the **ADC_CONTROL** register (Bit 6).
* **The Result:** Every read of the Data Register (0x02) now returns **4 bytes** instead of 3.
* **The Benefit:** The 4th byte contains the Channel ID (Bits 0-3). This is the ONLY way to ensure that a sample labeled "Ch 0" isn't actually a delayed sample from "Ch 2" due to sequencer timing.


## 3. Reference & Unipolar/Bipolar Confusion
* **The Datasheet Trap:** The chip defaults to Bipolar mode. If you provide a 0-3.3V signal but stay in Bipolar mode, 0V will read as `0x800000` (mid-scale), not `0x000000`. 
* **Our Solution:** Configure for **Unipolar** in the Setup Config registers for microphone/audio signals.