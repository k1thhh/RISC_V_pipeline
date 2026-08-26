# comprehensive_test.s
# Tests RV32I instructions, hazards (load-use, control), and forwarding (EX-EX, MEM-EX)

.text
.globl _start

_start:
    # -----------------------------------------------------------------
    # 1. Forwarding & Basic ALU Tests (R-type, I-type)
    # -----------------------------------------------------------------
    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 20      # x2 = 20
    
    # EX-EX Forwarding: x3 depends on x2 right after it's produced
    # x2 is forwarded from the EX/MEM pipeline register back to the ALU
    add  x3, x1, x2      # x3 = 30
    
    # MEM-EX Forwarding: x4 depends on x3, but there's a 1-cycle gap
    # x3 is in the MEM/WB pipeline register when this ADD executes
    sub  x4, x3, x1      # x4 = 20
    
    # R-type operations
    and  x5, x1, x2      # x5 = 10 & 20 = 0
    or   x6, x1, x2      # x6 = 10 | 20 = 30
    xor  x7, x1, x2      # x7 = 10 ^ 20 = 30
    
    # Logical shifts
    addi x20, x0, 2      # x20 = 2
    sll  x8, x1, x20     # x8 = 10 << 2 = 40
    
    # Set Less Than
    slt  x9, x1, x2      # x9 = (10 < 20) ? 1 : 0 = 1
    
    # U-type operations
    lui   x10, 0x12345   # x10 = 0x12345000
    auipc x11, 0x1       # x11 = PC + 0x1000

    # -----------------------------------------------------------------
    # 2. Load-Use Hazard & Memory Operations
    # -----------------------------------------------------------------
    # Store x3 (30) to memory
    addi x12, x0, 0x100  # Base address = 256
    sw   x3, 0(x12)      # Mem[0x100] = 30
    
    # Load-use hazard: lw followed immediately by an instruction using the result.
    # The hazard_unit should detect this and stall the pipeline for 1 cycle.
    lw   x13, 0(x12)     # x13 = 30
    add  x14, x13, x1    # x14 = 30 + 10 = 40 

    # -----------------------------------------------------------------
    # 3. Control Hazards (Branches & Jumps)
    # -----------------------------------------------------------------
    beq  x13, x3, branch_taken # 30 == 30, should take branch
    
    # These should be flushed by the branch_unit!
    addi x15, x0, 999 
    addi x15, x0, 999
    
branch_taken:
    addi x15, x0, 1      # x15 = 1 (confirms branch was successfully taken)

    jal  x16, jump_target
    
    # These should be flushed!
    addi x17, x0, 999

jump_target:
    addi x17, x0, 2      # x17 = 2 (confirms JAL was taken, x16 holds return address)

    # -----------------------------------------------------------------
    # 4. End of Program - "Print" Register File
    # -----------------------------------------------------------------
    # By adding 0 to each register and writing it back to itself, we 
    # force the testbench's Write-Back monitor to print the final 
    # values of the registers to the simulation console!
print_regs:
    addi x1, x1, 0
    addi x2, x2, 0
    addi x3, x3, 0
    addi x4, x4, 0
    addi x5, x5, 0
    addi x6, x6, 0
    addi x7, x7, 0
    addi x8, x8, 0
    addi x9, x9, 0
    addi x10, x10, 0
    addi x11, x11, 0
    addi x12, x12, 0
    addi x13, x13, 0
    addi x14, x14, 0
    addi x15, x15, 0
    addi x16, x16, 0
    addi x17, x17, 0

    # Infinite loop to halt program safely
halt:
    beq x0, x0, halt
