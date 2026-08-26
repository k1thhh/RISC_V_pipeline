# fibonacci.s — compute first 10 Fibonacci numbers, store at address 0x1000
# x10 = counter  x11 = fib(n-2)  x12 = fib(n-1)  x13 = temp  x14 = base  x15 = ptr

    addi x10, x0, 10
    addi x11, x0, 0
    addi x12, x0, 1
    addi x14, x0, 256          # base = 0x100 (word 64, within 512-word data mem)
    sw   x11, 0(x14)
    sw   x12, 4(x14)
    addi x15, x14, 8
    addi x10, x10, -2
loop:
    beq  x10, x0, done
    add  x13, x11, x12
    sw   x13, 0(x15)
    addi x15, x15, 4
    addi x10, x10, -1
    add  x11, x12, x0
    add  x12, x13, x0
    jal  x0, loop
done:
    nop
    nop
    nop
    halt
