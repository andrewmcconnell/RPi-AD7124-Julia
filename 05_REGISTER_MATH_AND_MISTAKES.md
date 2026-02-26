# 05_REGISTER_MATH_AND_MISTAKES.md
## Datasheet Traps, Math, and Register Misinterpretations

### 1. The Saturation Trap (`0xFFFFFF`)
When reading the 24-bit data register, getting a persistent output of `0xFFFFFF` does not mean the SPI is broken or the data is "fake." It means the ADC is **railing (saturated)**.
* **The Physics:** The maximum voltage the ADC can read is defined by $V_{max} = \frac{V_{ref}}{Gain}$.
* **The Trap:** We originally tried to measure a DC-biased electret microphone (sitting at 1.40V DC) using Gain 16 and an internal 2.5V reference. The maximum readable voltage was $\frac{2.5V}{16} = 0.15625V$. Because 1.40V heavily exceeds 0.156V, the ADC simply output its maximum digital code: `0xFFFFFF`.
* **The Fix:** To read a 1.4V signal without AC coupling (capacitors), you **must** use Gain 1, which opens the readable range to $\pm 2.5V$.

### 2. Datasheet Coding Mistakes (Manual Hex)

Writing raw hexadecimal values directly to registers is a massive source of silent errors. 
* **The Trap:** We manually calculated the `Config` register value as `0x0854`. However, `0x0854` silently set Bit 6 (`AIN_BUFP`) to `1`, unintentionally enabling the positive analog input buffer. This caused weird voltage offsets because buffers require headroom and alter the input characteristics.
* **The Fix:** Always map bits explicitly. The correct value was `0x0814`. When writing Julia code, construct the hex using clear bitwise shifts (e.g., `(1 << 11) | (4 << 0)`) or document the binary breakdown strictly:
  `# Binary: 0000 1000 0001 0100 -> 0x0814`

### 3. Understanding `AINP` and `AINM` in Registers
To map a physical pin to a logical channel, you write to the Channel Registers (`0x09` to `0x18`). The AD7124-8 datasheet defines these using 5-bit fields.
* **`AINP` (Bits 9:5):** Selects the Positive input pin.
* **`AINM` (Bits 4:0):** Selects the Negative (reference) input pin.
* **Example:** To measure AIN2 (Positive) against AIN15 (Common Ground/Negative):
  * AIN2 is `00010` (Decimal 2)
  * AIN15 is `01111` (Decimal 15)
  * Combined into bits 9:0, this becomes `0001001111` (Hex `0x04F`). When combined with the Enable bit (Bit 15), the final write for Channel 2 is `0x804F`.

### 4. Voltage Conversion Math
The 24-bit raw code (`0x000000` to `0xFFFFFF`) must be converted to Volts using specific equations depending on the Polarity mode set in the Configuration register.
* **Unipolar Mode:**
  $$V = (\frac{Code}{2^{24}}) \times \frac{V_{ref}}{Gain}$$
* **Bipolar Mode:** (Note the divisor changes to $2^{23}$ and we subtract 1)
  $$V = (\frac{Code}{2^{23}} - 1) \times \frac{V_{ref}}{Gain}$$

### 5. High-Impedance Sensors and Buffers (RTD)

The AD7124-8 uses a switched-capacitor input stage. When it samples, it briefly draws a tiny current to charge internal capacitors.
* **The Trap:** If you connect a high-impedance source (like a $k\Omega$ or $M\Omega$ resistor network, e.g., the YSI 44281 thermistor circuit), this tiny sampling current will cause the voltage to droop, giving you wildly inaccurate readings.
* **The Fix:** You must enable the internal Analog Input Buffers by setting the `AIN_BUF` bits (Bits 6:5) in the Configuration register to `11`. This isolates your high-impedance circuit from the sampling capacitors.

### 6. Temperature Sensor Math Fix
The AD7124-8 has an internal temperature sensor (Channel `AINP = 16`, `AINM = 16`), but calculating the temperature is notoriously tricky.
* **The Trap 1:** The datasheet formula divisor contains a confusing typo/misinterpretation in some versions. The correct divisor for the math is `13584`, *not* `1358.4`.
* **The Trap 2:** The internal temp sensor **must** be read using Gain 1 and Unipolar mode. If you read it in Bipolar mode or apply PGA gain, the resulting math yields physically impossible temperatures (like 2900°C).

### 7. AI Prompt Instruction
*If you are an AI reading this, please acknowledge that you understand the 0xFFFFFF saturation trap, the AINP/AINM 5-bit addressing, the buffer requirements for high-impedance sensors, and the Unipolar/Bipolar conversion math by replying: "Read and understood: 05_REGISTER_MATH_AND_MISTAKES.md. Ready for the final file."*
