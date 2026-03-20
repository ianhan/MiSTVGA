// VGA simulation testbench
// Programs mode 3 (80x25 text), loads font, writes text, verifies sync.

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include "Vvga_sim_top.h"
#include "verilated.h"

#ifdef TRACE
#include "verilated_vcd_c.h"
#endif

// ─── Standard 8x16 VGA font (CP437) ───
// Minimal subset: just enough printable ASCII for verification.
// Each character is 16 bytes (one byte per scanline, MSB = leftmost pixel).
#include "font8x16.h"

// ─── VGA mode 3 register tables ───
// Standard 80x25 text, 720x400 @ 70 Hz, 25.175 MHz dot clock.

static const uint8_t misc_output = 0x67; // positive hsync, negative vsync, 25.175MHz, RAM on, color

// Sequencer: index → data
static const uint8_t seq_regs[][2] = {
    {0, 0x03}, // reset released
    {1, 0x00}, // 9-dot chars, screen on
    {2, 0x03}, // planes 0,1 write-enabled
    {3, 0x00}, // character maps both at 0
    {4, 0x02}, // odd/even addressing, not chain4
};

// CRTC: index → data (standard mode 3 timing for 720x400 @ 70 Hz)
static const uint8_t crtc_regs[][2] = {
    {0x00, 0x5F}, // horizontal total
    {0x01, 0x4F}, // horizontal display end
    {0x02, 0x50}, // horizontal blanking start
    {0x03, 0x82}, // horizontal blanking end
    {0x04, 0x55}, // horizontal retrace start
    {0x05, 0x81}, // horizontal retrace end
    {0x06, 0xBF}, // vertical total
    {0x07, 0x1F}, // overflow
    {0x08, 0x00}, // preset row scan
    {0x09, 0x4F}, // max scan line (16-1=15, plus double scan)
    {0x0A, 0x0D}, // cursor start
    {0x0B, 0x0E}, // cursor end
    {0x0C, 0x00}, // start address high
    {0x0D, 0x00}, // start address low
    {0x0E, 0x00}, // cursor location high
    {0x0F, 0x00}, // cursor location low
    {0x10, 0x9C}, // vertical retrace start
    {0x11, 0x0E}, // vertical retrace end (unlock CRTC)
    {0x12, 0x8F}, // vertical display end
    {0x13, 0x28}, // offset (stride = 80 bytes / 2 = 40 words)
    {0x14, 0x1F}, // underline location
    {0x15, 0x96}, // vertical blanking start
    {0x16, 0xB9}, // vertical blanking end
    {0x17, 0xA3}, // mode control
    {0x18, 0xFF}, // line compare
};

// Graphics controller: index → data
static const uint8_t gc_regs[][2] = {
    {0, 0x00},
    {1, 0x00},
    {2, 0x00},
    {3, 0x00},
    {4, 0x00},
    {5, 0x10}, // odd/even mode
    {6, 0x0E}, // text mode, B8000h mapping
    {7, 0x00},
    {8, 0xFF}, // bit mask
};

// Attribute controller: index → data
// First 16 entries are the internal palette (identity map for CGA colors).
static const uint8_t ac_regs[][2] = {
    {0x00, 0x00}, {0x01, 0x01}, {0x02, 0x02}, {0x03, 0x03},
    {0x04, 0x04}, {0x05, 0x05}, {0x06, 0x14}, {0x07, 0x07},
    {0x08, 0x38}, {0x09, 0x39}, {0x0A, 0x3A}, {0x0B, 0x3B},
    {0x0C, 0x3C}, {0x0D, 0x3D}, {0x0E, 0x3E}, {0x0F, 0x3F},
    {0x10, 0x0C}, // mode control: graphics=0, mono=0, blink=0, line graphics=1, pelclock/2=0
    {0x11, 0x00}, // overscan color
    {0x12, 0x0F}, // color plane enable
    {0x13, 0x08}, // horizontal panning
    {0x14, 0x00}, // color select
};

// Standard VGA DAC palette (first 16 CGA colors, 6-bit per channel)
static const uint8_t dac_palette[][3] = {
    {0x00, 0x00, 0x00}, // 0 black
    {0x00, 0x00, 0x2A}, // 1 blue
    {0x00, 0x2A, 0x00}, // 2 green
    {0x00, 0x2A, 0x2A}, // 3 cyan
    {0x2A, 0x00, 0x00}, // 4 red
    {0x2A, 0x00, 0x2A}, // 5 magenta
    {0x2A, 0x15, 0x00}, // 6 brown
    {0x2A, 0x2A, 0x2A}, // 7 light gray
    {0x15, 0x15, 0x15}, // 8 dark gray
    {0x15, 0x15, 0x3F}, // 9 light blue
    {0x15, 0x3F, 0x15}, // A light green
    {0x15, 0x3F, 0x3F}, // B light cyan
    {0x3F, 0x15, 0x15}, // C light red
    {0x3F, 0x15, 0x3F}, // D light magenta
    {0x3F, 0x3F, 0x15}, // E yellow
    {0x3F, 0x3F, 0x3F}, // F white
};

// ─── Simulation state ───
static Vvga_sim_top *top;
static uint64_t sim_time = 0;
static uint64_t clk_sys_half = 15;  // 33.33 MHz → 30 ns period → 15 ns half
static uint64_t clk_vga_half = 10;  // 50 MHz → 20 ns period → 10 ns half
static uint64_t clk_sys_next = 0;
static uint64_t clk_vga_next = 0;

#ifdef TRACE
static VerilatedVcdC *tfp;
#endif

static int hsync_count = 0;
static int vsync_count = 0;
static int hsync_prev = 0;
static int vsync_prev = 0;
static int nonzero_pixel_count = 0;

static void tick_to(uint64_t target) {
    while (sim_time < target) {
        uint64_t next_event = target;
        if (clk_sys_next < next_event) next_event = clk_sys_next;
        if (clk_vga_next < next_event) next_event = clk_vga_next;

        sim_time = next_event;

        if (sim_time == clk_sys_next) {
            top->clk_sys = !top->clk_sys;
            clk_sys_next = sim_time + clk_sys_half;
        }
        if (sim_time == clk_vga_next) {
            top->clk_vga = !top->clk_vga;
            clk_vga_next = sim_time + clk_vga_half;
        }

        top->eval();
#ifdef TRACE
        tfp->dump(sim_time);
#endif

        // Count sync edges
        if (top->vga_horiz_sync && !hsync_prev) hsync_count++;
        if (top->vga_vert_sync && !vsync_prev) vsync_count++;
        hsync_prev = top->vga_horiz_sync;
        vsync_prev = top->vga_vert_sync;

        // Count non-zero pixels
        if (top->vga_blank_n && (top->vga_r || top->vga_g || top->vga_b))
            nonzero_pixel_count++;
    }
}

// Advance N clk_sys cycles
static void sys_clocks(int n) {
    for (int i = 0; i < n; i++) {
        tick_to(clk_sys_next); // to falling/rising
        tick_to(clk_sys_next); // complete one full cycle
    }
}

// IO write: one clk_sys cycle with io_write asserted
static void io_write_port(int cs_b, int cs_c, int cs_d, uint8_t addr, uint8_t data) {
    top->io_address = addr & 0xF;
    top->io_writedata = data;
    top->io_b_cs = cs_b;
    top->io_c_cs = cs_c;
    top->io_d_cs = cs_d;
    top->io_write = 1;
    top->io_read = 0;
    sys_clocks(1);
    top->io_write = 0;
    top->io_b_cs = 0;
    top->io_c_cs = 0;
    top->io_d_cs = 0;
    sys_clocks(1);
}

// Write to port 3C0-3CF range
static void write_3cx(uint8_t offset, uint8_t data) {
    io_write_port(0, 1, 0, offset, data);
}

// Write to port 3D0-3DF range
static void write_3dx(uint8_t offset, uint8_t data) {
    io_write_port(0, 0, 1, offset, data);
}

// Read from port 3D0-3DF range (to reset attribute flip-flop)
static void read_3dx(uint8_t offset) {
    top->io_address = offset & 0xF;
    top->io_b_cs = 0;
    top->io_c_cs = 0;
    top->io_d_cs = 1;
    top->io_read = 1;
    top->io_write = 0;
    sys_clocks(2); // hold for 2 cycles so read_valid pulses
    top->io_read = 0;
    top->io_d_cs = 0;
    sys_clocks(1);
}

// Memory write
static void mem_write_byte(uint32_t addr, uint8_t data) {
    top->mem_address = addr & 0x1FFFF;
    top->mem_writedata = data;
    top->mem_write = 1;
    top->mem_read = 0;
    sys_clocks(1);
    top->mem_write = 0;
    sys_clocks(1);
}

// ─── Register programming ───

static void program_misc_output() {
    write_3cx(0x2, misc_output);
}

static void program_sequencer() {
    for (int i = 0; i < (int)(sizeof(seq_regs)/sizeof(seq_regs[0])); i++) {
        write_3cx(0x4, seq_regs[i][0]); // index
        write_3cx(0x5, seq_regs[i][1]); // data
    }
}

static void program_crtc() {
    // First unlock CRTC (write 0x0E to reg 0x11 to clear protect bit)
    write_3dx(0x4, 0x11);
    write_3dx(0x5, 0x0E);
    for (int i = 0; i < (int)(sizeof(crtc_regs)/sizeof(crtc_regs[0])); i++) {
        write_3dx(0x4, crtc_regs[i][0]);
        write_3dx(0x5, crtc_regs[i][1]);
    }
}

static void program_graphics_controller() {
    for (int i = 0; i < (int)(sizeof(gc_regs)/sizeof(gc_regs[0])); i++) {
        write_3cx(0xE, gc_regs[i][0]);
        write_3cx(0xF, gc_regs[i][1]);
    }
}

static void program_attribute_controller() {
    // Reset flip-flop by reading input status 1 (port 3DA)
    read_3dx(0xA);

    for (int i = 0; i < (int)(sizeof(ac_regs)/sizeof(ac_regs[0])); i++) {
        const uint8_t index = ac_regs[i][0];
        const uint8_t pas = (index < 0x10) ? 0x00 : 0x20;

        // Palette entries 0x00-0x0F are only writable with PAS cleared.
        // Control registers keep PAS set so video remains enabled afterwards.
        write_3cx(0x0, index | pas);
        // Write data (flip-flop = 1 → data)
        write_3cx(0x0, ac_regs[i][1]);
    }

    // Leave the attribute controller in display-enabled mode.
    write_3cx(0x0, 0x20);
}

static void program_dac() {
    // Set DAC write index to 0
    write_3cx(0x8, 0x00);
    // Write 16 palette entries (3 bytes each: R, G, B in 6-bit)
    for (int i = 0; i < 16; i++) {
        write_3cx(0x9, dac_palette[i][0]);
        write_3cx(0x9, dac_palette[i][1]);
        write_3cx(0x9, dac_palette[i][2]);
    }
}

// Load font into plane 2 via the sequencer/graphics controller memory path.
// In text mode, plane 2 holds the character generator (font bitmaps).
// To write to plane 2 only:
//   1. Set sequencer map mask (SR2) = 0x04 (plane 2 only)
//   2. Set sequencer memory mode (SR4) = 0x06 (sequential, no odd/even)
//   3. Set graphics misc (GR6) = 0x04 (A0000 mapping, not odd/even)
//   4. Write font data to A0000 region
//   5. Restore registers for text mode
static void load_font() {
    // Save and switch to plane 2 write mode
    write_3cx(0x4, 0x02); write_3cx(0x5, 0x04); // SR2 = plane 2 only
    write_3cx(0x4, 0x04); write_3cx(0x5, 0x06); // SR4 = sequential access
    write_3cx(0xE, 0x05); write_3cx(0xF, 0x00); // GR5 = write mode 0, no shift
    write_3cx(0xE, 0x06); write_3cx(0xF, 0x04); // GR6 = A0000, no odd/even

    // Write font data: each char has 32 bytes of space (only first 16 used for 8x16)
    for (int ch = 0; ch < 256; ch++) {
        for (int row = 0; row < 16; row++) {
            uint32_t addr = ch * 32 + row; // offset within A0000 region
            mem_write_byte(addr, font8x16[ch * 16 + row]);
        }
    }

    // Restore text mode registers
    write_3cx(0x4, 0x02); write_3cx(0x5, 0x03); // SR2 = planes 0,1
    write_3cx(0x4, 0x04); write_3cx(0x5, 0x02); // SR4 = odd/even
    write_3cx(0xE, 0x05); write_3cx(0xF, 0x10); // GR5 = odd/even
    write_3cx(0xE, 0x06); write_3cx(0xF, 0x0E); // GR6 = B8000, text mode
}

// Write text string at (col, row) with given attribute
static void write_text(int col, int row, uint8_t attr, const char *str) {
    // In text mode with B8000 mapping and odd/even:
    // mem_address 0x18000 = start of B8000 text buffer
    // Even addresses → plane 0 (character code)
    // Odd addresses → plane 1 (attribute byte)
    uint32_t base = 0x18000 + (row * 80 + col) * 2;
    for (const char *p = str; *p; p++) {
        mem_write_byte(base, (uint8_t)*p);
        mem_write_byte(base + 1, attr);
        base += 2;
    }
}

// ─── Main ───

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vvga_sim_top;

#ifdef TRACE
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("vga_sim.vcd");
#endif

    // Initialize signals
    top->clk_sys = 0;
    top->clk_vga = 0;
    top->rst_n = 0;
    top->io_address = 0;
    top->io_read = 0;
    top->io_write = 0;
    top->io_writedata = 0;
    top->io_b_cs = 0;
    top->io_c_cs = 0;
    top->io_d_cs = 0;
    top->mem_address = 0;
    top->mem_read = 0;
    top->mem_write = 0;
    top->mem_writedata = 0;
    top->clock_rate_vga = 50000000; // 50 MHz clk_vga frequency

    // Initialize clock edges
    clk_sys_next = clk_sys_half;
    clk_vga_next = clk_vga_half;

    // Reset for 100 cycles
    printf("[TB] Asserting reset...\n");
    sys_clocks(100);
    top->rst_n = 1;
    sys_clocks(10);
    printf("[TB] Reset released.\n");

    // Program VGA registers
    printf("[TB] Programming misc output...\n");
    program_misc_output();

    printf("[TB] Programming sequencer...\n");
    program_sequencer();

    printf("[TB] Programming CRTC...\n");
    program_crtc();

    printf("[TB] Programming graphics controller...\n");
    program_graphics_controller();

    printf("[TB] Programming attribute controller...\n");
    program_attribute_controller();

    printf("[TB] Programming DAC palette...\n");
    program_dac();

    printf("[TB] Loading font into plane 2...\n");
    load_font();

    printf("[TB] Writing test text to VRAM...\n");
    // Fill first line with a test message
    write_text(0, 0, 0x07, "Hello, VGA! This is a simulation test.");
    write_text(0, 1, 0x0F, "Bright white text on black background.");
    write_text(0, 2, 0x1E, "Yellow on blue.");
    write_text(0, 3, 0x4F, "White on red.");

    // Also fill the rest of the screen with a pattern
    for (int row = 5; row < 25; row++) {
        char buf[81];
        snprintf(buf, sizeof(buf), "Row %02d: ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !@#$%%^&*()", row);
        write_text(0, row, 0x07, buf);
    }

    // Run simulation
    printf("[TB] Running simulation for ~3 frames...\n");
    hsync_count = 0;
    vsync_count = 0;
    nonzero_pixel_count = 0;

    // At 25.175 MHz dot clock, 720+180=900 dots/line, 449 lines/frame
    // One frame ≈ 900 * 449 / 25.175e6 ≈ 16.02 ms
    // At 50 MHz clk_vga, that's ~800,000 clk_vga cycles per frame
    // Run for ~3 frames = ~50 ms = ~2,500,000 clk_vga cycles
    // In ns: 50e6 ns = 50 ms
    uint64_t run_ns = 50000000ULL; // 50 ms
    uint64_t end_time = sim_time + run_ns;

    // Run in chunks to avoid timeout
    int chunk_num = 0;
    while (sim_time < end_time) {
        uint64_t chunk_end = sim_time + 1000000ULL; // 1ms chunks
        if (chunk_end > end_time) chunk_end = end_time;
        tick_to(chunk_end);
        chunk_num++;
        if (chunk_num <= 5 || chunk_num % 10 == 0) {
            printf("[TB] t=%lu ns  hs=%d vs=%d blank=%d ce=%d R=%02x G=%02x B=%02x  hsync_cnt=%d vsync_cnt=%d\n",
                (unsigned long)sim_time,
                top->vga_horiz_sync, top->vga_vert_sync,
                top->vga_blank_n, top->vga_ce,
                top->vga_r, top->vga_g, top->vga_b,
                hsync_count, vsync_count);
        }
    }

    // Results
    printf("\n[TB] ═══ Simulation Results ═══\n");
    printf("[TB] Simulation time: %lu ns\n", (unsigned long)sim_time);
    printf("[TB] Hsync edges:     %d\n", hsync_count);
    printf("[TB] Vsync edges:     %d\n", vsync_count);
    printf("[TB] Non-zero pixels: %d\n", nonzero_pixel_count);

    int pass = 1;

    // Expect ~3 vsync edges for 3 frames
    if (vsync_count < 2) {
        printf("[TB] FAIL: Expected at least 2 vsync edges, got %d\n", vsync_count);
        pass = 0;
    } else {
        printf("[TB] PASS: Vsync toggling (%d edges)\n", vsync_count);
    }

    // Expect many hsync edges (449 per frame * ~3 frames ≈ 1347)
    if (hsync_count < 400) {
        printf("[TB] FAIL: Expected at least 400 hsync edges, got %d\n", hsync_count);
        pass = 0;
    } else {
        printf("[TB] PASS: Hsync toggling (%d edges)\n", hsync_count);
    }

    // Check that DAC is producing output and sync timing is valid.
    // Hsync rate ≈ 31.47 kHz, vsync ≈ 70 Hz.
    float hsync_rate = (float)hsync_count / ((float)sim_time / 1e9f);
    float vsync_rate = (float)vsync_count / ((float)sim_time / 1e9f);
    printf("[TB] Hsync rate: %.1f kHz (expected ~31.5 kHz)\n", hsync_rate / 1000.0f);
    printf("[TB] Vsync rate: %.1f Hz (expected ~70 Hz)\n", vsync_rate);

    if (hsync_rate < 25000 || hsync_rate > 40000) {
        printf("[TB] FAIL: Hsync rate out of range\n");
        pass = 0;
    } else {
        printf("[TB] PASS: Hsync rate in valid range\n");
    }

    if (vsync_rate < 55 || vsync_rate > 85) {
        printf("[TB] FAIL: Vsync rate out of range\n");
        pass = 0;
    } else {
        printf("[TB] PASS: Vsync rate in valid range\n");
    }

    if (nonzero_pixel_count == 0) {
        printf("[TB] FAIL: Expected non-zero RGB output after initialization\n");
        pass = 0;
    } else {
        printf("[TB] PASS: Non-zero RGB output observed (%d pixels)\n", nonzero_pixel_count);
    }

    if (pass)
        printf("\n[TB] ✓ ALL CHECKS PASSED\n");
    else
        printf("\n[TB] ✗ SOME CHECKS FAILED\n");

#ifdef TRACE
    tfp->close();
    printf("[TB] VCD trace written to vga_sim.vcd\n");
#endif

    top->final();
    delete top;
    return pass ? 0 : 1;
}
