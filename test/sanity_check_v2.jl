# =========================================================
# FILE: test/sanity_check_v2.jl
# USAGE: sudo ~/.juliaup/bin/julia test/sanity_check_v2.jl
# =========================================================

project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "AD7124.jl"))
include(joinpath(project_root, "src", "DirectSPI.jl"))

using .AD7124
using .DirectSPI
using Printf
using Mmap

# --- CONSTANTS FOR KERNEL CONTROL ---
const DRIVER_PATH = "/sys/bus/platform/drivers/spi-bcm2835"
# 3f204000.spi is the standard ID for SPI0 on Pi Zero 2 W / Pi 3
const DEV_ID = "3f204000.spi" 

# =========================================================
# 1. KERNEL DRIVER CONTROL (BIND/UNBIND)
# =========================================================

function ensure_kernel_driver()
    println("   ⚡ Checking Kernel SPI Driver...")
    
    # Check if spidev exists
    if isfile("/dev/spidev0.0")
        println("      ✅ /dev/spidev0.0 is present.")
        return
    end

    println("      ⚠️  /dev/spidev0.0 missing. Attempting to BIND...")
    
    # 1. Ensure Module is Loaded
    try run(`sudo modprobe spi_bcm2835`); catch; end
    
    # 2. Bind Device
    try
        run(`sudo sh -c "echo $DEV_ID > $DRIVER_PATH/bind"`)
    catch
        # Might fail if already bound but dev missing for other reasons
    end

    # 3. Wait for udev
    sleep(0.5)
    if isfile("/dev/spidev0.0")
        println("      ✅ Driver restored.")
    else
        println("      ❌ ERROR: Could not restore driver. Is SPI enabled in /boot/config.txt?")
    end
end

function stop_kernel_driver()
    println("\n[TRANSITION] Unbinding Kernel Driver ($DEV_ID)...")
    try
        run(`sudo sh -c "echo $DEV_ID > $DRIVER_PATH/unbind"`)
        println("      ✅ Unbound successfully.")
    catch
        println("      ℹ️  Driver was already unbound.")
    end
end

# =========================================================
# 2. BARE METAL GPIO CONFIGURATION
# =========================================================
function configure_gpio_spi()
    # Pi Zero 2 W (BCM2837) GPIO Base
    GPIO_BASE = 0x3F200000
    
    println("   🔧 Configuring GPIO Pins 8, 9, 10, 11 to ALT0 (SPI)...")
    
    f = open("/dev/mem", "r+")
    try
        gpio_regs = Mmap.mmap(f, Vector{UInt32}, (1024,), GPIO_BASE; grow=false, shared=true)
        
        fsel0 = unsafe_load(pointer(gpio_regs, 1))
        fsel1 = unsafe_load(pointer(gpio_regs, 2))
        
        # --- FIX: PIN 8 (CE0) AND PIN 9 (MISO) ---
        # Clear bits
        mask_8_9 = ~((UInt32(7) << 24) | (UInt32(7) << 27))
        fsel0 &= mask_8_9
        # Set ALT0 (4)
        val_8 = UInt32(4) << 24
        val_9 = UInt32(4) << 27
        fsel0 |= (val_8 | val_9)
        
        # --- FIX: PIN 10 (MOSI) AND PIN 11 (SCLK) ---
        # Clear bits
        mask_10_11 = ~((UInt32(7) << 0) | (UInt32(7) << 3))
        fsel1 &= mask_10_11
        # Set ALT0 (4)
        val_10 = UInt32(4) << 0
        val_11 = UInt32(4) << 3
        fsel1 |= (val_10 | val_11)
        
        # Write Back
        unsafe_store!(pointer(gpio_regs, 1), fsel0)
        unsafe_store!(pointer(gpio_regs, 2), fsel1)
        
        println("      ✅ GPIO Config Complete: CS(8), MISO(9), MOSI(10), SCLK(11) -> ALT0")
        
    catch e
        println("      ❌ GPIO Config Failed: $e")
    finally
        close(f)
    end
end

# =========================================================
# 3. SAFETY HELPERS
# =========================================================
function with_watchdog(f::Function, timeout_sec::Int)
    ccall(:alarm, Cuint, (Cuint,), timeout_sec)
    try
        f()
    catch e
        if isa(e, InterruptException)
            error("🛑 WATCHDOG FIRED! Operation timed out.")
        else
            rethrow(e)
        end
    finally
        ccall(:alarm, Cuint, (Cuint,), 0)
    end
end

@inline function volatile_load_local(ptr::Ptr{UInt32})
    return Base.llvmcall(
        """
        %ptr = inttoptr i64 %0 to i32*
        %val = load volatile i32, i32* %ptr, align 4
        ret i32 %val
        """,
        UInt32, Tuple{UInt64}, UInt64(ptr)
    )
end

# =========================================================
# MAIN TEST LOGIC
# =========================================================
function run_test()
    println("\n=== 🏥 HARDWARE SANITY CHECK V2 (Integrated) ===")
    
    # --- PHASE 1: KERNEL TEST ---
    ensure_kernel_driver()
    
    println("\n[TEST 1] Kernel Driver (ioctl)")
    try
        linux_drv = AD7124.AD7124Driver("/dev/spidev0.0", 2000000) 
        AD7124.reset(linux_drv)
        id = AD7124.register_read(linux_drv, 0x05, 1)
        println("   ✅ Kernel Read ID: 0x$(string(id, base=16))")
        AD7124.close_driver(linux_drv)
    catch e
        println("   ❌ Kernel Test Failed: $e")
        println("      (Aborting to avoid inconsistent state)")
        return
    end

    # --- PHASE 2: SWITCH TO BARE METAL ---
    stop_kernel_driver()  # Unbind via sysfs
    configure_gpio_spi()  # Fix pins
    
    # --- PHASE 3: MMAP TEST ---
    println("\n[TEST 2] Bare Metal MMap (Read ID 0x45)")
    try
        with_watchdog(3) do
            drv = DirectSPI.SPIMmapDriver()
            cs   = pointer(drv.regs, DirectSPI.REG_CS)
            fifo = pointer(drv.regs, DirectSPI.REG_FIFO)
            clk  = pointer(drv.regs, DirectSPI.REG_CLK)
            
            # 1. INIT CLOCK (Crucial)
            # Unbind resets this to 0. We set it to 128 (approx 1.9 MHz)
            println("   -> Setting Clock Divider to 128...")
            unsafe_store!(clk, UInt32(128))
            
            # 2. CLEAR FIFO
            unsafe_store!(cs, UInt32(DirectSPI.CS_CLEAR_RX | DirectSPI.CS_CLEAR_TX))
            
            # 3. START TRANSACTION
            # Mode 3 (CPOL=1, CPHA=1), TA=1, CS=0
            println("   -> Starting Transaction...")
            unsafe_store!(cs, UInt32(DirectSPI.CS_TA | DirectSPI.CS_CPOL | DirectSPI.CS_CPHA | DirectSPI.CS_CS_0))
            
            # 4. WRITE COMMANDS (0x45 = Read ID, 0x00 = Dummy)
            unsafe_store!(fifo, 0x45)
            unsafe_store!(fifo, 0x00)
            
            # 5. WAIT FOR DONE
            while (volatile_load_local(cs) & DirectSPI.CS_DONE) == 0; end
            
            # 6. READ RESULTS
            b1 = volatile_load_local(fifo) & 0xFF
            b2 = volatile_load_local(fifo) & 0xFF
            
            println("   -> Bytes Received: [0x$(string(b1,base=16)) | 0x$(string(b2,base=16))]")
            
            if b2 == 0x14 || b2 == 0x16
                println("   🎉 SUCCESS! Bare metal matches Kernel.")
            else
                println("   ❌ FAILURE. Expected 0x14.")
            end
            
            unsafe_store!(cs, 0)
            DirectSPI.close_driver(drv)
        end
    catch e
        println("   ❌ MMap Test Failed: $e")
    end

    # --- PHASE 4: CLEANUP ---
    println("\n[CLEANUP] Restoring Kernel Driver...")
    try
        run(`sudo sh -c "echo $DEV_ID > $DRIVER_PATH/bind"`)
        println("   ✅ System restored to normal.")
    catch
        println("   ⚠️  Could not re-bind driver.")
    end
end

run_test()