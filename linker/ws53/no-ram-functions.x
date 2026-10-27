/* Do not silently orphan annotations when the relocation feature is absent. */
SECTIONS {
    .ws53.ramtext.forbidden : {
        *(.ws53.ramtext .ws53.ramtext.* .ws53.ramrodata .ws53.ramrodata.*)
    }
} INSERT AFTER .rodata;
ASSERT(SIZEOF(.ws53.ramtext.forbidden) == 0,
       "WS53 RAM sections require ws53-ram-functions")
