CompactFlash Bootloader
For XMICRO-6502/XMICRO-MEMORY

This ROM attempts to find and load a binary file named "AUTOEXEC.BIN" from a
FAT16-formatted CompactFlash card. If an error occurs, an error code will be
displayed on an XMICRO-7SEG card if present and the CPU will be halted.

AUTOEXEC.BIN is loaded into RAM starting at $04000 and has a maximum filesize
of $B000. Once the file is successfully loaded, the CPU jumps to $4000 and
executes it. Although this ROM does some initialization, the system should be
considered uninitialized at the beginning of execution.


Error Codes
-----------------------------------
$01:	CF card not inserted
$02:	CF timeout
$10:	FAT16 filesystem not found
$11:	File not found
$12:	Oversize file (reading)
$13:	Invalid Cluster
