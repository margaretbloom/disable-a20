# disable-a20
Can A20 line be disabled nowadays?

It seems No, at least in my Skylake platform.

The a20.asm file is a legacy (BIOS) bootloader that check the A20 line status and try to disable it if enabled. It first attempt to use the BIOS, if unavailable or returning an error, the usual manual disabling is done (with all the known methods: KBC, FASTA20 and port 0eeh).  
After being disabled the A20 line is tested **again** to see if it worked, in case it didn't and the disabling code used only the BIOS a manual disabling is done and the A20 is tested again.  

The output printed on screen is intuitive but source code looking may be necessary.  

The a20 file is the assembled binary file, ready to be copied on the MBR.

The a20.bxrc is the Bochs configuration file.
