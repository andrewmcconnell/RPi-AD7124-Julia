# =========================================================
# FILE: test/interactive_console.jl
# USAGE: sudo ~/.juliaup/bin/julia -i test/interactive_console.jl
# =========================================================

project_root = dirname(@__DIR__)

# Load the FIXED Debug Driver
include(joinpath(project_root, "src", "BareMetalDebug.jl"))
include(joinpath(project_root, "src", "AD7124Registers.jl"))

using .BareMetalDebug
using .AD7124Registers

println("🔌 Initializing SPI Hardware (BareMetalDebug)...")
const spi = BareMetalDebug.init()

# =========================================================
# CONSOLE COMMANDS
# =========================================================

function read_reg(addr::Integer)
    reg_addr = UInt8(addr)
    try
        info = AD7124Registers.get_info(reg_addr)
        raw_val = BareMetalDebug.read_register_variable(spi, reg_addr, info.size)
        AD7124Registers.decode(reg_addr, raw_val)
        return raw_val
    catch e
        println("❌ Error reading register: $e")
    end
end

function write_reg(addr::Integer, val::Integer)
    reg_addr = UInt8(addr)
    try
        info = AD7124Registers.get_info(reg_addr)
        println("📝 Writing 0x$(string(val, base=16)) to $(info.name)...")
        BareMetalDebug.write_register(spi, reg_addr, val, info.size)
        println("✅ Done.")
    catch e
        println("❌ Error writing register: $e")
    end
end

println("\n=== 🎮 AD7124 INTERACTIVE CONSOLE ===")
println("Hardware:  BareMetalDebug (Safe Clone)")
println("\nTry this:  read_reg(0x05)  -> Should see 0x14")