// angle_ctrl_rt.v
// Calisma aninda ayarlanabilen hedef aci register'i ve aci -> darbe donusumu.
//
// Aciyi degistiren kaynaklar (oncelik sirasiyla):
//   1) rst / center : aci = INIT_DEG
//   2) set_stb      : aci = set_deg            (mutlak, PS'ten)
//   3) move_stb     : aci = aci + move_deg     (goreceli, isaretli, PS'ten)
//   4) step         : aci = aci +/- step_deg   (encoder tiki)
// Sonuc her zaman 0..180 araligina doyurulur.
//
// Darbe:  pulse_us = min_us + (max_us - min_us) * aci / 180
// 180'e bolme yerine: x / 180  ~=  (x * 2913) >> 19   (hata < 1 us)
// Iki asamali pipeline: degisiklik cikisa 3 saat cevriminde yansir.

`timescale 1ns/1ps

module angle_ctrl_rt #(
    parameter integer INIT_DEG = 90
)(
    input  wire               clk,
    input  wire               rst,        // senkron, aktif-yuksek

    // Encoder
    input  wire               step,       // tek cevrimlik tik darbesi
    input  wire               dir,        // 1 = artir, 0 = azalt
    input  wire               center,     // tek cevrimlik ortalama darbesi

    // PS komutlari (tek cevrimlik strobe + deger)
    input  wire               move_stb,
    input  wire signed [15:0] move_deg,   // goreceli, isaretli
    input  wire               set_stb,
    input  wire        [15:0] set_deg,    // mutlak, 180'den buyukse 180

    // Ayarlar
    input  wire        [7:0]  step_deg,
    input  wire        [11:0] min_us,
    input  wire        [11:0] max_us,

    output reg         [7:0]  angle,      // 0..180
    output reg         [11:0] pulse_us
);

    initial angle = INIT_DEG;

    // ------------------------------------------------------------------
    // Bir sonraki aci: isaretli 18 bitte hesapla, sonra 0..180'e doyur
    // ------------------------------------------------------------------
    wire signed [17:0] a_s  = {10'd0, angle};
    wire signed [17:0] mv_s = {{2{move_deg[15]}}, move_deg};
    wire signed [17:0] st_s = {10'd0, step_deg};

    reg signed [17:0] nxt;
    always @(*) begin
        if (move_stb)  nxt = a_s + mv_s;
        else if (step) nxt = dir ? (a_s + st_s) : (a_s - st_s);
        else           nxt = a_s;
    end

    wire [7:0] nxt_sat = (nxt < 0)   ? 8'd0   :
                         (nxt > 180) ? 8'd180 :
                                       nxt[7:0];

    wire [7:0] set_sat = (set_deg > 16'd180) ? 8'd180 : set_deg[7:0];

    always @(posedge clk) begin
        if (rst || center) angle <= INIT_DEG;
        else if (set_stb)  angle <= set_sat;
        else               angle <= nxt_sat;
    end

    // ------------------------------------------------------------------
    // Aci -> darbe genisligi (2 asamali pipeline)
    // ------------------------------------------------------------------
    wire [11:0] span = (max_us > min_us) ? (max_us - min_us) : 12'd0;

    reg [19:0] p1;   // span * aci          (en fazla 4095 * 180)
    reg [31:0] p2;   // p1 * 2913           (< 2^31)

    always @(posedge clk) begin
        p1       <= span * angle;
        p2       <= p1 * 32'd2913;
        pulse_us <= min_us + ((p2 + 32'd262144) >> 19);   // +2^18: yuvarlama
    end

endmodule
