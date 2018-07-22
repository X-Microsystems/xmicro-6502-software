CompactFlash Bootloader for XMICRO-6502 and XMICRO-MEMORY

Finds the first available FAT16 partition on the CF card
Searches for a file named "AUTOEXEC.BIN"
If found, loads that file into memory starting at $4000 and executes it.
