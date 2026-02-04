# =========================================================
# FILE: test/interactive_console.jl
# USAGE: sudo ~/.juliaup/bin/julia -i test/interactive_console.jl
# (The '-i' flag keeps the Julia REPL open after loading!)
#     THIS WORKS WITH BareMetalDebug and AD7124Registers 
# =========================================================

project_root = dirname(@__DIR__)

# Load the Read-Optimized Debug Driver
include(joinpath(project_root, "src", "BareMetalDebug.jl"))
# Load the Register Definitions
include(joinpath(project_root, "src", "AD7124Registers.jl"))

using .BareMetalDebug
using .AD7124Registers

println("🔌 Initializing SPI Hardware (BareMetalDebug)...")
# Initialize the SPI engine
const spi = BareMetalDebug.init()

# =========================================================
# CONSOLE COMMANDS
# =========================================================

"""
    read_reg(addr)
    
Reads a register from the AD7124 and prints a detailed bit-by-bit breakdown.

Usage:
  read_reg(0x00)  # Check Status
  read_reg(0x01)  # Check Control
  read_reg(0x06)  # Check Errors
"""
function read_reg(addr::Integer)
    reg_addr = UInt8(addr)
    
    # 1. Get Register Info (Size, Name)
    try
        info = AD7124Registers.get_info(reg_addr)
        
        # 2. Read Raw Value from Hardware
        # We use the 'variable' reader from our debug driver
        raw_val = BareMetalDebug.read_register_variable(spi, reg_addr, info.size)
        
        # 3. Decode and Print
        AD7124Registers.decode(reg_addr, raw_val)
        return raw_val
        
    catch e
        println("❌ Error reading register: $e")
    end
end

"""
    write_reg(addr, value)

Writes a new value to an AD7124 register.

Usage:
  write_reg(0x01, 0x0580)   # Enable Full Power Mode
  write_reg(0x09, 0x8001)   # Enable Channel 0
"""
function write_reg(addr::Integer, val::Integer)
    reg_addr = UInt8(addr)
    
    try
        # 1. Get Register Info
        info = AD7124Registers.get_info(reg_addr)
        
        println("📝 Writing 0x$(string(val, base=16)) to $(info.name)...")
        
        # 2. Perform SPI Transfer (Manual Write Implementation)
        # We access the raw pointers from the spi handle because 
        # BareMetalDebug was originally designed just for reading.
        
        # A. Assert Chip Select (CS)
        unsafe_store!(spi.ptr_cs, UInt32(BareMetalDebug.CS_CLEAR_RX | BareMetalDebug.CS_CLEAR_TX))
        unsafe_store!(spi.ptr_cs, UInt32(BareMetalDebug.CS_TA | BareMetalDebug.CS_CS_0))
        
        # B. Write Command Byte (Write Operation = 0x00 | Address)
        cmd = 0x00 | (reg_addr & 0x3F)
        unsafe_store!(spi.ptr_fifo, UInt32(cmd))
        
        # C. Write Data Bytes (Big Endian)
        # We shift the value to extract bytes from MSB to LSB
        for i in (info.size - 1):-1:0
            byte = (val >> (i * 8)) & 0xFF
            unsafe_store!(spi.ptr_fifo, UInt32(byte))
        end
        
        # D. Wait for DONE bit
        while (BareMetalDebug.volatile_load(spi.ptr_cs) & BareMetalDebug.CS_DONE) == 0
            # Spin wait
        end
        
        # E. Clear Chip Select
        unsafe_store!(spi.ptr_cs, 0)
        
        println("✅ Write Complete.")
        
        # Optional: Auto-verify by reading back?
        # read_reg(reg_addr) 
        
    catch e
        println("❌ Error writing register: $e")
    end
end

"""
    scan_channels()

Quickly checks all 16 channels to see which are enabled.
"""
function scan_channels()
    println("\n🔎 Scanning Channels 0-15...")
    for i in 0:15
        reg = 0x09 + i
        val = BareMetalDebug.read_register_variable(spi, UInt8(reg), 2)
        enabled = (val & 0x8000) != 0
        if enabled
            setup = (val >> 12) & 0x07
            ainp = (val >> 5) & 0x1F
            ainm = val & 0x1F
            println("   ✅ Ch $i: ENABLED (Setup $setup, AIN$ainp / AIN$ainm)")
        end
    end
    println("   (All other channels disabled)")
end

# =========================================================
# STARTUP MESSAGE
# =========================================================
println("\n=== 🎮 AD7124 INTERACTIVE CONSOLE ===")
println("Hardware:  BareMetalDebug (SPI0)")
println("Registers: Loaded from AD7124Registers.jl")
println("\nAvailable Commands:")
println("  read_reg(0xXX)      -> Read and decode a register")
println("  write_reg(0xXX, Y)  -> Write value Y to register 0xXX")
println("  scan_channels()     -> List all enabled channels")
println("\nTry this first:  read_reg(0x00)  # Check Status")