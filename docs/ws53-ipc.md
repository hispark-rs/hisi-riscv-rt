# WS53 named interrupt dispatch completeness

The application PAC now declares IPC APP_INT0/1 causes26/27. Adding a PAC IRQ
does not automatically update this runtime's Rust `__INTERRUPTS` table. The
first real CPU IPC model hung in DefaultHandler when enabling IRQ26, exposing
two missing bindings. Comparing the complete PAC set also found SEC_INT1/3
causes59/61 missing. The table now binds all24 declared WS53 interrupts by PAC
enum/name, including all four previously omitted entries; gaps retain the
ordinary DefaultHandler and the ABI stays90 words.

`scripts/check-ws53-irq-table.py --svd /path/to/WS53.svd --self-test` checks
complete set, declarations, duplicate/wrong-name slots and26 mutations. Adding
`--elf /path/to/consumer.elf` resolves the linked90-word table and each actual
handler symbol. This is a validation tool; normal Cargo builds require no SDK,
Python or register generation. Named pointer binding does not establish device
IRQ routing, hardware ACK or handler correctness. Actual model IRQ26/27 delivery
and return are tested by the independent ws53-ipc consumer; silicon validation
remains separate.

This adds no IPC initialization, ring buffers, peripheral ownership negotiation,
control-core release or low-power protocol. SEC_INT1/3 binding alone does not
qualify HASH/SYMC/KM IRQ behavior or shared interrupt ownership. Existing WS63/
BS2X table generation paths are untouched. The change needs the corresponding
WS53 PAC IPC increment,04e54c0 or a later compatible generated PAC.
