#!/usr/bin/env python3
"""Patch a VGA BIOS ROM with a PCIR data structure and emit $readmemh hex."""

import sys

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.rom> <output.hex>", file=sys.stderr)
        sys.exit(1)

    rom_path, hex_path = sys.argv[1], sys.argv[2]

    with open(rom_path, "rb") as f:
        rom = bytearray(f.read())

    assert len(rom) == 32768, f"Expected 32768 bytes, got {len(rom)}"
    assert rom[0] == 0x55 and rom[1] == 0xAA, "Missing ROM signature 55 AA"

    # Verify the patch region is zero (don't clobber existing data)
    for i in range(0x06, 0x1E):
        assert rom[i] == 0, f"Byte at 0x{i:02X} is 0x{rom[i]:02X}, expected 0x00"

    # Patch 24-byte PCIR structure at offset 0x06
    pcir = bytearray([
        0x50, 0x43, 0x49, 0x52,  # 'PCIR' signature
        0x3D, 0x3D,              # Vendor ID 0x3D3D
        0x00, 0x3D,              # Device ID 0x3D00
        0x00, 0x00,              # VPD pointer (none)
        0x18, 0x00,              # PCIR data structure length = 24
        0x00,                    # PCIR revision 0
        0x00, 0x00, 0x03,       # Class code: 03 00 00 (VGA)
        0x40, 0x00,              # Image length: 64 * 512 = 32KB
        0x06, 0x00,              # Code revision (doubles as PCI data ptr at ROM 0x18)
        0x00,                    # Code type: x86
        0x80,                    # Last image indicator
        0x00, 0x00,              # Reserved
    ])
    assert len(pcir) == 24
    rom[0x06:0x06 + 24] = pcir

    # Fix checksum: adjust last byte so all bytes sum to 0 mod 256
    rom[-1] = 0
    checksum = sum(rom) & 0xFF
    rom[-1] = (256 - checksum) & 0xFF
    assert sum(rom) & 0xFF == 0, "Checksum failed"

    # Write patched ROM for inspection
    patched_path = rom_path.replace(".rom", "_pcir.rom")
    with open(patched_path, "wb") as f:
        f.write(rom)
    print(f"Patched ROM: {patched_path}")

    # Emit $readmemh hex: 8192 lines of 32-bit words, little-endian packed
    with open(hex_path, "w") as f:
        for i in range(0, len(rom), 4):
            word = rom[i] | (rom[i+1] << 8) | (rom[i+2] << 16) | (rom[i+3] << 24)
            f.write(f"{word:08X}\n")
    print(f"Hex file:    {hex_path} ({len(rom) // 4} words)")

if __name__ == "__main__":
    main()
