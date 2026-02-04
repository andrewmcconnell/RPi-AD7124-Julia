# =========================================================
# FILE: test/inspect_asm.jl
# USAGE: sudo ~/.juliaup/bin/julia test/inspect_asm.jl
# DESCRIPTION: Inspects the native assembly of src/DirectSPI.jl
# =========================================================

using InteractiveUtils # Needed for @code_native

# 1. Load the REAL source file
# We are in 'test/', so we look up one level to 'src/'
project_root = dirname(@__DIR__) # Gets the parent of the 'test' folder
src_path = joinpath(project_root, "src", "DirectSPI.jl")

if isfile(src_path)
    println("Loading source from: $src_path")
    include(src_path)
else
    # Fallback: maybe running from project root?
    if isfile("src/DirectSPI.jl")
        include("src/DirectSPI.jl")
    else
        error("Could not find src/DirectSPI.jl. Tested path: $src_path")
    end
end

using .DirectSPI

# 2. Main Inspection Routine
try
    println("\n--- INITIALIZING DRIVER (REQUIRES SUDO) ---")
    # We must instantiate the driver because Julia compiles specific versions 
    # of functions based on input types. The constructor requires root.
    drv = DirectSPI.SPIMmapDriver()
    println("Driver instantiated. Compiling assembly...")

    println("\n===============================================================")
    println("              ARM64 ASSEMBLY DUMP: collect_fast_mmap             ")
    println("===============================================================")
    
    # Dump the assembly for the function call
    @code_native DirectSPI.collect_fast_mmap(drv, 1)

    println("\n===============================================================")
    println(" ANALYSIS GUIDE:")
    println(" 1. Look for the inner loop label (e.g., LBB0_2).")
    println(" 2. INSIDE that loop, look for 'ldr' (Load Register).")
    println("    - BAD:  No 'ldr' inside the loop (Compiler optimized it away).")
    println("    - GOOD: You see 'ldr' inside the loop structure.")
    println("===============================================================")

    # Clean up
    DirectSPI.close_driver(drv)

catch e
    if isa(e, SystemError) && startswith(e.prefix, "opening file")
        println("\n❌ PERMISSION DENIED")
        println("   The SPIMmapDriver constructor tries to open /dev/mem.")
        println("   You must run this script with 'sudo'.")
    else
        println("\n❌ ERROR: $e")
        rethrow(e) # Show full stack trace for other errors
    end
end
