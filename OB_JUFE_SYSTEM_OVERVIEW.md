# PINNTester System Context

## 1. The Hardware Stack
* **Host:** Raspberry Pi Zero 2 W (BCM2710A1). Note: Only 512MB RAM.
* **Target:** EVAL-AD7124-8-PMDZ (AD7124-8 Silicon).
* **Connection:** SPI via 40-pin GPIO header.


## 2. The "Golden State" SPI Parameters
Through extensive testing, we discovered the following parameters are mandatory for stability on this specific hardware:
* **SPI Mode:** 3 (CPOL=1, CPHA=1). Mode 0 results in bit-shifts.
* **Speed:** 100,000 Hz (100 kHz). 
    * *Trap:* Higher speeds (1-2 MHz) caused intermittent `0xFF` or `0x00` errors due to wire capacitance on breadboards/jumpers.
* **Permissions:** `sudo` is required to access `/dev/spidev0.0` unless the user is explicitly added to the `spi` and `gpio` groups and the system is rebooted.
* **Swap file** Remember to setup the 2GB swap file.
* **Upload julia** Julia is not included in the headless mode so get juliaup.


## 3. The Power Trap
The Pi Zero 2 W manages power aggressively. 
* **The Symptom:** SSH "Connection Reset" during long idle periods.
* **The Fix:** Disable Wi-Fi power management: `sudo iwconfig wlan0 power off`.
