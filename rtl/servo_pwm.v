// servo_pwm.v
// Surekli donen (360 derece) servo icin 50 Hz PWM ureteci.
//
//  - Darbe genisligi mikrosaniye cinsinden verilir; modul saat frekansindan
//    bagimsizdir. CLK_HZ, 1 MHz'in tam kati olmali (100 MHz, 125 MHz gibi).
//  - Yeni pulse_us degeri sadece periyot basinda alinir (golge register),
//    boylece periyot ortasindaki degisiklik bozuk darbe uretmez.
//  - en=0 iken bir sonraki periyottan itibaren hic darbe uretilmez.

`timescale 1ns/1ps

module servo_pwm #(
    parameter integer CLK_HZ    = 100_000_000,
    parameter integer PERIOD_US = 20_000          // 20 ms = 50 Hz
)(
    input  wire        clk,
    input  wire        rst,        // senkron, aktif-yuksek
    input  wire        en,
    input  wire [11:0] pulse_us,   // 0..4095 us
    output reg         pwm_out
);

    localparam integer TICK_DIV = CLK_HZ / 1_000_000;   // 1 us icin gereken cevrim

    // ------------------------------------------------------------------
    // 1 us tick ureteci: her TICK_DIV cevrimde bir cevrimlik darbe
    // ------------------------------------------------------------------
    reg [7:0] div_cnt;
    reg       us_tick;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt <= 8'd0;
            us_tick <= 1'b0;
        end else if (div_cnt == TICK_DIV - 1) begin
            div_cnt <= 8'd0;
            us_tick <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 8'd1;
            us_tick <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Periyot sayaci (us) ve golge register
    // ------------------------------------------------------------------
    reg [15:0] us_cnt;
    reg [11:0] pulse_shadow;

    always @(posedge clk) begin
        if (rst) begin
            us_cnt       <= 16'd0;
            pulse_shadow <= 12'd0;
        end else if (us_tick) begin
            if (us_cnt == PERIOD_US - 1) begin
                us_cnt       <= 16'd0;
                pulse_shadow <= en ? pulse_us : 12'd0;   // periyot basinda yukle
            end else begin
                us_cnt <= us_cnt + 16'd1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Cikis: us_cnt < pulse_shadow oldugu surece yuksek
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pwm_out <= 1'b0;
        else
            pwm_out <= ({4'd0, pulse_shadow} > us_cnt);
    end

endmodule
