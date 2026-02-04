# =========================================================
# FILE: test/register_dump.jl
# USAGE: sudo ~/.juliaup/bin/julia test/register_dump.jl
# =========================================================

# Locate source file
project_root = dirname(@__DIR__)
src_path = joinpath(project_root, "src", "DirectSPI.jl")
if isfile(src_path)
    include(src_path)
else
    # Fallback if running from root
    include("src/DirectSPI.jl")
end

using .DirectSPI
using Printf

# --- HELPER TO PRINT BITS ---
function print_reg(name, offset, val)
    @printf("Offset +0x%02X | %-6s | Hex: 0x%08X | Bin: %s\n", 
            offset * 4, name, val, string(val, base=2, pad=32))
end

try
    println("\n=== 🕵️ SPI REGISTER NEIGHBORHOOD DUMP ===")
    drv = DirectSPI.SPIMmapDriver()
    
    # 1. READ NEIGHBORHOOD (CS, FIFO, CLK, DLEN)
    # The 'regs' array is UInt32, so index 1 = 0x00, index 2 = 0x04...
    println("Raw Memory Snapshot:")
    println("----------------------------------------------------------------")
    
    # CS (Index 1)
    val_cs = unsafe_load(pointer(drv.regs, 1))
    print_reg("CS", 0, val_cs)
    
    # FIFO (Index 2) - Reading this pops data, but fine for debug
    val_fifo = unsafe_load(pointer(drv.regs, 2))
    print_reg("FIFO", 1, val_fifo)
    
    # CLK (Index 3)
    val_clk = unsafe_load(pointer(drv.regs, 3))
    print_reg("CLK", 2, val_clk)
    
    # DLEN (Index 4)
    val_dlen = unsafe_load(pointer(drv.regs, 4))
    print_reg("DLEN", 3, val_dlen)
    
    println("----------------------------------------------------------------")
    
    # 2. ADDRESS VERIFICATION
    if val_clk == 128
        println("✅ CLK Register is 128. Base Address 0x3F204000 is CORRECT.")
    else
        println("⚠️ CLK Register is $(val_clk). Expected 128. We might be lost.")
    end

    # 3. MANUAL DATA CAPTURE
    println("\n=== 🧪 MANUAL DATA CAPTURE TEST ===")
    println("Sending 4 bytes (0xFF) slowly to trigger AD7124 output...")
    
    ptr_cs   = pointer(drv.regs, DirectSPI.REG_CS)
    ptr_fifo = pointer(drv.regs, DirectSPI.REG_FIFO)
    
    # A. Clear FIFOs
    unsafe_store!(ptr_cs, UInt32(DirectSPI.CS_CLEAR_RX | DirectSPI.CS_CLEAR_TX))
    
    # B. Start Transaction (TA=1, Mode 3)
    cmd = UInt32(DirectSPI.CS_TA | DirectSPI.CS_CPOL | DirectSPI.CS_CPHA | DirectSPI.CS_CS_0)
    unsafe_store!(ptr_cs, cmd)
    
    # C. Write 4 Bytes
    println("  -> Writing 0xFFFFFFFF to FIFO...")
    unsafe_store!(ptr_fifo, 0xFFFFFFFF)
    
    # D. Wait for DONE
    print("  -> Waiting for DONE... ")
    retries = 0
    while true
        curr_cs = unsafe_load(ptr_cs)
        if (curr_cs & DirectSPI.CS_DONE) != 0
            println("✅ DONE!")
            break
        end
        retries += 1
        if retries > 1000000
            println("❌ TIMEOUT.")
            break
        end
    end
    
    # E. DUMP FIFO CONTENTS
    println("\n[RAW FIFO DUMP]")
    
    # We read the FIFO 4 times to see exactly what arrived
    for i in 1:4
        raw_byte = unsafe_load(ptr_fifo)
        @printf("  Read %d: 0x%08X\n", i, raw_byte)
    end
    
    # Stop
    unsafe_store!(ptr_cs, 0)
    DirectSPI.close_driver(drv)

catch e
    println("ERROR: $e")
    if isa(e, SystemError); println("Run with sudo."); end
end
