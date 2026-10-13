// oled_text.v
// oled_ctrl icin piksel ureteci: 2 satir x 16 karakterlik metni, 8x16 fontla
// framebuffer kullanmadan, istenen (sayfa, sutun) icin aninda cizer.
//
//   satir 0:  "ACI 135  ETKIN  "     (sinirdaysa aciya bitisik '<' veya '>')
//   satir 1:  "1500us  ADIM  5 "
//
//   metin satiri = page[1],  karakterin yarisi = page[0]
//   karakter     = col[6:3], karakter ici sutun = col[2:0]
//
// Degerler frame_start aninda kopyalanir: kare ortasinda degisen deger
// yarim guncellenmis bir goruntu olusturmaz.
// Gecikme: page/col -> pix 2 cevrim (oled_ctrl PIX_LAT >= 2 olmali).

`timescale 1ns/1ps

module oled_text (
    input  wire        clk,
    input  wire        frame_start,

    // Gosterilecek degerler
    input  wire [7:0]  angle,
    input  wire [11:0] pulse_us,
    input  wire [7:0]  step_deg,
    input  wire        en,
    input  wire        at_min,
    input  wire        at_max,

    // oled_ctrl arayuzu
    input  wire [1:0]  page,
    input  wire [6:0]  col,
    output wire [7:0]  pix
);

    // ------------------------------------------------------------------
    // Kare basinda degerlerin kopyasi
    // ------------------------------------------------------------------
    reg [7:0]  s_angle = 8'd90;
    reg [11:0] s_pulse = 12'd1500;
    reg [7:0]  s_step  = 8'd5;
    reg        s_en = 1'b0, s_min = 1'b0, s_max = 1'b0;

    always @(posedge clk) if (frame_start) begin
        s_angle <= angle;
        s_pulse <= pulse_us;
        s_step  <= step_deg;
        s_en    <= en;
        s_min   <= at_min;
        s_max   <= at_max;
    end

    // ------------------------------------------------------------------
    // Ikili -> ondalik (kopyadan, sonucu register'a al)
    // ------------------------------------------------------------------
    wire [3:0] a3, a2, a1, a0, p3, p2, p1, p0, t3, t2, t1, t0;

    bin2bcd u_bcd_a (.bin({4'd0, s_angle}), .d3(a3), .d2(a2), .d1(a1), .d0(a0));
    bin2bcd u_bcd_p (.bin(s_pulse),         .d3(p3), .d2(p2), .d1(p1), .d0(p0));
    bin2bcd u_bcd_t (.bin({4'd0, s_step}),  .d3(t3), .d2(t2), .d1(t1), .d0(t0));

    reg [3:0] ang_h, ang_t, ang_o, pul_th, pul_h, pul_t, pul_o, stp_t, stp_o;

    always @(posedge clk) begin
        ang_h  <= a2;  ang_t <= a1;  ang_o <= a0;
        pul_th <= p3;  pul_h <= p2;  pul_t <= p1;  pul_o <= p0;
        stp_t  <= t1;  stp_o <= t0;
    end

    // ------------------------------------------------------------------
    // Karakter secimi
    // ------------------------------------------------------------------
    localparam [6:0] SP = 7'h20;

    function [6:0] dig(input [3:0] d);          // basamak -> ASCII rakam
        dig = 7'h30 + {3'd0, d};
    endfunction

    wire       line = page[1];
    wire [3:0] cidx = col[6:3];
    reg  [6:0] ch;

    always @(*) begin
        ch = SP;
        if (line == 1'b0) begin
            case (cidx)
                4'd0:  ch = "A";
                4'd1:  ch = "C";
                4'd2:  ch = "I";
                4'd4:  ch = (ang_h == 0)                 ? SP : dig(ang_h);
                4'd5:  ch = (ang_h == 0 && ang_t == 0)   ? SP : dig(ang_t);
                4'd6:  ch = dig(ang_o);
                4'd7:  ch = s_min ? "<" : (s_max ? ">" : SP);
                4'd9:  ch = s_en ? "E" : "K";
                4'd10: ch = s_en ? "T" : "A";
                4'd11: ch = s_en ? "K" : "P";
                4'd12: ch = s_en ? "I" : "A";
                4'd13: ch = s_en ? "N" : "L";
                4'd14: ch = s_en ? SP  : "I";
                default: ch = SP;
            endcase
        end else begin
            case (cidx)
                4'd0:  ch = (pul_th == 0) ? SP : dig(pul_th);
                4'd1:  ch = dig(pul_h);
                4'd2:  ch = dig(pul_t);
                4'd3:  ch = dig(pul_o);
                4'd4:  ch = "u";
                4'd5:  ch = "s";
                4'd8:  ch = "A";
                4'd9:  ch = "D";
                4'd10: ch = "I";
                4'd11: ch = "M";
                4'd13: ch = (stp_t == 0) ? SP : dig(stp_t);
                4'd14: ch = dig(stp_o);
                default: ch = SP;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Font: karakter kodunu ve karakter ici konumu bir cevrim tut, sonra ROM
    // ------------------------------------------------------------------
    reg [6:0] ch_r;
    reg       half_r;
    reg [2:0] x_r;

    always @(posedge clk) begin
        ch_r   <= ch;
        half_r <= page[0];
        x_r    <= col[2:0];
    end

    font_rom u_font (
        .clk (clk),
        .ch  (ch_r),
        .half(half_r),
        .x   (x_r),
        .data(pix)
    );

endmodule
