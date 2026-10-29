/* Link-time defaults, not weak definitions inside a Rust LTO assembly unit. */
PROVIDE(WS53_EXCEPTION = __ws53_default_exception_dispatch);
PROVIDE(default_exc_handler = __ws53_default_exc_halt);
PROVIDE(do_insn_misaligned = default_exc_handler);
PROVIDE(do_insn_fault = default_exc_handler);
PROVIDE(do_insn_illegal = default_exc_handler);
PROVIDE(do_breakpoint = default_exc_handler);
PROVIDE(do_load_misaligned = default_exc_handler);
PROVIDE(do_load_fault = default_exc_handler);
PROVIDE(do_store_misaligned = default_exc_handler);
PROVIDE(do_store_fault = default_exc_handler);
PROVIDE(do_ecall_u = default_exc_handler);
PROVIDE(do_ecall_s = default_exc_handler);
PROVIDE(do_ecall_m = default_exc_handler);
PROVIDE(do_insn_page_fault = default_exc_handler);
PROVIDE(do_load_page_fault = default_exc_handler);
PROVIDE(do_store_page_fault = default_exc_handler);
