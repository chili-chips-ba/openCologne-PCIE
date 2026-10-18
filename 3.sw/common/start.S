.section .vectors
.global _start
_start:
    li sp, 0x2000    
    call main       
loop:
    j loop           

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
