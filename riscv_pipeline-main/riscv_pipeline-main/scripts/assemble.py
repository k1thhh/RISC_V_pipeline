#!/usr/bin/env python3
"""Minimal RV32I assembler: .s -> .hex (one 32-bit word per line, hex, for $readmemh)"""

import sys
import re
import argparse

REGS = {f'x{i}': i for i in range(32)}
REGS.update({'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,
             't0':5,'t1':6,'t2':7,'s0':8,'fp':8,'s1':9,
             'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,'a6':16,'a7':17,
             's2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,'s8':24,'s9':25,'s10':26,'s11':27,
             't3':28,'t4':29,'t5':30,'t6':31})

def reg(s):
    s = s.strip().rstrip(',')
    if s not in REGS:
        raise ValueError(f"Unknown register: {s!r}")
    return REGS[s]

def imm(s, bits=12):
    s = s.strip().rstrip(',')
    v = int(s, 0)
    lo = -(1 << (bits-1))
    hi = (1 << (bits-1)) - 1
    if v < lo or v > hi:
        raise ValueError(f"Immediate {v} out of range [{lo},{hi}]")
    return v & ((1 << bits) - 1)

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12 | (rd & 0x1F) << 7 | (opcode & 0x7F))

def i_type(imm12, rs1, funct3, rd, opcode):
    return ((imm12 & 0xFFF) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12 | (rd & 0x1F) << 7 | (opcode & 0x7F))

def s_type(imm12, rs2, rs1, funct3, opcode):
    hi = (imm12 >> 5) & 0x7F
    lo = imm12 & 0x1F
    return (hi << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12 | lo << 7 | (opcode & 0x7F))

def b_type(offset, rs2, rs1, funct3, opcode):
    o = offset & 0x1FFF  # 13 bits
    b12 = (o >> 12) & 1
    b11 = (o >> 11) & 1
    b10_5 = (o >> 5) & 0x3F
    b4_1 = (o >> 1) & 0xF
    return (b12 << 31 | b10_5 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12 | b4_1 << 8 | b11 << 7 | (opcode & 0x7F))

def u_type(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12 | (rd & 0x1F) << 7 | (opcode & 0x7F))

def j_type(offset, rd, opcode):
    o = offset & 0x1FFFFF  # 21 bits
    b20 = (o >> 20) & 1
    b19_12 = (o >> 12) & 0xFF
    b11 = (o >> 11) & 1
    b10_1 = (o >> 1) & 0x3FF
    return (b20 << 31 | b10_1 << 21 | b11 << 20 | b19_12 << 12 |
            (rd & 0x1F) << 7 | (opcode & 0x7F))

def parse_mem(s):
    """Parse 'offset(reg)' format."""
    m = re.match(r'(-?\w+)\((\w+)\)', s.strip())
    if not m:
        raise ValueError(f"Bad memory operand: {s!r}")
    return int(m.group(1), 0), REGS[m.group(2)]

def assemble(lines):
    # First pass: collect labels
    labels = {}
    pc = 0
    clean = []
    for raw in lines:
        line = re.sub(r'#.*', '', raw).strip()
        if not line:
            continue
        if line.endswith(':'):
            labels[line[:-1]] = pc
        elif ':' in line and not line.startswith('.'):
            lbl, rest = line.split(':', 1)
            labels[lbl.strip()] = pc
            line = rest.strip()
            if line:
                clean.append((pc, line))
                pc += 4
        else:
            clean.append((pc, line))
            pc += 4

    # Second pass: encode
    words = []
    for pc, line in clean:
        parts = re.split(r'[\s,]+', line)
        parts = [p for p in parts if p]
        op = parts[0].lower()
        w = encode(op, parts[1:], pc, labels)
        words.append(w)
    return words

def sext(v, bits):
    """Sign-extend v from bits-wide."""
    sign = 1 << (bits - 1)
    return (v & (sign - 1)) - (v & sign)

def encode(op, args, pc, labels):
    def lbl_off(s, pc, bits):
        v = labels[s] - pc if s in labels else int(s, 0)
        return v & ((1 << bits) - 1)

    # R-type
    if op == 'add':   return r_type(0,reg(args[2]),reg(args[1]),0,reg(args[0]),0x33)
    if op == 'sub':   return r_type(0x20,reg(args[2]),reg(args[1]),0,reg(args[0]),0x33)
    if op == 'sll':   return r_type(0,reg(args[2]),reg(args[1]),1,reg(args[0]),0x33)
    if op == 'slt':   return r_type(0,reg(args[2]),reg(args[1]),2,reg(args[0]),0x33)
    if op == 'sltu':  return r_type(0,reg(args[2]),reg(args[1]),3,reg(args[0]),0x33)
    if op == 'xor':   return r_type(0,reg(args[2]),reg(args[1]),4,reg(args[0]),0x33)
    if op == 'srl':   return r_type(0,reg(args[2]),reg(args[1]),5,reg(args[0]),0x33)
    if op == 'sra':   return r_type(0x20,reg(args[2]),reg(args[1]),5,reg(args[0]),0x33)
    if op == 'or':    return r_type(0,reg(args[2]),reg(args[1]),6,reg(args[0]),0x33)
    if op == 'and':   return r_type(0,reg(args[2]),reg(args[1]),7,reg(args[0]),0x33)

    # I-type arithmetic
    if op == 'addi':  return i_type(sext(int(args[2].strip(','), 0),12)&0xFFF,reg(args[1]),0,reg(args[0]),0x13)
    if op == 'slti':  return i_type(sext(int(args[2].strip(','), 0),12)&0xFFF,reg(args[1]),2,reg(args[0]),0x13)
    if op == 'sltiu': return i_type(int(args[2].strip(','),0)&0xFFF,reg(args[1]),3,reg(args[0]),0x13)
    if op == 'xori':  return i_type(sext(int(args[2].strip(','), 0),12)&0xFFF,reg(args[1]),4,reg(args[0]),0x13)
    if op == 'ori':   return i_type(sext(int(args[2].strip(','), 0),12)&0xFFF,reg(args[1]),6,reg(args[0]),0x13)
    if op == 'andi':  return i_type(sext(int(args[2].strip(','), 0),12)&0xFFF,reg(args[1]),7,reg(args[0]),0x13)
    if op == 'slli':  return i_type(int(args[2].strip(','),0)&0x1F,reg(args[1]),1,reg(args[0]),0x13)
    if op == 'srli':  return i_type(int(args[2].strip(','),0)&0x1F,reg(args[1]),5,reg(args[0]),0x13)
    if op == 'srai':  return i_type((0x20<<5)|(int(args[2].strip(','),0)&0x1F),reg(args[1]),5,reg(args[0]),0x13)

    # Loads
    if op == 'lb':  off,rs = parse_mem(args[1]); return i_type(off&0xFFF,rs,0,reg(args[0]),0x03)
    if op == 'lh':  off,rs = parse_mem(args[1]); return i_type(off&0xFFF,rs,1,reg(args[0]),0x03)
    if op == 'lw':  off,rs = parse_mem(args[1]); return i_type(off&0xFFF,rs,2,reg(args[0]),0x03)
    if op == 'lbu': off,rs = parse_mem(args[1]); return i_type(off&0xFFF,rs,4,reg(args[0]),0x03)
    if op == 'lhu': off,rs = parse_mem(args[1]); return i_type(off&0xFFF,rs,5,reg(args[0]),0x03)

    # Stores
    if op == 'sb': off,rs1 = parse_mem(args[1]); return s_type(off&0xFFF,reg(args[0]),rs1,0,0x23)
    if op == 'sh': off,rs1 = parse_mem(args[1]); return s_type(off&0xFFF,reg(args[0]),rs1,1,0x23)
    if op == 'sw': off,rs1 = parse_mem(args[1]); return s_type(off&0xFFF,reg(args[0]),rs1,2,0x23)

    # Branches
    if op == 'beq':  return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),0,0x63)
    if op == 'bne':  return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),1,0x63)
    if op == 'blt':  return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),4,0x63)
    if op == 'bge':  return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),5,0x63)
    if op == 'bltu': return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),6,0x63)
    if op == 'bgeu': return b_type(lbl_off(args[2].strip(','),pc,13),reg(args[1]),reg(args[0]),7,0x63)

    # U-type
    if op == 'lui':   return u_type(int(args[1].strip(','),0),reg(args[0]),0x37)
    if op == 'auipc': return u_type(int(args[1].strip(','),0),reg(args[0]),0x17)

    # J-type
    if op == 'jal':
        if len(args) == 2:
            rd_r = reg(args[0])
            off = lbl_off(args[1].strip(','), pc, 21)
        else:
            rd_r = reg(args[0])
            off = lbl_off(args[1].strip(','), pc, 21)
        return j_type(off, rd_r, 0x6F)

    # JALR
    if op == 'jalr':
        if '(' in args[1]:
            off, rs = parse_mem(args[1])
            return i_type(off&0xFFF, rs, 0, reg(args[0]), 0x67)
        else:
            return i_type(sext(int(args[2].strip(','),0),12)&0xFFF,reg(args[1]),0,reg(args[0]),0x67)

    # Pseudo-instructions
    if op == 'nop':   return 0x00000013
    if op == 'halt':  return 0xFFFFFFFF
    if op == 'mv':    return i_type(0, reg(args[1]), 0, reg(args[0]), 0x13)
    if op == 'li':
        v = int(args[1].strip(','), 0)
        if -2048 <= v <= 2047:
            return i_type(v & 0xFFF, 0, 0, reg(args[0]), 0x13)
        raise ValueError(f"li with large immediate not supported: {v}")
    if op == 'j':     return j_type(lbl_off(args[0].strip(','), pc, 21), 0, 0x6F)
    if op == 'ret':   return i_type(0, 1, 0, 0, 0x67)

    # System
    if op == 'ecall':  return 0x00000073
    if op == 'ebreak': return 0x00100073

    raise ValueError(f"Unknown instruction: {op!r}")


def main():
    ap = argparse.ArgumentParser(description="RV32I assembler")
    ap.add_argument("input", help="Assembly source file (.s)")
    ap.add_argument("-o", "--output", help="Output hex file", required=True)
    args = ap.parse_args()

    with open(args.input) as f:
        lines = f.readlines()

    words = assemble(lines)

    with open(args.output, 'w') as f:
        for w in words:
            f.write(f"{w:08X}\n")

    print(f"Assembled {len(words)} instructions -> {args.output}")

if __name__ == "__main__":
    main()
