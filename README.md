# RV32I 5-Stage Pipelined CPU

SystemVerilog implementation of a 32-bit RISC-V processor (RV32I base integer instruction set) featuring a classic 5-stage pipeline. 

This project was developed as part of the Digital Electronics course at Tongji University (Shanghai, China) during a Double Degree exchange program.

## Architecture Overview
The core follows a standard 5-stage pipeline design: Instruction Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Write-Back (WB). 

Key hardware features include:
* **Hazard Unit:** Fully handles data hazards (via EX-to-EX and MEM-to-EX forwarding paths) and control hazards (branch flushing and load-use stalls).
* **Control Flow:** Branch evaluation and target calculation are centralized in the EX stage to streamline flush logic.
* **Memory Subsystem:** Harvard architecture with byte-enabled write logic for partial memory updates (`sb`, `sh`).

## Supported Instructions
The CPU implements a comprehensive subset of the RV32I standard:
* **Arithmetic/Logical:** `add`, `addi`, `sub`, `and`, `andi`, `slt`, `slti`, `sll`, `slli`
* **Control Flow:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
* **Memory:** `lw`, `lh`, `lbu`, `sw`, `sh`, `sb`

## Repository Structure
* `src/`: SystemVerilog source files (top-level module, ALU, hazard unit, decoders, memories).
* `tb/`: SystemVerilog testbenches for simulation.
* `tools/`: A custom Python assembler (`assembler.py`) written to convert RISC-V assembly into hex machine code for the instruction memory.
* `docs/`: Contains the detailed project report with block diagrams and waveform analysis.

## Verification & Simulation
The processor was verified using a custom test suite triggering specific hazard scenarios. 

To run a simulation:
1. Write the target RISC-V assembly code in `instructions.txt`.
2. Run the Python assembler to generate the machine code: `python tools/assembler.py` (outputs `machinecode.txt`).
3. Run the SystemVerilog testbench (`testbench.sv`) using your preferred HDL simulator.
4. Open the generated `.vcd` dump file using **GTKWave** to inspect pipeline registers, control signals, and hazard resolutions.
