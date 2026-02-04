# =========================================================
# FILE: test/speed_test_1.jl
# USAGE: sudo ~/.juliaup/bin/julia test/speed_test_1.jl
# =========================================================

project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "BareMetalSPI.jl"))
using .BareMetalSPI
using Printf

function run_speed_test()
    println("\n=== 🏎️  BARE METAL SPEED TEST 1 ===")
    
    spi = BareMetalSPI.init()
    
    try
        # 1. SETUP: High Speed Configuration
        println("-> Configuring AD7124 for Max Speed...")
        
        # A. ADC_CONTROL (0x01): Full Power Mode (Bits 7:6 = 11)
        # 0x0C00 = Full Power
        BareMetalSPI.write_register(spi, 0x01, UInt16(0x0C00))
        
        # B. FILTER_0 (0x21): Sinc4, FS=1 (Max Speed)
        # 0x0601 -> Sinc4 (Bits 10:8=011), Output Data Rate = Max (FS=1)
        # Note: At FS=1 in Full Power, Output Rate is 19.2 kSPS
        BareMetalSPI.write_register(spi, 0x21, UInt16(0x0601))
        
        println("-> Config Done. Warming up...")
        sleep(0.1)

        # 2. THE RACE
        println("-> Starting 1 Second Loop...")
        
        start_time = time()
        samples = 0
        reads = 0
        
        # Run for approx 1 second
        while (time() - start_time) < 1.0
            reads += 1
            
            # Polling Status Register (0x00)
            status = BareMetalSPI.read_register(spi, 0x00)
            
            # Check Bit 7 (/RDY). It is Low (0) when ready.
            if (status & 0x80) == 0
                # Read Data Register (0x02) - 24 bits
                # We do a simplified 3-byte transfer here manually for speed
                # (Command 0x42 + 3 Dummy Bytes)
                BareMetalSPI.transfer(spi, [0x42, 0x00, 0x00, 0x00])
                samples += 1
            end
        end
        
        duration = time() - start_time
        
        # 3. RESULTS
        println("\n=== 🏁 RESULTS ===")
        @printf("Time:     %.4f seconds\n", duration)
        @printf("Attempts: %d loops\n", reads)
        @printf("Samples:  %d captured\n", samples)
        @printf("Speed:    %.2f SPS (Samples Per Second)\n", samples / duration)
        
    catch e
        println("ERROR: $e")
        rethrow(e)
    finally
        BareMetalSPI.close_spi(spi)
        println("-> Driver Closed.")
    end
end

run_speed_test()