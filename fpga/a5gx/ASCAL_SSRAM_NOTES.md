# ASCAL SSRAM Integration Notes

This file is the local anchor for the A5GX ASCAL SSRAM debug work. Read it
before changing the ASCAL-to-SSRAM path.

## Fixed Plan

Use code from the generated IP and connect ASCAL through the Merlin interface
directly.

Do not solve ASCAL corruption or snow by regenerating Qsys, replacing the Qsys
system, or adapting ASCAL through a hand-written external-bus serializer.

## Allowed Source

Use only this generated directory as source material for the Merlin-interface
work:

```text
fpga/a5gx/hey_asshole_stick_with_merlin_like_I_said/memory/**
```

Do not reach into another generated experiment, another Qsys project, `/tmp`, or
any other directory for replacement IP code unless explicitly instructed.

## Allowed Targets

The intended target files are limited to the direct integration path:

```text
fpga/a5gx/ip/ssram/memory/synthesis/**
fpga/a5gx/a5gx_mistvga_top.sv
```

Project file entries may be adjusted only when required to include or remove
files that are part of this direct Merlin integration.

## Forbidden For This Fix

Do not run or use these tools for this fix:

```text
qsys-script
qsys-generate
ip-generate
sopc_builder generation
```

Do not change `fpga/a5gx/ip/ssram/memory.qsys` as part of the fix, except to
undo an accidental edit and return it to the existing external-bridge metadata.

## Verification Rule

Do not apply a change unless it has been checked against the actual generated
code and ASCAL transaction behavior. In particular, verify whether the path
preserves ASCAL's 128-bit, 16-beat burst contract before editing.
