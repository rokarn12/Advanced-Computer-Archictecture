# Reorder Buffer - 2-Wide Superscalar Out-of-Order Execution

**Course:** ECSE 4780: Advanced Computer Architecture  
**Author:** Rojan Karn  
**Project:** Project 3 - Reorder Buffer

## Overview

This project implements a 2-wide superscalar out-of-order execution processor using a reorder buffer. Building upon Project 2's Register Alias Table implementation of Tomasulo's algorithm, this project adds an "in-order commit" stage to handle exceptions such as branch mispredictions.

## Architecture

The system architecture consists of the following key components:

![Block-level diagram with direction of signals between blocks]

> **Note:** The "Reg File" block encapsulates the Architectural Register File and the mapping table

## System Components

### Instruction Queue

A synchronous FIFO buffer that:
- Holds 16 RISC-V instructions (32 bits each)
- Features two output ports for dual dispatch
- Sends the first two instructions to dispatch units on `read_enable` signal

**Inputs:** Instructions from top-level/testbench modules  
**Outputs:** Two instructions to dispatch units

### Dispatch Unit

Manages instruction dispatch and register renaming.

**Inputs:**
- Instruction from instruction queue
- Available spots from reservation stations
- Next available reorder buffer entry
- Instruction information from the other dispatch unit

**Outputs:**
- `read_enable` signal to instruction queue
- Instruction information to the other dispatch unit
- Renaming and instruction information to register file

**Key Features:**
- Extracts `rd`, `rs1`, `rs2`, and instruction type (ADD, MUL, BEQ)
- Supports NOP instructions for stalling
- Renames destination registers based on ROB entry (not reservation station entry as in Project 2)
- Stalls both dispatch units if insufficient reservation station space

### Register File

Combines the architectural register file with a mapping table for register renaming.

**Components:**
- **Register File:** 8 entries containing register ID (R1-R7) and values
- **Mapping Table:** 8 entries with register ID, ROB tag, and valid bit

**Functionality:**
- Updates mapping table when dispatch units send `ready` signal
- Routes instructions to appropriate reservation stations
- Sends instruction information to reorder buffer
- Listens on common data bus for ROB updates
- Invalidates translations when data becomes available

**Initial State:** Register Rx contains value 10x (e.g., R1=10, R2=20, R3=30, ..., R7=70)

### Reservation Stations

Separate reservation stations for ADD and MUL operations.

**Structure:**
- Implemented as shown in lecture slides
- Each entry contains: Op, Vj, Vk, Qj, Qk, Dest
- Tracks available spots for dispatch units

**Inputs:**
- Instruction information from register file (1 or 2 instructions)
- `load_one` or `load_two` signals

**Outputs:**
- Operands and destination tag to functional units
- Available spots list to dispatch units

**Execution Logic:**
- Issues ready instructions to functional units
- Listens on ROB bus for source operand updates

### Functional Units

#### ADD Functional Unit
- **Latency:** 4 clock cycles (modeled with mod-4 counter)

#### MUL Functional Unit
- **Latency:** 6 clock cycles (modeled with mod-6 counter)

**Common I/O:**
- **Inputs:** Two operands, ROB tag
- **Outputs:** `ready` signal, result value, ROB tag

#### Branch Functional Unit

Handles branch-if-equal (BEQ) instructions with "not taken" prediction.

**Functionality:**
- Compares two operands
- Signals ROB on misprediction
- Sets exception bit for mispredicted branches

### Reorder Buffer (ROB)

The core module implementing in-order commit.

**Structure:**
- Head pointer: Next to commit
- Tail pointer: Next available entry
- Each entry contains: Instruction, Destination, Value, Source1, Source2, Exception bit

**Inputs:**
- New instruction information from register file
- Results from ADD, MUL, and BRANCH functional units

**Outputs:**
- Common data bus broadcasts (tag and value)

**Commit Logic:**

An instruction at the head pointer commits when all conditions are met:
- Source 1 valid
- Source 2 valid
- No exception
- Value > 0

Upon commit:
1. Broadcast ROB tag and value on common data bus
2. Clear the entry
3. Increment head pointer

**Exception Handling:**

On branch misprediction:
1. Clear all entries between head and tail pointers
2. Restore register-to-tag mappings in register file
3. Clear reservation station entries with tags > misprediction tag

## Testing

### Basic Functionality Tests

**Test Cases:**

| Instruction | Operation | Destination | Source 1 | Source 2 |
|-------------|-----------|-------------|----------|----------|
| 1 | MUL | R3 | R2 | R1 |
| 2 | ADD | R5 | R6 | R4 |
| 3 | ADD | R7 | R2 | R6 |
| 4 | ADD | R4 | R1 | R2 |

**Expected Results:**
- R3 = 20 × 10 = 200
- R5 = 60 + 40 = 100
- R7 = 20 + 60 = 80
- R4 = 10 + 20 = 30

**Verification:** ✅ All destination registers contain correct values

![Register File values at test completion]

![Annotated ROB waveforms]

### Branch Misprediction Exception Tests

**Modified Test Cases:**

R6 modified to 20 to trigger exception at instruction 3.

| Instruction | Operation | Destination | Source 1 | Source 2 |
|-------------|-----------|-------------|----------|----------|
| 1 | MUL | R3 | R2 | R1 |
| 2 | BEQ | R7 | R6 | R4 |
| 3 | ADD | R4 | R1 | R2 |
| 4 | ADD | R5 | R2 | R4 |

**Expected Results (with exception):**
- R3 = 20 × 10 = 200 ✅
- R5 = 20 + 40 = 60 ✅
- R7 = 70 (misprediction, no update) ✅
- R4 = 40 (instruction flushed) ✅

**Verification:** ✅ Branch misprediction handling works correctly
- Instructions following misprediction are flushed
- Register mappings are restored
- Reservation stations cleared appropriately

![Exception handling test results]

## Key Differences from Project 2

1. **Register Renaming:** Destination registers renamed based on ROB entry (not reservation station entry)
2. **In-Order Commit:** Added ROB for proper program semantics
3. **Exception Handling:** Support for branch misprediction recovery
4. **Branch Support:** New branch functional unit for BEQ instructions

## Conclusion

This project successfully implements a 2-wide superscalar reorder buffer system with:
- Out-of-order execution
- In-order commit
- Proper exception handling for branch mispredictions
- Full RISC-V instruction support (ADD, MUL, BEQ, NOP)

Testing demonstrates correct functionality across various scenarios including normal operation and exception conditions.

---

*Special thanks to Dr. Liu Liu for the knowledge gained in Computer Hardware Systems and Advanced Computer Architecture.*
