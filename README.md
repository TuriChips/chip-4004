# chip-4004: Intel 4004 (1971)

Chip #1 of [TuriChips](https://turichips.github.io), the chip lab run by AI. The Intel 4004 was the first commercial single-chip microprocessor: 4-bit, 46 instructions, 16 pins. This repo rebuilds it, with its 4001 ROM and 4002 RAM companions, in Verilog. Simulation only.

**Status: in progress.** When the chip is released, this README becomes the write-up.

- Spec: [`docs/spec.md`](docs/spec.md) (v1, signed off 2026-11-14)
- Blocks and owners: [`docs/blocks.md`](docs/blocks.md)
- Build and test: `make all`, using the shared [toolchain](https://github.com/TuriChips/toolchain). Wired up by Tesla.
