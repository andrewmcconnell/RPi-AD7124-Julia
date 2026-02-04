# =========================================================
# FILE: test/speed_test_v2.jl
# USAGE: sudo ~/.juliaup/bin/julia test/speed_test_v2.jl
# =========================================================

project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "BareMetalSPI.jl"))
using .BareMetalSPI
using Printf

function run_speed_test()
    println("\n=== 🏎️  BARE METAL SPEED TEST V2 ===")
    
    spi = BareMetalSPI.init()
    
    try
        # 1. SETUP: High Speed Configuration
        println("-> Configuring AD7124...")
        
        # A. ADC_CONTROL (0x01) - 16 Bit Register
        # OLD BUG: We sent 0x0C00 (Low Power).
        # NEW FIX: We want Full Power (Bits 7:6 = 11).
        # Val = 0x00C0 (Mid Power=01, Full=11... wait, Bits 7:6. 11 = 0xC0)
        # 0x01C0 = Full Power + Data Status Bit Enabled (Optional)
        println("   Writing ADC_CONTROL (16-bit)...")
        BareMetalSPI.write_register(spi, 0x01, 0x01C0, 2)
        
        # B. FILTER_0 (0x21) - 24 Bit Register (CRITICAL FIX)
        # OLD BUG: We only wrote 16 bits.
        # NEW FIX: Write 24 bits.
        # Val = 0x060001 (Sinc4, FS=1)
        println("   Writing FILTER_0 (24-bit)...")
        BareMetalSPI.write_register(spi, 0x21, 0x060001, 3)
        
        sleep(0.1) # Settle

        # 2. VERIFY (Read Status)
        println("-> Verifying Status...")
        for i in 1:3
            s = BareMetalSPI.read_register_8(spi, 0x00)
            @printf("   Status Read: 0x%02X\n", s)
        end
        
        # 3. THE RACE (Allocation Free Loop)
        println("-> Starting 1 Second Loop (Optimized)...")
        
        start_time = time()
        samples = 0
        reads = 0
        
        # Using Base.time() for non-blocking check
        while (time() - start_time) < 1.0
            reads += 1
            
            # 1. Check Status (Bit 7 must be 0)
            # 0x00 = Register Address 0x00
            # We inline the logic manually here or use helper
            # 0x40 = Read Bit | 0x00 Addr
            status = BareMetalSPI.read_register_8(spi, 0x00)
            
            if (status & 0x80) == 0
                # 2. Read Data (0x02). Command 0x42.
                # We need to read 3 bytes of data (plus 1 cmd byte = 4 bytes total)
                # We just pump the clock 4 times.
                BareMetalSPI.transfer_bytes(spi, 0x42, 0x00, 0x00, 0x00, 4)
                samples += 1
            end
        end
        
        duration = time() - start_time
        
        println("\n=== 🏁 RESULTS ===")
        @printf("Time:     %.4f seconds\n", duration)
        @printf("Attempts: %d loops\n", reads)
        @printf("Samples:  %d captured\n", samples)
        @printf("Speed:    %.2f SPS\n", samples / duration)
        
    catch e
        println("ERROR: $e")
        rethrow(e)
    finally
        BareMetalSPI.close_spi(spi)
        println("-> Driver Closed.")
    end
end

run_speed_test()