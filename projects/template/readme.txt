Project Template
For XMICRO-6502

This directory contains a project template for XMICRO-6502 software using the CC65 toolchain. The program can be compiled using GNU Make. The makefile itself is from https://github.com/cc65/wiki/wiki/Bigger-Projects and was modified to suit XMICRO-6502 single-target projects. Make requires the CC65 executables to be added to the PATH, or CC65_HOME environment variables.

The output is a binary named AUTOEXEC.BIN which can be loaded via a CompactFlash card with the system's ROM bootloader.

To ensure proper linking, only crt0.s should define the STARTUP segment. Constructors should be used to initialize modules, and should be placed in the ONCE segment. System hardware info (card addresses/vectors) should be imported using linker-generated constants found in xmicro.cfg to centralize configuration.

The following files are included in the src directory:

crt0.s - System initialization and startup code.
xmicro.cfg - XMICRO linker configuration script.
none-debug.lib - The CC65 "none" target library, compiled with full debug info. This file is not necessary, but provides debug info for included modules.
