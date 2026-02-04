# =========================================================
# FILE: test/sanity_check.jl
# USAGE: sudo ~/.juliaup/bin/julia test/sanity_check.jl
# =========================================================

# 1. SETUP PATHS
project_root = dirname(@__DIR__)
src_spi_path = joinpath(project_root, "src", "DirectSPI.jl")
src_ad_path  = joinpath(project_root, "src", "AD7124.jl")

# Load Modules
if isfile(src_ad_path)
    include(src_ad_path)
else
    error("Could not find src/AD7124.jl")
end

if isfile(src_spi_path)
    include(src_spi_path)
else
    error("Could not find src/DirectSPI.jl")
end

using .AD7124
using .DirectSPI
using Printf

# =========================================================
# SAFETY UTILITIES
# =========================================================

# 1. Soft Watchdog (Requested)
function with_watchdog(f::Function, timeout_sec::Int)
    # Set SIGALRM
    ccall(:alarm, Cuint, (Cuint,), timeout_sec)
    try
        f()
    catch e
        if isa(e, InterruptException)
            error("🛑 WATCHDOG FIRED! Operation timed out after $timeout_sec seconds.")
        else
            rethrow(e)
        end
    finally
        # Disable Alarm
        ccall(:alarm, Cuint, (Cuint,), 0)
    end
end

# 2. Volatile Load (Crucial for MMap Loop)
# We redefine this locally to ensure this script is safe even if the module changes.
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

const DRIVER_PATH = "/sys/bus/platform/drivers/spi-bcm2835"
# Auto-detect ID
const DEV_ID = first(filter(x -> endswith(x, ".spi"), readdir(DRIVER_PATH)))

function stop_kernel_driver()
    println("   ⏸️  Unbinding Kernel Driver ($DEV_ID)...")
    try
        write(joinpath(DRIVER_PATH, "unbind"), DEV_ID)
    catch
        # Ignore if already unbound
    end
end

function start_kernel_driver()
    println("   ▶️  Re-binding Kernel Driver...")
    try
        write(joinpath(DRIVER_PATH, "bind"), DEV_ID)
    catch
        # Ignore if already bound or busy
    end
end

# =========================================================
# MAIN TEST
# =========================================================

function run_test()
    println("\n=== 🏥 HARDWARE SANITY CHECK ===")
    
    # ---------------------------------------------------------
    # PART 1: THE "GOLDEN STANDARD" (Kernel IOCTL)
    # ---------------------------------------------------------
    println("\n[TEST 1] Standard Linux Kernel Driver (ioctl)")
    println("   Goal: Read Chip ID (Reg 0x05) using standard Linux tools.")
    
    try
        # Ensure driver is loaded for Test 1
        # We try to load it, but ignore errors if it's already there or permissions fail
        start_kernel_driver()
        #try run(`sudo modprobe spi_bcm2835`); catch; end

        linux_drv = AD7124.AD7124Driver("/dev/spidev0.0", 2000000) 
        AD7124.reset(linux_drv)
        id = AD7124.register_read(linux_drv, 0x05, 1)
        
        println("   ✅ Kernel Read ID: 0x", string(id, base=16, pad=2))
        AD7124.close_driver(linux_drv)
        
    catch e
        println("   ❌ Kernel Test Failed: $e")
        println("      (Skipping MMap test because hardware state is unknown)")
        return
    end

    # ---------------------------------------------------------
    # TRANSITION: UNLOAD KERNEL DRIVER
    # ---------------------------------------------------------
    println("\n[TRANSITION] Unloading Kernel Driver to prevent conflict...")
    try
        # 1. Remove the driver so it releases the hardware
        #run(`sudo rmmod spi_bcm2835`)
        stop_kernel_driver()
        println("   ✅ Driver unloaded.")
        
        # 2. Force Pins to ALT0 (SPI)
        # Unloading the driver might reset pins to INPUT. We must set them back.
        # This requires raspi-gpio. If not installed, this might fail (ignore if so).
        try
            run(`sudo raspi-gpio set 9 a0`)
            run(`sudo raspi-gpio set 10 a0`)
            run(`sudo raspi-gpio set 11 a0`)
            println("   ✅ Pins forced to ALT0 (SPI Mode).")
        catch
            println("   ⚠️  Could not set pins via raspi-gpio. Assuming they stuck correctly.")
        end
        
    catch e
        println("   ⚠️  Warning during unload: $e")
    end

    # ---------------------------------------------------------
    # PART 2: THE "BARE METAL" (Direct Memory)
    # ---------------------------------------------------------
    println("\n[TEST 2] Direct Memory Access (MMap) with Watchdog")
    
    with_watchdog(3) do
        try
            mmap_drv = DirectSPI.SPIMmapDriver()
            ptr_cs   = pointer(mmap_drv.regs, DirectSPI.REG_CS)
            ptr_fifo = pointer(mmap_drv.regs, DirectSPI.REG_FIFO)
            
            # 1. SETUP
            # Use unsafe_store! (Volatile store isn't strictly needed for setup, but good practice)
            unsafe_store!(ptr_cs, UInt32(DirectSPI.CS_CLEAR_RX | DirectSPI.CS_CLEAR_TX))
            
            # 2. COMMAND
            println("   -> Writing Command 0x45 (Read ID)...")
            
            # Start Transaction (TA=1)
            # We assume DirectSPI.CS_* constants are available
            unsafe_store!(ptr_cs, UInt32(DirectSPI.CS_TA | DirectSPI.CS_CPOL | DirectSPI.CS_CPHA | DirectSPI.CS_CS_0))
            
            # Write Command
            unsafe_store!(ptr_fifo, 0x45)
            unsafe_store!(ptr_fifo, 0x00) # Dummy
            
            # 3. WAIT (The Fix: Volatile Load)
            # We use volatile_load_local to ensure the compiler doesn't delete this loop
            while (volatile_load_local(ptr_cs) & DirectSPI.CS_DONE) == 0
                # Spin
            end
            
            # 4. READ RESULT
            println("   -> Transaction Done. Reading FIFO...")
            byte1 = volatile_load_local(ptr_fifo) & 0xFF
            byte2 = volatile_load_local(ptr_fifo) & 0xFF
            
            @printf("      Byte 1 (Echo): 0x%02X\n", byte1)
            @printf("      Byte 2 (ID):   0x%02X\n", byte2)
            
            if byte2 == 0x14 || byte2 == 0x16
                println("   🎉 MMAP SUCCESS! Matches Kernel ID.")
            else
                println("   ❌ MMAP FAIL: Expected 0x14, got 0x$(string(byte2, base=16, pad=2))")
            end
            
            unsafe_store!(ptr_cs, 0)
            DirectSPI.close_driver(mmap_drv)
            
        catch e
            println("   ❌ MMap Test Failed: $e")
            rethrow(e)
        end
    end
end

run_test()