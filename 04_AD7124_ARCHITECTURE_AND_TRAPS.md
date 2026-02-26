# 04_AD7124_ARCHITECTURE_AND_TRAPS.md
## The AD7124-8: Conceptual Hurdles and SPI Traps

### 1. The Setup/Channel Paradigm

Standard microcontrollers often let you simply say "Read Pin A0." The AD7124-8 does not work this way; its architecture is highly decoupled for maximum flexibility.
* **Setups (The "How"):** The chip holds 8 independent "Setups" (Setup 0 through Setup 7). A Setup defines the *Configuration* (Bipolar/Unipolar, Gain, Reference source) and the *Filter* (Sinc3/Sinc4, Output Data Rate).
* **Channels (The "What"):** The chip has 16 logical "Channels" (Channel 0 through 15). A Channel maps a physical positive pin (`AINP`), a physical negative pin (`AINM`), and assigns them to one of the 8 Setups. 
* **The Rule:** You enable a *Channel*, and the ADC automatically applies the hardware settings defined in its linked *Setup*.

### 2. The `DATA_STATUS` Trap (Frame Desync)
When multiplexing multiple channels (like our 4-mic array), you must know which channel a piece of data belongs to.
* **The Mechanism:** By setting the `DATA_STATUS` bit (Bit 10) in the `ADC_Control` register (`0x01`), the ADC appends the Status register to the end of every Data read.
* **The Trap:** The Data register (`0x02`) is normally 24 bits (3 bytes) long. When `DATA_STATUS` is enabled, the read operation immediately becomes **32 bits (4 bytes)** long. 
* **The Consequence:** If you enable `DATA_STATUS` but your bare-metal driver only clocks out 3 bytes, the 4th byte is left dangling in the ADC's hardware SPI shift register. The next time you try to read a register, the SPI frame will be permanently out of sync, returning garbage data. *Always adjust your byte-read length to 4 when this bit is high!*

### 3. The POR (Power-On Reset) Trap

When the AD7124-8 first receives power, it sets the `POR_FLAG` (Bit 4) in the `Status` register (`0x00`).
* **The Trap:** The ADC is extremely cautious. If it powers up, it may refuse to begin continuous conversions or accept certain commands until the host explicitly acknowledges that a reset occurred.
* **The Fix:** Your initialization script must read the `Status` register at least once during boot. Reading the register automatically clears the `POR` bit and gives the ADC the green light to operate normally.

### 4. Polling for Ready (`RDY_n`)
The AD7124-8 is a Sigma-Delta ADC, meaning it takes time for its digital filter to settle and produce a valid conversion.
* **The Trap:** You cannot simply blast a read command to the Data register (`0x02`) whenever you want. If you read blindly, you will either get old data or corrupt the ongoing conversion.
* **The Fix:** You must continuously read the `Status` register (`0x00`) in a tight `while` loop and monitor Bit 7 (`RDY_n`). 
  * `1` = ADC is busy converting.
  * `0` = Fresh data is ready.
  * *Code Example:* `while (read_reg(spi, 0x00) & 0x80) != 0 end`

### 5. AI Prompt Instruction
*If you are an AI reading this, please acknowledge that you understand the Setup/Channel mapping, the 4-byte `DATA_STATUS` trap, the `POR` flag clearing requirement, and the `RDY_n` spin-lock polling method by replying: "Read and understood: 04_AD7124_ARCHITECTURE_AND_TRAPS.md. Ready for the next file."*