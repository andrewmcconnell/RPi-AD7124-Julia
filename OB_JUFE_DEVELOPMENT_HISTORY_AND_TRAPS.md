# Lessons Learned & Traps Avoided

## 1. The "Bare Metal" Disaster
* **What we tried:** Using LLVM-level Julia calls to write directly to `/dev/mem` for "Ultimate" speed.
* **What happened:** Immediate kernel crashes and system instability.
* **The Lesson:** On Raspberry Pi OS (Linux), use the standard `ioctl` driver approach. The performance hit is negligible compared to the cost of a crashed headless node.

## 2. The Memory/Swap Milestone
* **The Trap:** Julia's JIT compiler and package manager (`Pkg`) will crash the Pi Zero 2 W (OOM error) because 512MB RAM is insufficient.
* **The Fix:** A **2GB Swapfile** is mandatory. 
* **Critical Trick:** You must remove `systemd-zram-generator` before enabling `dphys-swapfile`, or the system will try to compress RAM instead of using the SD card, causing a deadlock.

## 3. SPI Call Strategies
We moved through three levels of SPI implementation:
1.  **High-Level Julia IO:** Too slow and inconsistent with `ioctl` flags.
2.  **Bare Metal (Memory Mapping):** Dangerous and caused crashes.
3.  **Intermediate `ccall` (Current):** Using Julia's `ccall` to trigger the Linux C library `ioctl` function. This is our "Golden Path"—it provides C-speed stability with Julia-level flexibility.

## 4. Troubleshooting Checklist for New Nodes
If a new Pi setup returns `0x00` or `0xFF` on an ID check:
1.  **Check Reset:** Send 64 clocks of '1' (`0xFF`) before the first command. The AD7124 SPI interface can get "out of sync" if the Pi restarts but the Chip doesn't.
2.  **Check Device Tree:** Ensure `dtparam=spi=on` is in `/boot/config.txt`.
3.  **Check Header Contact:** Pi Zero 2 W pins often have poor contact if using hammer-headers or low-quality soldering.