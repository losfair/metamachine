# metamachine

An experimental CPU with support for software-defined instruction set.

Instructions from memory are decoded using a microcode-like "meta-program" that is loaded into an array of hardware
registers by the software. The meta-program, which implements most of the decoding logic, then translates the incoming
instructions into a form of VLIW instructions, and feeds that into later stages in the pipeline.

In theory, the hardware only needs to provide a minimal set of instructions in the VLIW low-level instruction set,
including basic arithmetic, register and memory operations, and a large enough set of general-purpose registers. More
complex stuff like architectural register mappings, privilege levels and virtual memory can be implemented in the decoder meta-program.

Ideally, this design would enable low-overhead implementation of different instruction sets like RISC-V, MIPS, ARM, and even WebAssembly entirely in software and on a same piece of hardware.

This is a work in progress.
