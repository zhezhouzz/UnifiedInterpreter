Supported regbase targets need automatic intra-core synchronization using GET_BUF/RLS_BUF. Producer/consumer dependencies, loops and multibuffered accesses require ordering while avoiding unsafe buffer-ID reuse.

Expected behavior and acceptance criteria:
- Offer automatic buffer synchronization for supported A5/A6 targets and an option to select the existing event solver.
- Preserve producer/consumer, fan-in/fan-out, loop-carried and conditional ordering.
- Support multibuffered accesses and bounded hardware buffer-ID allocation.
- Remain correct when available buffer IDs are exhausted.
- Diagnose unsupported targets and unsupported kernel forms.
- Verify bracket pairing, matching modes and unsafe same-ID nesting, including dynamic IDs and control flow.