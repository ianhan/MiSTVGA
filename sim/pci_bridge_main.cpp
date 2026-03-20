#include <cstdint>
#include <cstdio>
#include <cstdlib>

#include "Vpci_bridge_test_top.h"
#include "verilated.h"

static Vpci_bridge_test_top* top = nullptr;

static bool check_equal_u8(const char* label, uint8_t actual, uint8_t expected, bool verbose_success);
static bool check_equal_u32(const char* label, uint32_t actual, uint32_t expected, bool verbose_success);
static bool check_true(const char* label, bool condition, bool verbose_success);
static bool expect_equal_u8(const char* label, uint8_t actual, uint8_t expected);
static bool expect_true(const char* label, bool condition);
static uint8_t parity32(uint32_t value);
static uint8_t pci_read_phase_parity(uint32_t data, uint8_t byte_en);
static bool pci_read_internal(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t* data,
                              bool idsel, bool verbose_success);
static bool pci_read_quiet(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t* data, bool idsel);
static bool pci_write_then_read_no_gap(uint32_t write_addr, uint8_t write_cmd, uint8_t write_byte_en,
                                       uint32_t write_data, bool write_idsel, uint32_t read_addr,
                                       uint8_t read_cmd, uint8_t read_byte_en, uint32_t* read_data,
                                       bool read_idsel, bool verbose_success);
static bool pci_read_then_write_no_gap(uint32_t read_addr, uint8_t read_cmd, uint8_t read_byte_en,
                                       uint32_t* read_data, bool read_idsel, uint32_t write_addr,
                                       uint8_t write_cmd, uint8_t write_byte_en, uint32_t write_data,
                                       bool write_idsel, bool verbose_success);
static bool pci_write_then_write_no_gap(uint32_t write0_addr, uint8_t write0_cmd, uint8_t write0_byte_en,
                                        uint32_t write0_data, bool write0_idsel, uint32_t write1_addr,
                                        uint8_t write1_cmd, uint8_t write1_byte_en, uint32_t write1_data,
                                        bool write1_idsel);
static uint32_t lcg_next(uint32_t* state);
static void model_apply_write(uint8_t* model, uint32_t word_offset, uint32_t data, uint8_t byte_en);
static uint32_t model_load_word(const uint8_t* model, uint32_t word_offset);
static uint32_t model_select_lanes(uint32_t word, uint8_t byte_en);
static uint8_t pci_single_byte_enable(uint32_t byte_addr);
static uint32_t pci_single_byte_data(uint32_t byte_addr, uint8_t value);
static uint8_t pci_extract_byte(uint32_t word, uint32_t byte_addr);
static bool pci_read_byte_quiet(uint32_t addr, uint8_t cmd, uint8_t* value, bool idsel);
static uint32_t fizzlefade_next_offset(uint32_t* rndval);
static bool stress_fast_back_to_back_io();
static bool stress_fast_back_to_back_vram();
static bool stress_true_back_to_back_vram_write_read();
static bool stress_true_back_to_back_vram_read_write();
static bool stress_fizzlefade_no_gap_byte_writes();
static bool stress_fizzlefade_no_gap_byte_rmw();

static void tick() {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
}

static void set_idle_bus() {
    top->host_ad_drive = 0;
    top->host_ad_out = 0;
    top->host_cben_out = 0xF;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 1;
    top->host_idsel = 0;
}

static void reset_dut() {
    top->rst_n = 0;
    set_idle_bus();
    for (int i = 0; i < 4; ++i) {
        tick();
    }
    top->rst_n = 1;
    for (int i = 0; i < 4; ++i) {
        tick();
    }
}

static bool wait_for_target_ready(uint32_t* read_data = nullptr) {
    for (int i = 0; i < 64; ++i) {
        tick();
        if (!top->host_devsel_n_in && !top->host_trdy_n_in) {
            if (read_data != nullptr) {
                *read_data = top->host_ad_in;
            }
            return true;
        }
    }
    return false;
}

static void end_transaction() {
    set_idle_bus();
    tick();
    tick();
}

static bool pci_write(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t data, bool idsel) {
    top->host_idsel = idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = addr;
    top->host_cben_out = cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = data;
    top->host_cben_out = byte_en & 0xF;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    const bool ok = wait_for_target_ready();
    end_transaction();
    return ok;
}

static bool pci_read(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t* data, bool idsel) {
    return pci_read_internal(addr, cmd, byte_en, data, idsel, true);
}

static bool pci_read_internal(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t* data,
                              bool idsel, bool verbose_success) {
    top->host_idsel = idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = addr;
    top->host_cben_out = cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = idsel ? 1 : 0;
    top->host_ad_drive = 0;
    top->host_ad_out = 0;
    top->host_cben_out = byte_en & 0xF;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    const bool ok = wait_for_target_ready(data);
    bool pass = ok;

    if (!ok) {
        end_transaction();
        return false;
    }

    pass &= check_true("Read data phase asserted STOP#", !top->host_stop_n_in, verbose_success);

    tick();

    pass &= check_true("Turnaround deasserted TRDY#", top->host_trdy_n_in, verbose_success);
    pass &= check_true("Turnaround deasserted DEVSEL#", top->host_devsel_n_in, verbose_success);
    pass &= check_true("Turnaround deasserted STOP#", top->host_stop_n_in, verbose_success);
    pass &= check_true("Turnaround drove PAR", top->host_par_oe_in, verbose_success);
    pass &= check_equal_u8("Turnaround PAR",
                           static_cast<uint8_t>(top->host_par_in),
                           pci_read_phase_parity(*data, byte_en),
                           verbose_success);

    set_idle_bus();
    tick();
    pass &= check_true("PAR released after turnaround", !top->host_par_oe_in, verbose_success);
    return pass;
}

static bool pci_read_quiet(uint32_t addr, uint8_t cmd, uint8_t byte_en, uint32_t* data, bool idsel) {
    return pci_read_internal(addr, cmd, byte_en, data, idsel, false);
}

static bool pci_write_then_read_no_gap(uint32_t write_addr, uint8_t write_cmd, uint8_t write_byte_en,
                                       uint32_t write_data, bool write_idsel, uint32_t read_addr,
                                       uint8_t read_cmd, uint8_t read_byte_en, uint32_t* read_data,
                                       bool read_idsel, bool verbose_success) {
    top->host_idsel = write_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write_addr;
    top->host_cben_out = write_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = write_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write_data;
    top->host_cben_out = write_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    if (!wait_for_target_ready()) {
        end_transaction();
        return false;
    }

    top->host_idsel = read_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = read_addr;
    top->host_cben_out = read_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = read_idsel ? 1 : 0;
    top->host_ad_drive = 0;
    top->host_ad_out = 0;
    top->host_cben_out = read_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    const bool ok = wait_for_target_ready(read_data);
    bool pass = ok;

    if (!ok) {
        end_transaction();
        return false;
    }

    pass &= check_true("No-gap read data phase asserted STOP#", !top->host_stop_n_in, verbose_success);

    tick();

    pass &= check_true("No-gap read turnaround deasserted TRDY#", top->host_trdy_n_in, verbose_success);
    pass &= check_true("No-gap read turnaround deasserted DEVSEL#", top->host_devsel_n_in, verbose_success);
    pass &= check_true("No-gap read turnaround deasserted STOP#", top->host_stop_n_in, verbose_success);
    pass &= check_true("No-gap read turnaround drove PAR", top->host_par_oe_in, verbose_success);
    pass &= check_equal_u8("No-gap read turnaround PAR",
                           static_cast<uint8_t>(top->host_par_in),
                           pci_read_phase_parity(*read_data, read_byte_en),
                           verbose_success);

    set_idle_bus();
    tick();
    pass &= check_true("No-gap read released PAR", !top->host_par_oe_in, verbose_success);
    return pass;
}

static bool pci_read_then_write_no_gap(uint32_t read_addr, uint8_t read_cmd, uint8_t read_byte_en,
                                       uint32_t* read_data, bool read_idsel, uint32_t write_addr,
                                       uint8_t write_cmd, uint8_t write_byte_en, uint32_t write_data,
                                       bool write_idsel, bool verbose_success) {
    top->host_idsel = read_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = read_addr;
    top->host_cben_out = read_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = read_idsel ? 1 : 0;
    top->host_ad_drive = 0;
    top->host_ad_out = 0;
    top->host_cben_out = read_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    const bool ok = wait_for_target_ready(read_data);
    bool pass = ok;

    if (!ok) {
        end_transaction();
        return false;
    }

    pass &= check_true("No-gap read data phase asserted STOP#", !top->host_stop_n_in, verbose_success);

    tick();

    pass &= check_true("No-gap write address released TRDY#", top->host_trdy_n_in, verbose_success);
    pass &= check_true("No-gap write address released DEVSEL#", top->host_devsel_n_in, verbose_success);
    pass &= check_true("No-gap write address released STOP#", top->host_stop_n_in, verbose_success);
    pass &= check_true("No-gap write address drove PAR", top->host_par_oe_in, verbose_success);
    pass &= check_equal_u8("No-gap write address PAR",
                           static_cast<uint8_t>(top->host_par_in),
                           pci_read_phase_parity(*read_data, read_byte_en),
                           verbose_success);

    top->host_idsel = write_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write_addr;
    top->host_cben_out = write_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    pass &= check_true("No-gap write address released PAR", !top->host_par_oe_in, verbose_success);

    top->host_idsel = write_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write_data;
    top->host_cben_out = write_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    pass &= wait_for_target_ready();
    end_transaction();
    return pass;
}

static bool pci_write_then_write_no_gap(uint32_t write0_addr, uint8_t write0_cmd, uint8_t write0_byte_en,
                                        uint32_t write0_data, bool write0_idsel, uint32_t write1_addr,
                                        uint8_t write1_cmd, uint8_t write1_byte_en, uint32_t write1_data,
                                        bool write1_idsel) {
    top->host_idsel = write0_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write0_addr;
    top->host_cben_out = write0_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = write0_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write0_data;
    top->host_cben_out = write0_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    if (!wait_for_target_ready()) {
        end_transaction();
        return false;
    }

    top->host_idsel = write1_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write1_addr;
    top->host_cben_out = write1_cmd;
    top->host_frame_n_out = 0;
    top->host_irdy_n_out = 1;
    tick();

    top->host_idsel = write1_idsel ? 1 : 0;
    top->host_ad_drive = 1;
    top->host_ad_out = write1_data;
    top->host_cben_out = write1_byte_en & 0xFu;
    top->host_frame_n_out = 1;
    top->host_irdy_n_out = 0;

    const bool ok = wait_for_target_ready();
    end_transaction();
    return ok;
}

static bool check_equal_u8(const char* label, uint8_t actual, uint8_t expected, bool verbose_success) {
    if (actual != expected) {
        std::printf("[TB] FAIL: %s expected 0x%02x got 0x%02x\n",
                    label, expected, actual);
        return false;
    }
    if (verbose_success) {
        std::printf("[TB] PASS: %s = 0x%02x\n", label, actual);
    }
    return true;
}

static bool check_equal_u32(const char* label, uint32_t actual, uint32_t expected, bool verbose_success) {
    if (actual != expected) {
        std::printf("[TB] FAIL: %s expected 0x%08x got 0x%08x\n",
                    label, expected, actual);
        return false;
    }
    if (verbose_success) {
        std::printf("[TB] PASS: %s = 0x%08x\n", label, actual);
    }
    return true;
}

static bool check_true(const char* label, bool condition, bool verbose_success) {
    if (!condition) {
        std::printf("[TB] FAIL: %s\n", label);
        return false;
    }
    if (verbose_success) {
        std::printf("[TB] PASS: %s\n", label);
    }
    return true;
}

static bool expect_equal_u8(const char* label, uint8_t actual, uint8_t expected) {
    return check_equal_u8(label, actual, expected, true);
}

static bool expect_equal_u32(const char* label, uint32_t actual, uint32_t expected) {
    return check_equal_u32(label, actual, expected, true);
}

static bool expect_true(const char* label, bool condition) {
    return check_true(label, condition, true);
}

static uint8_t parity32(uint32_t value) {
    value ^= value >> 16;
    value ^= value >> 8;
    value ^= value >> 4;
    value &= 0xFu;
    return static_cast<uint8_t>((0x6996u >> value) & 0x1u);
}

static uint8_t pci_read_phase_parity(uint32_t data, uint8_t byte_en) {
    return static_cast<uint8_t>(parity32(data) ^ parity32(byte_en & 0xFu));
}

static uint32_t lcg_next(uint32_t* state) {
    *state = (*state * 1664525u) + 1013904223u;
    return *state;
}

static void model_apply_write(uint8_t* model, uint32_t word_offset, uint32_t data, uint8_t byte_en) {
    for (uint32_t lane = 0; lane < 4; ++lane) {
        if ((byte_en & (1u << lane)) == 0) {
            model[word_offset + lane] = static_cast<uint8_t>(data >> (lane * 8));
        }
    }
}

static uint32_t model_load_word(const uint8_t* model, uint32_t word_offset) {
    return static_cast<uint32_t>(model[word_offset]) |
           (static_cast<uint32_t>(model[word_offset + 1]) << 8) |
           (static_cast<uint32_t>(model[word_offset + 2]) << 16) |
           (static_cast<uint32_t>(model[word_offset + 3]) << 24);
}

static uint32_t model_select_lanes(uint32_t word, uint8_t byte_en) {
    uint32_t selected = 0;
    for (uint32_t lane = 0; lane < 4; ++lane) {
        if ((byte_en & (1u << lane)) == 0) {
            selected |= word & (0xFFu << (lane * 8));
        }
    }
    return selected;
}

static uint8_t pci_single_byte_enable(uint32_t byte_addr) {
    return static_cast<uint8_t>(0xFu & ~(1u << (byte_addr & 0x3u)));
}

static uint32_t pci_single_byte_data(uint32_t byte_addr, uint8_t value) {
    return static_cast<uint32_t>(value) << ((byte_addr & 0x3u) * 8u);
}

static uint8_t pci_extract_byte(uint32_t word, uint32_t byte_addr) {
    return static_cast<uint8_t>((word >> ((byte_addr & 0x3u) * 8u)) & 0xFFu);
}

static bool pci_read_byte_quiet(uint32_t addr, uint8_t cmd, uint8_t* value, bool idsel) {
    uint32_t word = 0;
    if (!pci_read_quiet(addr, cmd, pci_single_byte_enable(addr), &word, idsel)) {
        return false;
    }
    *value = pci_extract_byte(word, addr);
    return true;
}

static uint32_t fizzlefade_next_offset(uint32_t* rndval) {
    while (true) {
        const uint32_t current = *rndval;
        const uint32_t y = current & 0x0000FFu;
        const uint32_t x = (current & 0x01FF00u) >> 8;
        const uint32_t lsb = current & 1u;

        *rndval = current >> 1;
        if (lsb) {
            *rndval ^= 0x00012000u;
        }
        if (x < 320u && y < 200u) {
            return (y * 320u) + x;
        }
    }
}

static bool stress_fast_back_to_back_io() {
    std::printf("[TB] Stressing fast back-to-back VGA I/O read/write/RMW...\n");

    bool pass = true;
    uint8_t io_model[16] = {};
    uint32_t seed = 0x13579BDFu;

    io_model[4] = top->io_c_4;
    io_model[5] = top->io_c_5;
    io_model[6] = top->io_c_6;

    for (int i = 0; i < 128 && pass; ++i) {
        const bool unaligned = (lcg_next(&seed) & 1u) != 0;
        const uint32_t addr = unaligned ? 0x000003C5u : 0x000003C4u;
        const uint8_t byte_en = unaligned ? 0x9u : 0xCu;
        const uint32_t word_offset = (addr - 0x000003C0u) & ~0x3u;
        const uint8_t byte0 = static_cast<uint8_t>(lcg_next(&seed) >> 24);
        const uint8_t byte1 = static_cast<uint8_t>(lcg_next(&seed) >> 24);
        const uint32_t write_data = unaligned
            ? (static_cast<uint32_t>(byte0) << 8) | (static_cast<uint32_t>(byte1) << 16)
            : static_cast<uint32_t>(byte0) | (static_cast<uint32_t>(byte1) << 8);

        pass &= pci_write(addr, 0x3u, byte_en, write_data, false);
        model_apply_write(io_model, word_offset, write_data, byte_en);

        uint32_t read_data = 0;
        pass &= pci_read_quiet(addr, 0x2u, byte_en, &read_data, false);
        const uint32_t expected_read = model_select_lanes(model_load_word(io_model, word_offset), byte_en);
        if (read_data != expected_read) {
            std::printf("[TB] FAIL: I/O stress read iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_read, read_data);
            pass = false;
            break;
        }

        const uint32_t rmw_data = read_data ^ (unaligned ? 0x005A3C00u : 0x00005A3Cu);
        pass &= pci_write(addr, 0x3u, byte_en, rmw_data, false);
        model_apply_write(io_model, word_offset, rmw_data, byte_en);

        uint32_t verify_data = 0;
        pass &= pci_read_quiet(addr, 0x2u, byte_en, &verify_data, false);
        const uint32_t expected_verify = model_select_lanes(model_load_word(io_model, word_offset), byte_en);
        if (verify_data != expected_verify) {
            std::printf("[TB] FAIL: I/O stress RMW iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_verify, verify_data);
            pass = false;
            break;
        }
    }

    if (pass) {
        std::printf("[TB] PASS: Fast back-to-back I/O stress\n");
    }
    return pass;
}

static bool stress_fast_back_to_back_vram() {
    std::printf("[TB] Stressing fast back-to-back VRAM read/write/RMW...\n");

    static constexpr uint32_t kStressBase = 0x000B8100u;
    static constexpr uint32_t kStressBytes = 128u;
    static constexpr uint32_t kStressWords = kStressBytes / 4u;

    bool pass = true;
    uint8_t vram_model[kStressBytes] = {};
    uint32_t seed = 0x2468ACE1u;

    for (uint32_t word = 0; word < kStressWords && pass; ++word) {
        const uint32_t addr = kStressBase + (word * 4u);
        const uint32_t write_data = lcg_next(&seed);
        pass &= pci_write(addr, 0x7u, 0x0u, write_data, false);
        model_apply_write(vram_model, word * 4u, write_data, 0x0u);

        uint32_t read_data = 0;
        pass &= pci_read_quiet(addr, 0x6u, 0x0u, &read_data, false);
        const uint32_t expected = model_load_word(vram_model, word * 4u);
        if (read_data != expected) {
            std::printf("[TB] FAIL: VRAM seed read word %u addr 0x%08x expected 0x%08x got 0x%08x\n",
                        word, addr, expected, read_data);
            pass = false;
            break;
        }
    }

    for (int i = 0; i < 256 && pass; ++i) {
        const uint32_t src_word = lcg_next(&seed) % kStressWords;
        const uint32_t dst_word = lcg_next(&seed) % kStressWords;
        const uint32_t src_addr = kStressBase + (src_word * 4u);
        const uint32_t dst_addr = kStressBase + (dst_word * 4u);

        uint32_t src_data = 0;
        pass &= pci_read_quiet(src_addr, 0x6u, 0x0u, &src_data, false);
        const uint32_t expected_src = model_load_word(vram_model, src_word * 4u);
        if (src_data != expected_src) {
            std::printf("[TB] FAIL: VRAM copy read iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, src_addr, expected_src, src_data);
            pass = false;
            break;
        }

        pass &= pci_write(dst_addr, 0x7u, 0x0u, src_data, false);
        model_apply_write(vram_model, dst_word * 4u, src_data, 0x0u);

        uint32_t dst_data = 0;
        pass &= pci_read_quiet(dst_addr, 0x6u, 0x0u, &dst_data, false);
        const uint32_t expected_dst = model_load_word(vram_model, dst_word * 4u);
        if (dst_data != expected_dst) {
            std::printf("[TB] FAIL: VRAM copy verify iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, dst_addr, expected_dst, dst_data);
            pass = false;
            break;
        }
    }

    const uint8_t masks[] = {0xAu, 0x5u, 0xCu, 0x3u, 0x6u, 0x9u};
    for (int i = 0; i < 256 && pass; ++i) {
        const uint32_t word = lcg_next(&seed) % kStressWords;
        const uint32_t word_offset = word * 4u;
        const uint32_t addr = kStressBase + word_offset;

        uint32_t cur = 0;
        pass &= pci_read_quiet(addr, 0x6u, 0x0u, &cur, false);
        const uint32_t expected_cur = model_load_word(vram_model, word_offset);
        if (cur != expected_cur) {
            std::printf("[TB] FAIL: VRAM RMW read iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_cur, cur);
            pass = false;
            break;
        }

        const uint8_t byte_en = masks[lcg_next(&seed) % (sizeof(masks) / sizeof(masks[0]))];
        const uint32_t patch = lcg_next(&seed) ^ ((cur << 5) | (cur >> 27));
        pass &= pci_write(addr, 0x7u, byte_en, patch, false);
        model_apply_write(vram_model, word_offset, patch, byte_en);

        uint32_t verify = 0;
        pass &= pci_read_quiet(addr, 0x6u, 0x0u, &verify, false);
        const uint32_t expected_verify = model_load_word(vram_model, word_offset);
        if (verify != expected_verify) {
            std::printf("[TB] FAIL: VRAM RMW verify iter %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_verify, verify);
            pass = false;
            break;
        }
    }

    if (pass) {
        std::printf("[TB] PASS: Fast back-to-back VRAM stress\n");
    }
    return pass;
}

static bool stress_true_back_to_back_vram_write_read() {
    std::printf("[TB] Stressing true no-gap VRAM write->read RMW traffic...\n");

    static constexpr uint32_t kStressBase = 0x000B8200u;
    static constexpr uint32_t kStressBytes = 128u;
    static constexpr uint32_t kStressWords = kStressBytes / 4u;

    bool pass = true;
    uint8_t vram_model[kStressBytes] = {};
    uint32_t seed = 0x31415926u;

    for (uint32_t word = 0; word < kStressWords && pass; ++word) {
        const uint32_t addr = kStressBase + (word * 4u);
        const uint32_t init = lcg_next(&seed);
        pass &= pci_write(addr, 0x7u, 0x0u, init, false);
        model_apply_write(vram_model, word * 4u, init, 0x0u);
    }

    uint32_t current_word = 0;
    uint32_t current_addr = kStressBase;
    uint32_t current_data = 0;
    pass &= pci_read_quiet(current_addr, 0x6u, 0x0u, &current_data, false);
    if (pass && current_data != model_load_word(vram_model, current_word * 4u)) {
        std::printf("[TB] FAIL: No-gap RMW prime read expected 0x%08x got 0x%08x\n",
                    model_load_word(vram_model, current_word * 4u), current_data);
        pass = false;
    }

    for (int i = 0; i < 256 && pass; ++i) {
        const uint32_t next_word = (current_word + 1u + (lcg_next(&seed) % 3u)) % kStressWords;
        const uint32_t next_addr = kStressBase + (next_word * 4u);
        const uint32_t patch = current_data ^ lcg_next(&seed);

        uint32_t next_data = 0;
        pass &= pci_write_then_read_no_gap(current_addr, 0x7u, 0x0u, patch, false,
                                           next_addr, 0x6u, 0x0u, &next_data, false, false);
        model_apply_write(vram_model, current_word * 4u, patch, 0x0u);

        const uint32_t expected_next = model_load_word(vram_model, next_word * 4u);
        if (next_data != expected_next) {
            std::printf("[TB] FAIL: No-gap write->read iter %d read addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, next_addr, expected_next, next_data);
            pass = false;
            break;
        }

        current_word = next_word;
        current_addr = next_addr;
        current_data = next_data;
    }

    if (pass) {
        std::printf("[TB] PASS: True no-gap VRAM write->read RMW stress\n");
    }
    return pass;
}

static bool stress_true_back_to_back_vram_read_write() {
    std::printf("[TB] Stressing true no-gap VRAM read->write traffic...\n");

    static constexpr uint32_t kStressBase = 0x000B8300u;
    static constexpr uint32_t kStressBytes = 128u;
    static constexpr uint32_t kStressWords = kStressBytes / 4u;
    const uint8_t masks[] = {0x0u, 0xAu, 0x5u, 0xCu, 0x3u, 0x6u, 0x9u};

    bool pass = true;
    uint8_t vram_model[kStressBytes] = {};
    uint32_t seed = 0x27182818u;

    for (uint32_t word = 0; word < kStressWords && pass; ++word) {
        const uint32_t addr = kStressBase + (word * 4u);
        const uint32_t init = lcg_next(&seed);
        pass &= pci_write(addr, 0x7u, 0x0u, init, false);
        model_apply_write(vram_model, word * 4u, init, 0x0u);
    }

    for (int i = 0; i < 256 && pass; ++i) {
        const uint32_t word = lcg_next(&seed) % kStressWords;
        const uint32_t word_offset = word * 4u;
        const uint32_t addr = kStressBase + word_offset;
        const uint8_t byte_en = masks[lcg_next(&seed) % (sizeof(masks) / sizeof(masks[0]))];
        const uint32_t patch = lcg_next(&seed);

        uint32_t read_data = 0;
        pass &= pci_read_then_write_no_gap(addr, 0x6u, 0x0u, &read_data, false,
                                           addr, 0x7u, byte_en, patch, false, false);

        const uint32_t expected_read = model_load_word(vram_model, word_offset);
        if (read_data != expected_read) {
            std::printf("[TB] FAIL: No-gap read->write iter %d read addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_read, read_data);
            pass = false;
            break;
        }

        model_apply_write(vram_model, word_offset, patch, byte_en);

        uint32_t verify = 0;
        pass &= pci_read_quiet(addr, 0x6u, 0x0u, &verify, false);
        const uint32_t expected_verify = model_load_word(vram_model, word_offset);
        if (verify != expected_verify) {
            std::printf("[TB] FAIL: No-gap read->write iter %d verify addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_verify, verify);
            pass = false;
            break;
        }
    }

    if (pass) {
        std::printf("[TB] PASS: True no-gap VRAM read->write stress\n");
    }
    return pass;
}

static bool stress_fizzlefade_no_gap_byte_writes() {
    std::printf("[TB] Stressing fizzlefade-style no-gap byte writes...\n");

    static constexpr uint32_t kBase = 0x000A0000u;
    static constexpr uint32_t kPixels = 320u * 200u;
    static constexpr int kOps = 2048;

    bool pass = true;
    uint8_t model[kPixels] = {};
    uint32_t rndval = 1u;
    uint32_t sample_seed = 0xF17EFADEu;

    uint32_t first_offset = fizzlefade_next_offset(&rndval);
    uint8_t first_value = static_cast<uint8_t>(lcg_next(&sample_seed) >> 24);
    pass &= pci_write(kBase + first_offset, 0x7u, pci_single_byte_enable(kBase + first_offset),
                      pci_single_byte_data(kBase + first_offset, first_value), false);
    model[first_offset] = first_value;

    for (int i = 1; i < kOps && pass; i += 2) {
        const uint32_t offset0 = fizzlefade_next_offset(&rndval);
        const uint32_t addr0 = kBase + offset0;
        const uint8_t value0 = static_cast<uint8_t>(lcg_next(&sample_seed) >> 24);

        const uint32_t offset1 = fizzlefade_next_offset(&rndval);
        const uint32_t addr1 = kBase + offset1;
        const uint8_t value1 = static_cast<uint8_t>(lcg_next(&sample_seed) >> 24);

        pass &= pci_write_then_write_no_gap(addr0, 0x7u, pci_single_byte_enable(addr0),
                                            pci_single_byte_data(addr0, value0), false,
                                            addr1, 0x7u, pci_single_byte_enable(addr1),
                                            pci_single_byte_data(addr1, value1), false);
        model[offset0] = value0;
        model[offset1] = value1;
    }

    for (int i = 0; i < 128 && pass; ++i) {
        const uint32_t offset = lcg_next(&sample_seed) % kPixels;
        uint8_t actual = 0;
        const uint32_t addr = kBase + offset;
        pass &= pci_read_byte_quiet(addr, 0x6u, &actual, false);
        if (actual != model[offset]) {
            std::printf("[TB] FAIL: Fizzle write sample %d addr 0x%08x expected 0x%02x got 0x%02x\n",
                        i, addr, model[offset], actual);
            pass = false;
            break;
        }
    }

    if (pass) {
        std::printf("[TB] PASS: Fizzlefade-style no-gap byte writes\n");
    }
    return pass;
}

static bool stress_fizzlefade_no_gap_byte_rmw() {
    std::printf("[TB] Stressing fizzlefade-style no-gap byte RMW...\n");

    static constexpr uint32_t kBase = 0x000AFA00u;
    static constexpr uint32_t kWindow = 4096u;
    static constexpr int kSeedWrites = 512;
    static constexpr int kOps = 512;

    bool pass = true;
    uint8_t model[kWindow] = {};
    uint32_t rndval = 1u;
    uint32_t seed = 0x00C0FFEEu;

    for (int i = 0; i < kSeedWrites && pass; ++i) {
        const uint32_t offset = fizzlefade_next_offset(&rndval) % kWindow;
        const uint32_t addr = kBase + offset;
        const uint8_t value = static_cast<uint8_t>(lcg_next(&seed) >> 24);
        pass &= pci_write(addr, 0x7u, pci_single_byte_enable(addr),
                          pci_single_byte_data(addr, value), false);
        model[offset] = value;
    }

    for (int i = 0; i < kOps && pass; ++i) {
        const uint32_t offset = fizzlefade_next_offset(&rndval) % kWindow;
        const uint32_t addr = kBase + offset;
        const uint8_t expected = model[offset];
        const uint8_t updated = static_cast<uint8_t>(expected ^ (static_cast<uint8_t>(lcg_next(&seed) >> 24) | 1u));

        uint32_t read_word = 0;
        pass &= pci_read_then_write_no_gap(addr, 0x6u, pci_single_byte_enable(addr), &read_word, false,
                                           addr, 0x7u, pci_single_byte_enable(addr),
                                           pci_single_byte_data(addr, updated), false, false);
        const uint32_t expected_word = pci_single_byte_data(addr, expected);
        if (read_word != expected_word) {
            std::printf("[TB] FAIL: Fizzle RMW read %d addr 0x%08x expected 0x%08x got 0x%08x\n",
                        i, addr, expected_word, read_word);
            pass = false;
            break;
        }

        model[offset] = updated;

        uint8_t verify = 0;
        pass &= pci_read_byte_quiet(addr, 0x6u, &verify, false);
        if (verify != updated) {
            std::printf("[TB] FAIL: Fizzle RMW verify %d addr 0x%08x expected 0x%02x got 0x%02x\n",
                        i, addr, updated, verify);
            pass = false;
            break;
        }
    }

    if (pass) {
        std::printf("[TB] PASS: Fizzlefade-style no-gap byte RMW\n");
    }
    return pass;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vpci_bridge_test_top;
    top->clk = 0;
    reset_dut();

    bool pass = true;

    std::printf("[TB] Enabling PCI I/O and memory decode...\n");
    pass &= pci_write(0x00000004u, 0xBu, 0xEu, 0x00000003u, true);

    std::printf("[TB] Exercising 16-bit aligned VGA I/O write...\n");
    pass &= pci_write(0x000003C4u, 0x3u, 0xCu, 0x00000F02u, false);
    pass &= expect_equal_u8("IO 3C4h", top->io_c_4, 0x02);
    pass &= expect_equal_u8("IO 3C5h", top->io_c_5, 0x0F);

    std::printf("[TB] Exercising 16-bit unaligned VGA I/O write...\n");
    pass &= pci_write(0x000003C5u, 0x3u, 0x9u, 0x00BBAA00u, false);
    pass &= expect_equal_u8("IO 3C5h updated", top->io_c_5, 0xAA);
    pass &= expect_equal_u8("IO 3C6h updated", top->io_c_6, 0xBB);

    std::printf("[TB] Exercising multi-byte VGA I/O read...\n");
    uint32_t io_read_data = 0;
    pass &= pci_read(0x000003C5u, 0x2u, 0x9u, &io_read_data, false);
    pass &= expect_equal_u32("IO readback 3C5h/3C6h", io_read_data, 0x00BBAA00u);

    std::printf("[TB] Exercising repeated single-byte side-effecting I/O reads...\n");
    uint32_t palette_read_0 = 0;
    uint32_t palette_read_1 = 0;
    pass &= pci_read(0x000003C9u, 0x2u, 0xDu, &palette_read_0, false);
    pass &= pci_read(0x000003C9u, 0x2u, 0xDu, &palette_read_1, false);
    pass &= expect_equal_u32("Palette read 0", palette_read_0, 0x00001000u);
    pass &= expect_equal_u32("Palette read 1", palette_read_1, 0x00001100u);

    std::printf("[TB] Exercising 32-bit VGA memory write...\n");
    pass &= pci_write(0x000B8000u, 0x7u, 0x0u, 0x2E421F41u, false);
    pass &= expect_equal_u8("MEM B8000h", top->mem_18000, 0x41);
    pass &= expect_equal_u8("MEM B8001h", top->mem_18001, 0x1F);
    pass &= expect_equal_u8("MEM B8002h", top->mem_18002, 0x42);
    pass &= expect_equal_u8("MEM B8003h", top->mem_18003, 0x2E);

    std::printf("[TB] Exercising 32-bit VGA memory read...\n");
    uint32_t mem_read_data = 0;
    pass &= pci_read(0x000B8000u, 0x6u, 0x0u, &mem_read_data, false);
    pass &= expect_equal_u32("MEM readback B8000h", mem_read_data, 0x2E421F41u);

    pass &= stress_fast_back_to_back_io();
    pass &= stress_fast_back_to_back_vram();
    pass &= stress_true_back_to_back_vram_write_read();
    pass &= stress_true_back_to_back_vram_read_write();
    pass &= stress_fizzlefade_no_gap_byte_writes();
    pass &= stress_fizzlefade_no_gap_byte_rmw();

    if (!pass) {
        std::printf("[TB] PCI bridge regression FAILED\n");
        top->final();
        delete top;
        return 1;
    }

    std::printf("[TB] PCI bridge regression PASSED\n");
    top->final();
    delete top;
    return 0;
}
