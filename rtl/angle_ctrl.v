// angle_ctrl.v
// Hedef aci register'i ve aci -> darbe genisligi donusumu.
//
//  - Aci 0..180 araliginda tutulur, acilista INIT_DEG.
//  - Her step darbesinde dir'e gore STEP_DEG kadar artar/azalir,
//    sinirlarda doyar (tasmaz).
//  - center darbesi aciyi INIT_DEG'e dondurur.
//  - pulse_us = MIN_US + aci * (MAX_US - MIN_US) / 180
//    Oran Q8 sabit noktali olarak sentez aninda hesaplanir; calisma aninda
//    sadece bir carpma ve kaydirma vardir.

`timescale 1ns/1ps

module angle_ctrl #(
    parameter integer MIN_US   = 1000,   // 0 derece darbe genisligi
    parameter integer MAX_US   = 2000,   // 180 derece darbe genisligi
    parameter integer STEP_DEG = 5,      // tik basina aci degisimi
    parameter integer INIT_DEG = 90      // acilis / ortalama acisi
)(
    input  wire        clk,
    input  wire        rst,        // senkron, aktif-yuksek
    input  wire        step,       // tek cevrimlik tik darbesi
    input  wire        dir,        // 1 = artir, 0 = azalt
    input  wire        center,     // tek cevrimlik ortalama darbesi
    output reg  [7:0]  angle,      // 0..180
    output reg  [11:0] pulse_us
);

    // us/derece orani, 256 ile carpilmis (Q8), yuvarlanmis
    localparam integer K_Q8 = ((MAX_US - MIN_US) * 256 + 90) / 180;

    initial angle = INIT_DEG;

    // ------------------------------------------------------------------
    // Aci register'i
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst || center) begin
            angle <= INIT_DEG;
        end else if (step) begin
            if (dir) begin
                if (angle > 180 - STEP_DEG) angle <= 8'd180;          // ust sinirda doy
                else                        angle <= angle + STEP_DEG;
            end else begin
                if (angle < STEP_DEG)       angle <= 8'd0;            // alt sinirda doy
                else                        angle <= angle - STEP_DEG;
            end
        end
    end

    // ------------------------------------------------------------------
    // Aci -> darbe genisligi (Q8 carpma, +128 ile yuvarlama, >> 8)
    // ------------------------------------------------------------------
    wire [23:0] prod = angle * K_Q8;

    always @(posedge clk) begin
        pulse_us <= MIN_US + ((prod + 24'd128) >> 8);
    end

endmodule
