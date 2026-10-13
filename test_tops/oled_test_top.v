// oled_test_top.v
// PS'siz kart testi: OLED'e test deseni gonderir.
//
//  BTN0 : reset (ekran da yeniden baslatilir)
//  LED0 : acilis bitti, kareler gidiyor
//  LED1 : her karede yanip soner (kare sayacinin bir biti)
//
//  OLED baglantisi Pmod JC:
//    JC1 -> DIN, JC2 -> CLK, JC3 -> CS, JC4 -> DC, JC7 -> RST
//    JC6 (3.3 V) -> VCC/VSYS,  JC5 (GND) -> GND

`timescale 1ns/1ps

module oled_test_top (
    input  wire       clk,          // 125 MHz, K17
    input  wire       btn0,
    output wire [3:0] led,

    output wire       oled_mosi,
    output wire       oled_sclk,
    output wire       oled_cs_n,
    output wire       oled_dc,
    output wire       oled_res_n
);

    (* ASYNC_REG = "TRUE" *) reg rst_s1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg rst_s2 = 1'b0;

    always @(posedge clk) begin
        rst_s1 <= btn0;
        rst_s2 <= rst_s1;
    end

    wire       rst = rst_s2;
    wire [1:0] page;
    wire [6:0] col;
    wire [7:0] pix;
    wire       frame_start, ready;

    oled_ctrl #(
        .CLK_HZ    (125_000_000),
        .HALF_DIV  (13),            // 125 MHz / 26 = 4.8 MHz SCLK
        .COL_OFFSET(4)
    ) u_oled (
        .clk        (clk),
        .rst        (rst),
        .page       (page),
        .col        (col),
        .pix        (pix),
        .frame_start(frame_start),
        .ready      (ready),
        .contrast   (8'h80),
        .disp_on    (1'b1),
        .oled_sclk  (oled_sclk),
        .oled_mosi  (oled_mosi),
        .oled_dc    (oled_dc),
        .oled_cs_n  (oled_cs_n),
        .oled_res_n (oled_res_n)
    );

    oled_pattern u_pat (
        .clk (clk),
        .page(page),
        .col (col),
        .pix (pix)
    );

    // Kare sayaci: LED1 her ~16 karede bir durum degistirir (~2 Hz)
    reg [4:0] frames = 5'd0;
    always @(posedge clk) if (frame_start) frames <= frames + 5'd1;

    assign led = {2'b00, frames[4], ready};

endmodule
