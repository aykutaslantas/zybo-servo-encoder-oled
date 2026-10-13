// oled_pattern.v
// OLED icin test deseni: cerceve + sol ustte dolu kare + 16 sutunda bir noktali cizgi.
//  - Cercevenin dort kenari da gorunuyorsa sutun/sayfa kaymasi dogru.
//  - Dolu kare sol ustteyse ekran ters donmemis.
// Bir cevrim gecikmeli (registered) cikis.

`timescale 1ns/1ps

module oled_pattern (
    input  wire       clk,
    input  wire [1:0] page,
    input  wire [6:0] col,
    output reg  [7:0] pix
);

    reg [7:0] b;

    always @(*) begin
        b = 8'h00;
        if (col[3:0] == 4'd0)               b = 8'h55;          // noktali dikey cizgi
        if (page == 2'd0)                   b = b | 8'h01;      // ust kenar (satir 0)
        if (page == 2'd3)                   b = b | 8'h80;      // alt kenar (satir 31)
        if (col == 7'd0 || col == 7'd127)   b = 8'hFF;          // sol ve sag kenar
        if (page == 2'd0 && col < 7'd16)    b = 8'hFF;          // sol ustte dolu kare
    end

    always @(posedge clk) pix <= b;

endmodule
