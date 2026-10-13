// encoder_test_top.v
// PS'siz kart testi: KY-040'in her tiki 4 bitlik bir sayaci artirir/azaltir,
// sayac LED'lerde ikili olarak gorunur.
//
//  Encoder ileri -> sayac +1,  geri -> sayac -1  (0..15, tasarak doner)
//  Encoder butonu -> sayac sifirlanir
//  BTN0           -> reset

`timescale 1ns/1ps

module encoder_test_top (
    input  wire       clk,       // 125 MHz, K17
    input  wire       btn0,
    input  wire       enc_a,     // JE1 <- KY-040 CLK
    input  wire       enc_b,     // JE2 <- KY-040 DT
    input  wire       enc_sw,    // JE3 <- KY-040 SW
    output wire [3:0] led
);

    // Reset butonu icin senkronizor
    (* ASYNC_REG = "TRUE" *) reg rst_s1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg rst_s2 = 1'b0;

    always @(posedge clk) begin
        rst_s1 <= btn0;
        rst_s2 <= rst_s1;
    end

    wire rst = rst_s2;

    // Encoder
    wire step, dir, btn_press, btn_level;

    rotary_encoder #(
        .CLK_HZ          (125_000_000),
        .AB_DEBOUNCE_US  (500),
        .SW_DEBOUNCE_US  (10_000),
        .EDGES_PER_DETENT(4),
        .INVERT_DIR      (0)
    ) u_enc (
        .clk      (clk),
        .rst      (rst),
        .enc_a    (enc_a),
        .enc_b    (enc_b),
        .enc_sw   (enc_sw),
        .step     (step),
        .dir      (dir),
        .btn_press(btn_press),
        .btn_level(btn_level)
    );

    // Sayac
    reg [3:0] count = 4'd0;

    always @(posedge clk) begin
        if (rst || btn_press)
            count <= 4'd0;
        else if (step)
            count <= dir ? count + 4'd1 : count - 4'd1;
    end

    assign led = count;

endmodule
