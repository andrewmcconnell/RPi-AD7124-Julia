# =========================================================
# FILE: speed_test_v4.jl
# DESCRIPTION: High-Performance AD7124 Data Capture
# USAGE: sudo ~/.juliaup/bin/julia speed_test_v4.jl
# =========================================================

project_root = dirname(@__DIR__)
# We use the Golden Master driver
include(joinpath(project_root, "src", "BareMetalSPI.jl"))

using .BareMetalSPI
using Printf
using Dates

const SAMPLES_TO_CAPTURE = 50000

function run_speed_test()
    println("\n=== 🏎️  AD7124 SPEED TEST V4 (VERIFIED CONFIG) ===")
    
    # 1. Initialize Hardware
    spi = BareMetalSPI.init()
    
    try
        # 2. Sanity Check (ID Register)
        # Using legacy helper or manual transfer just to be safe
        id = BareMetalSPI.read_register_8(spi, 0x05)
        println("1. Chip ID Check: 0x$(string(id, base=16))")
        
        if id != 0x14 && id != 0x16
            println("   ❌ CRITICAL: Chip ID failed. Aborting.")
            return
        end
        println("   ✅ Chip ID verified.")

        # 3. Apply Verified Configuration
        println("2. Configuring ADC...")
        
        # A. ADC_Control (0x01) -> 0x01C0 (Ref En, Full Power, Continuous Read)
        # We write 2 bytes: 0x01 (Upper), 0xC0 (Lower)
        BareMetalSPI.write_register(spi, 0x01, 0x01C0, 2)
        
        # B. Config_0 (0x19) -> 0x0870 (Bipolar, Internal Ref, Gain 1)
        BareMetalSPI.write_register(spi, 0x19, 0x0870, 2)
        
        # C. Filter_0 (0x21) -> 0x060001 (Sinc4, Fast, FS=1) -> Max Speed
        BareMetalSPI.write_register(spi, 0x21, 0x060001, 3)
        
        # D. Channel_0 (0x09) -> 0x8001 (Enable, AIN0 vs AIN1)
        # Changing back to measuring input pins, not the short circuit!
        BareMetalSPI.write_register(spi, 0x09, 0x8001, 2)
        
        println("   ✅ Configuration Complete.")

        # 4. The Speed Loop
        println("3. Capturing $SAMPLES_TO_CAPTURE samples...")
        
        data_buffer = Vector{UInt32}(undef, SAMPLES_TO_CAPTURE)
        
        # Pre-calculate pointers for raw speed
        ptr_cs   = spi.ptr_cs
        ptr_fifo = spi.ptr_fifo
        
        # Constants for bit manipulation
        # READ DATA Command = 0x42 (Read Reg 0x02)
        const CMD_READ_DATA = UInt32(0x42) 
        const CS_TA_START   = UInt32(BareMetalSPI.CS_TA | BareMetalSPI.CS_CPOL | BareMetalSPI.CS_CPHA | BareMetalSPI.CS_CS_0)
        const CS_CLEAR      = UInt32(BareMetalSPI.CS_CLEAR_RX | BareMetalSPI.CS_CLEAR_TX)
        const CS_DONE_MASK  = UInt32(BareMetalSPI.CS_DONE)
        
        t_start = time()
        
        for i in 1:SAMPLES_TO_CAPTURE
            # A. Start Transaction
            BareMetalSPI.unsafe_store!(ptr_cs, CS_TA_START | CS_CLEAR)
            
            # B. Write Command + 3 Dummies (Total 4 bytes)
            # We pump the FIFO quickly
            BareMetalSPI.unsafe_store!(ptr_fifo, CMD_READ_DATA)
            BareMetalSPI.unsafe_store!(ptr_fifo, 0x00)
            BareMetalSPI.unsafe_store!(ptr_fifo, 0x00)
            BareMetalSPI.unsafe_store!(ptr_fifo, 0x00)
            
            # C. Wait for Done
            while (BareMetalSPI.volatile_load(ptr_cs) & CS_DONE_MASK) == 0
                # Busy Wait
            end
            
            # D. Read FIFO
            _  = BareMetalSPI.volatile_load(ptr_fifo) # Discard Echo
            b1 = BareMetalSPI.volatile_load(ptr_fifo) & 0xFF
            b2 = BareMetalSPI.volatile_load(ptr_fifo) & 0xFF
            b3 = BareMetalSPI.volatile_load(ptr_fifo) & 0xFF
            
            # E. Store
            data_buffer[i] = (b1 << 16) | (b2 << 8) | b3
            
            # F. Stop Transaction
            BareMetalSPI.unsafe_store!(ptr_cs, 0)
        end
        
        t_end = time()
        duration = t_end - t_start
        sps = SAMPLES_TO_CAPTURE / duration
        
        println("\n=== 🏁 RESULTS ===")
        @printf("Time:     %.4f seconds\n", duration)
        @printf("Rate:     %.2f SPS\n", sps)
        
        # Show first 5 samples
        println("\nFirst 5 Samples:")
        for i in 1:5
            val = data_buffer[i]
            # Convert to Volts (Approx)
            volts = ((val / 8388608.0) - 1.0) * 2.5
            @printf("  [%d]: 0x%06X  (%.4f V)\n", i, val, volts)
        end

    finally
        BareMetalSPI.close_spi(spi)
        println("\n-> SPI Closed.")
    end
end

run_speed_test()