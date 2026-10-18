MEMORY {
    mem : ORIGIN = 0x00000000, LENGTH = 0x00002000
}
SECTIONS {
    .text : {
        *(.vectors)
        *(.text)
    } > mem
}

/* -----------------------------------------------------------------------------
   Project:     openCologne-PCIE
   Description: NLnet-sponsored open-source implementation
   Version:     1.0
   Date:        April 2025
   ----------------------------------------------------------------------------- */
