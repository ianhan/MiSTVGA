// 100 MHz input clock to 25 MHz pixel clock for Arria V GX.
// At 25 MHz, vga_ce fires every cycle (matching the standard VGA
// 25.175 MHz dot clock within monitor tolerance).
//
// Direct altera_pll instantiation so the netlist does not depend on
// IP-Catalog-generated wrappers.

`default_nettype none

module a5gx_mistvga_pll (
    input  wire areset,
    input  wire inclk0,
    output wire c0,
    output wire locked
);

    wire [0:0] outclk_wire;
    assign c0 = outclk_wire[0];

    altera_pll #(
        .fractional_vco_multiplier  ("false"),
        .reference_clock_frequency  ("100.0 MHz"),
        .operation_mode             ("direct"),
        .number_of_clocks           (1),
        .output_clock_frequency0    ("25.000000 MHz"),
        .phase_shift0               ("0 ps"),
        .duty_cycle0                (50),
        .pll_type                   ("General"),
        .pll_subtype                ("General")
    ) u_altera_pll (
        .rst        (areset),
        .refclk     (inclk0),
        .fbclk      (1'b0),
        .outclk     (outclk_wire),
        .fboutclk   (),
        .locked     (locked)
    );

endmodule

`default_nettype wire
