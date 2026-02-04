# =========================================================
# FILE: test/speed_test_v3.jl
# USAGE: sudo ~/.juliaup/bin/julia test/speed_test_v3.jl
# =========================================================

project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "BareMetalSPI.jl"))
using .BareMetalSPI
using Printf
using Dates

function run_speed_test_v3()
    println("\n=== 🏎️  BARE METAL DATA CAPTURE (V3) ===")
    
    spi = BareMetalSPI.init()
    
    # --- PRE-ALLOCATION (CRITICAL) ---
    # We want to capture slightly more than 1 second of data.
    # 19200 SPS * 1.5 seconds = ~28,800 samples.
    MAX_SAMPLES = 30000
    data_buffer = Vector{UInt32}(undef, MAX_SAMPLES)
    sample_count = 0
    
    try
        # 1. SETUP
        println("-> Configuring AD7124 (Full Power, Sinc4, FS=1)...")
        BareMetalSPI.write_register(spi, 0x01, 0x01C0, 2) # ADC_Control
        BareMetalSPI.write_register(spi, 0x21, 0x060001, 3) # Filter_0
        sleep(0.1)
        
        # 2. VERIFY STATUS
        status = BareMetalSPI.read_register_8(spi, 0x00)
        println("-> Initial Status: 0x$(string(status, base=16))")
        
        # 3. CAPTURE LOOP
        println("-> 🟢 STARTING CAPTURE (Buffer size: $MAX_SAMPLES)...")
        start_time = time()
        
        # We assume 0x00 = Status Register. 0x80 is /RDY bit.
        # We inline the loop logic for max speed.
        
        while sample_count < MAX_SAMPLES
            # A. Check RDY (Status Reg)
            s = BareMetalSPI.read_register_8(spi, 0x00)
            
            if (s & 0x80) == 0
                # B. Capture Data
                sample_count += 1
                data_buffer[sample_count] = BareMetalSPI.read_data_24(spi)
            end
            
            # Safety break (if loop runs too long, e.g. 2 seconds)
            if (time() - start_time) > 2.0
                println("-> ⚠️ Timeout reached!")
                break
            end
        end
        
        total_time = time() - start_time
        println("-> 🔴 STOPPED.")
        
        # 4. STATISTICS
        sps = sample_count / total_time
        println("\n=== 📊 REPORT ===")
        @printf("Samples Captured: %d\n", sample_count)
        @printf("Total Duration:   %.4f s\n", total_time)
        @printf("Throughput:       %.2f SPS\n", sps)
        
        # 5. DATA INSPECTION
        println("\n=== 🔍 FIRST 5 SAMPLES ===")
        for i in 1:min(5, sample_count)
            val = data_buffer[i]
            # Convert to voltage (assuming Unipolar, VRef=2.5V, Gain=1)
            # Code = (Vin * 2^24) / VRef
            # Vin = (Code * Vref) / 2^24
            volts = (val * 2.5) / 16777216
            @printf("[%d] Hex: 0x%06X | Volts: %.6f V\n", i, val, volts)
        end
        
        # 6. SAVE FILE
        filename = "capture_$(Dates.format(now(), "HHMMSS")).bin"
        open(filename, "w") do f
            # We only write the valid part of the buffer
            write(f, data_buffer[1:sample_count])
        end
        println("\n💾 Saved raw data to '$filename'")
        
    catch e
        println("ERROR: $e")
    finally
        BareMetalSPI.close_spi(spi)
    end
    
end

run_speed_test_v3()