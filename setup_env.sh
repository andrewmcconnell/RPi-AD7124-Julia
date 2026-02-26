#!/bin/bash

# PINNTester: Automated Hardware & Software Setup Script
# Target: Raspberry Pi Zero 2 W (AArch64)
# first:
# chmod +x setup_env.sh
# sudo ./setup_env.sh
# sudo reboot
# Run this script with: sudo bash setup_env.sh


# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo."
  exit 1
fi

echo "=== Starting PINNTester Environment Setup ==="

# 2. Enable SPI Interface
echo "--> Enabling SPI..."
# Using the non-interactive mode of raspi-config (0 = enable, 1 = disable)
raspi-config nonint do_spi 0
echo "SPI enabled. (A reboot will be required)"

# 3. Add default user to hardware groups (spi, gpio)
# This helps mitigate the sudo requirement for some libraries, 
# though running scripts via sudo may still be needed for raw /dev/spidev access.
if [ -n "$SUDO_USER" ]; then
    echo "--> Adding user '$SUDO_USER' to spi and gpio groups..."
    usermod -a -G spi,gpio "$SUDO_USER"
fi

# 4. Install Julia (AArch64)
# Define the version and URLs (Update these variables for newer releases)
JULIA_MAJOR_MINOR="1.10"
JULIA_PATCH="1.10.4"
JULIA_TARBALL="julia-${JULIA_PATCH}-linux-aarch64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/aarch64/${JULIA_MAJOR_MINOR}/${JULIA_TARBALL}"

echo "--> Downloading Julia v${JULIA_PATCH} for AArch64..."
wget -q --show-progress "$JULIA_URL" -O "/tmp/$JULIA_TARBALL"

echo "--> Extracting Julia to /opt/..."
# Remove any existing installation first to avoid conflicts
rm -rf /opt/julia
tar -xzf "/tmp/$JULIA_TARBALL" -C /opt/
mv /opt/julia-$JULIA_PATCH /opt/julia

echo "--> Creating symlink to /usr/local/bin/julia..."
ln -sf /opt/julia/bin/julia /usr/local/bin/julia

# Clean up the downloaded tarball
rm "/tmp/$JULIA_TARBALL"

echo "=== Setup Complete! ==="
echo "Julia version installed:"
julia --version
echo "Please reboot the Raspberry Pi to apply the SPI and user group changes by running: sudo reboot"
