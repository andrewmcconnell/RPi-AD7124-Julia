# =========================================================
# FILE: test/test_module.jl
# USAGE: sudo ~/.juliaup/bin/julia test/test_module.jl
# =========================================================

# === 🛠️  BARE METAL SPI MODULE TEST ===
# -> Initializing SPI Subsystem (Hostile Takeover)...
# -> Reading ID Register (0x05)...
#    Result: 0x14
#    🎉 SUCCESS! We have full control of the SPI Block.
# -> Driver Closed.

# Ensure we can find the src folder
project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "BareMetalSPI.jl"))

using .BareMetalSPI
using Printf

function run_test()
    println("\n=== 🛠️  BARE METAL SPI MODULE TEST ===")
    
    println("-> Initializing SPI Subsystem (Hostile Takeover)...")
    spi = BareMetalSPI.init()
    
    try
        # 1. Read ID (Register 0x05)
        println("-> Reading ID Register (0x05)...")
        id = BareMetalSPI.read_register(spi, 0x05)
        
        @printf("   Result: 0x%02X\n", id)
        
        if id == 0x14 || id == 0x16
            println("   🎉 SUCCESS! We have full control of the SPI Block.")
        elseif id == 0x00
            println("   ❌ ZERO READ. Hardware clock might still be off.")
        else
            println("   ❌ UNKNOWN ID. Expected 0x14.")
        end
        
    catch e
        println("ERROR: $e")
    finally
        BareMetalSPI.close_spi(spi)
        println("-> Driver Closed.")
    end
end

run_test()