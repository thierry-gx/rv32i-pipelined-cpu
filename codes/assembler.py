import re

REGISTERS = {
    'zero': 0, 'x0': 0, 'ra': 1, 'x1': 1, 'sp': 2, 'x2': 2, 'gp': 3, 'x3': 3,
    'tp': 4, 'x4': 4, 't0': 5, 'x5': 5, 't1': 6, 'x6': 6, 't2': 7, 'x7': 7,
    's0': 8, 'x8': 8, 'fp': 8, 's1': 9, 'x9': 9, 'a0': 10, 'x10': 10,
    'a1': 11, 'x11': 11, 'a2': 12, 'x12': 12, 'a3': 13, 'x13': 13,
    'a4': 14, 'x14': 14, 'a5': 15, 'x15': 15, 'a6': 16, 'x16': 16,
    'a7': 17, 'x17': 17, 's2': 18, 'x18': 18, 's3': 19, 'x19': 19,
    's4': 20, 'x20': 20, 's5': 21, 'x21': 21, 's6': 22, 'x22': 22,
    's7': 23, 'x23': 23, 's8': 24, 'x24': 24, 's9': 25, 'x25': 25,
    's10': 26, 'x26': 26, 's11': 27, 'x27': 27, 't3': 28, 'x28': 28,
    't4': 29, 'x29': 29, 't5': 30, 'x30': 30, 't6': 31, 'x31': 31,
}

INSTRUCTIONS = {
    'lui': {'type': 'U', 'opcode': '0110111'}, 'auipc': {'type': 'U', 'opcode': '0010111'},
    'jal': {'type': 'J', 'opcode': '1101111'},
    'jalr': {'type': 'I', 'opcode': '1100111', 'funct3': '000'},
    'lb': {'type': 'I', 'opcode': '0000011', 'funct3': '000'}, 'lh': {'type': 'I', 'opcode': '0000011', 'funct3': '001'},
    'lw': {'type': 'I', 'opcode': '0000011', 'funct3': '010'}, 'lbu': {'type': 'I', 'opcode': '0000011', 'funct3': '100'},
    'lhu': {'type': 'I', 'opcode': '0000011', 'funct3': '101'},
    'addi': {'type': 'I', 'opcode': '0010011', 'funct3': '000'}, 'slti': {'type': 'I', 'opcode': '0010011', 'funct3': '010'},
    'sltiu': {'type': 'I', 'opcode': '0010011', 'funct3': '011'}, 'xori': {'type': 'I', 'opcode': '0010011', 'funct3': '100'},
    'ori': {'type': 'I', 'opcode': '0010011', 'funct3': '110'}, 'andi': {'type': 'I', 'opcode': '0010011', 'funct3': '111'},
    'slli': {'type': 'I-shift', 'opcode': '0010011', 'funct3': '001', 'funct7': '0000000'},
    'srli': {'type': 'I-shift', 'opcode': '0010011', 'funct3': '101', 'funct7': '0000000'},
    'srai': {'type': 'I-shift', 'opcode': '0010011', 'funct3': '101', 'funct7': '0100000'},
    'fence.i': {'type': 'I-special', 'opcode': '0001111', 'funct3': '001'},
    'sb': {'type': 'S', 'opcode': '0100011', 'funct3': '000'}, 'sh': {'type': 'S', 'opcode': '0100011', 'funct3': '001'},
    'sw': {'type': 'S', 'opcode': '0100011', 'funct3': '010'},
    'beq': {'type': 'B', 'opcode': '1100011', 'funct3': '000'}, 'bne': {'type': 'B', 'opcode': '1100011', 'funct3': '001'},
    'blt': {'type': 'B', 'opcode': '1100011', 'funct3': '100'}, 'bge': {'type': 'B', 'opcode': '1100011', 'funct3': '101'},
    'bltu': {'type': 'B', 'opcode': '1100011', 'funct3': '110'}, 'bgeu': {'type': 'B', 'opcode': '1100011', 'funct3': '111'},
    'add': {'type': 'R', 'opcode': '0110011', 'funct3': '000', 'funct7': '0000000'},
    'sub': {'type': 'R', 'opcode': '0110011', 'funct3': '000', 'funct7': '0100000'},
    'sll': {'type': 'R', 'opcode': '0110011', 'funct3': '001', 'funct7': '0000000'},
    'slt': {'type': 'R', 'opcode': '0110011', 'funct3': '010', 'funct7': '0000000'},
    'sltu': {'type': 'R', 'opcode': '0110011', 'funct3': '011', 'funct7': '0000000'},
    'xor': {'type': 'R', 'opcode': '0110011', 'funct3': '100', 'funct7': '0000000'},
    'srl': {'type': 'R', 'opcode': '0110011', 'funct3': '101', 'funct7': '0000000'},
    'sra': {'type': 'R', 'opcode': '0110011', 'funct3': '101', 'funct7': '0100000'},
    'or': {'type': 'R', 'opcode': '0110011', 'funct3': '110', 'funct7': '0000000'},
    'and': {'type': 'R', 'opcode': '0110011', 'funct3': '111', 'funct7': '0000000'},
}

def to_binary(n, bits):
    if n >= 0:
        return format(n, f'0{bits}b')
    else:
        return format((1 << bits) + n, f'0{bits}b')

def get_register_number(reg_str):
    reg_str = reg_str.lower().strip()
    if reg_str not in REGISTERS:
        raise ValueError(f"Invalid register: '{reg_str}'")
    return REGISTERS[reg_str]

def resolve_immediate(operand, symbol_table, current_address):
    operand = operand.strip()
    try:
        return int(operand, 0)
    except ValueError:
        if operand in symbol_table:
            target_address = symbol_table[operand]
            return target_address - current_address
        else:
            raise ValueError(f"Undefined label: '{operand}'")

def assemble_r_type(instr_info, operands):
    rd = to_binary(get_register_number(operands[0]), 5)
    rs1 = to_binary(get_register_number(operands[1]), 5)
    rs2 = to_binary(get_register_number(operands[2]), 5)
    funct7, funct3, opcode = instr_info['funct7'], instr_info['funct3'], instr_info['opcode']
    return funct7 + rs2 + rs1 + funct3 + rd + opcode

def assemble_i_type(instr_info, operands):
    rd = to_binary(get_register_number(operands[0]), 5)
    rs1 = to_binary(get_register_number(operands[1]), 5)
    imm = to_binary(int(operands[2], 0), 12)
    funct3, opcode = instr_info['funct3'], instr_info['opcode']
    return imm + rs1 + funct3 + rd + opcode

def assemble_i_load_type(instr_info, operands):
    rd = to_binary(get_register_number(operands[0]), 5)
    mem_access = operands[1]
    match = re.match(r'(-?\w+)\s*\((.+)\)', mem_access)
    if not match:
        raise ValueError(f"Invalid memory operand format: '{mem_access}'")
    imm_val = int(match.group(1), 0)
    rs1_str = match.group(2)
    rs1 = to_binary(get_register_number(rs1_str), 5)
    imm = to_binary(imm_val, 12)
    funct3, opcode = instr_info['funct3'], instr_info['opcode']
    return imm + rs1 + funct3 + rd + opcode

def assemble_i_shift_type(instr_info, operands):
    rd = to_binary(get_register_number(operands[0]), 5)
    rs1 = to_binary(get_register_number(operands[1]), 5)
    shamt = to_binary(int(operands[2], 0), 5)
    funct7, funct3, opcode = instr_info['funct7'], instr_info['funct3'], instr_info['opcode']
    return funct7 + shamt + rs1 + funct3 + rd + opcode

def assemble_s_type(instr_info, operands):
    rs2 = to_binary(get_register_number(operands[0]), 5)
    mem_access = operands[1]
    match = re.match(r'(-?\w+)\s*\((.+)\)', mem_access)
    if not match:
        raise ValueError(f"Invalid memory operand format: '{mem_access}'")
    imm_val = int(match.group(1), 0)
    rs1_str = match.group(2)
    rs1 = to_binary(get_register_number(rs1_str), 5)
    imm = to_binary(imm_val, 12)
    imm_11_5, imm_4_0 = imm[0:7], imm[7:12]
    funct3, opcode = instr_info['funct3'], instr_info['opcode']
    return imm_11_5 + rs2 + rs1 + funct3 + imm_4_0 + opcode

def assemble_b_type(instr_info, operands, symbol_table, current_address):
    rs1 = to_binary(get_register_number(operands[0]), 5)
    rs2 = to_binary(get_register_number(operands[1]), 5)
    offset = resolve_immediate(operands[2], symbol_table, current_address)
    imm = to_binary(offset, 13)
    imm_12, imm_11, imm_10_5, imm_4_1 = imm[0], imm[1], imm[2:8], imm[8:12]
    funct3, opcode = instr_info['funct3'], instr_info['opcode']
    return imm_12 + imm_10_5 + rs2 + rs1 + funct3 + imm_4_1 + imm_11 + opcode

def assemble_u_type(instr_info, operands):
    rd = to_binary(get_register_number(operands[0]), 5)
    imm = to_binary(int(operands[1], 0), 20)
    opcode = instr_info['opcode']
    return imm + rd + opcode

def assemble_j_type(instr_info, operands, symbol_table, current_address):
    rd = to_binary(get_register_number(operands[0]), 5)
    offset = resolve_immediate(operands[1], symbol_table, current_address)
    imm = to_binary(offset, 21)
    imm_20, imm_19_12, imm_11, imm_10_1 = imm[0], imm[1:9], imm[9], imm[10:20]
    opcode = instr_info['opcode']
    return imm_20 + imm_10_1 + imm_11 + imm_19_12 + rd + opcode

def assemble_i_special_type(instr_info, mnemonic):
    if mnemonic == 'fence.i':
        imm = to_binary(0, 12)
        rs1 = to_binary(0, 5)
        rd = to_binary(0, 5)
        funct3, opcode = instr_info['funct3'], instr_info['opcode']
        return imm + rs1 + funct3 + rd + opcode
    return ""

def convert_instruction(line, symbol_table, current_address):
    line = line.split('#')[0].strip()
    if ':' in line:
        line = line.split(':', 1)[1].strip()
    if not line:
        return None
    parts = line.split(maxsplit=1)
    mnemonic = parts[0].lower()
    if mnemonic not in INSTRUCTIONS:
        raise ValueError(f"Unrecognized instruction: '{mnemonic}'")
    instr_info = INSTRUCTIONS[mnemonic]
    operands_str = parts[1] if len(parts) > 1 else ""
    operands = [op.strip() for op in operands_str.split(',') if op.strip()]
    instr_type = instr_info['type']
    binary_code = ""
    if instr_type == 'J':
        binary_code = assemble_j_type(instr_info, operands, symbol_table, current_address)
    elif instr_type == 'B':
        binary_code = assemble_b_type(instr_info, operands, symbol_table, current_address)
    elif instr_type == 'R':
        binary_code = assemble_r_type(instr_info, operands)
    elif instr_type == 'I':
        if mnemonic in ['lb', 'lh', 'lw', 'lbu', 'lhu', 'jalr']:
            binary_code = assemble_i_load_type(instr_info, operands)
        else:
            binary_code = assemble_i_type(instr_info, operands)
    elif instr_type == 'I-shift':
        binary_code = assemble_i_shift_type(instr_info, operands)
    elif instr_type == 'I-special':
        binary_code = assemble_i_special_type(instr_info, mnemonic)
    elif instr_type == 'S':
        binary_code = assemble_s_type(instr_info, operands)
    elif instr_type == 'U':
        binary_code = assemble_u_type(instr_info, operands)
    else:
        raise ValueError(f"Unsupported instruction type: {instr_type}")
    return f"{int(binary_code, 2):08x}"

def main():
    input_filename = 'instructions.txt'
    output_filename = 'machinecode.txt'
    base_address = 0x0
    try:
        with open(input_filename, 'r') as infile:
            lines = infile.readlines()
            
        print("Pass 1: Searching for labels...")
        symbol_table = {}
        current_address = base_address
        for line in lines:
            clean_line = line.split('#')[0].strip()
            if not clean_line:
                continue
            if ':' in clean_line:
                label = clean_line.split(':', 1)[0].strip()
                if label:
                    symbol_table[label] = current_address
                    print(f"  - Found label '{label}' at address 0x{current_address:x}")
            
            instruction_part = clean_line.split(':', 1)[-1].strip()
            if instruction_part:
                current_address += 4
        print("Symbol table created.\n")
        
        print("Pass 2: Assembling the code...")
        with open(output_filename, 'w') as outfile:
            current_address = base_address
            for i, line in enumerate(lines):
                original_line = line.strip()
                instruction_part = line.split('#')[0].strip()
                if not instruction_part:
                    continue
                instruction_only = instruction_part.split(':', 1)[-1].strip()
                if not instruction_only:
                    continue
                try:
                    hex_code = convert_instruction(line, symbol_table, current_address)
                    if hex_code:
                        outfile.write(f"{hex_code}\n")
                    current_address += 4
                except ValueError as e:
                    print(f"Error at address 0x{current_address:x} (line ~{i+1}): {e}")
                    print(f"  -> {original_line}")
                    return
                    
        print(f"\nConversion complete. Output saved to '{output_filename}'.")
    except FileNotFoundError:
        print(f"Error: The file '{input_filename}' was not found.")

if __name__ == '__main__':
    main()