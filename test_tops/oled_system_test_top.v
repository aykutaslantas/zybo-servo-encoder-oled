// oled_system_test_top.v
// PS'siz kart testi: encoder + aci kontrolu + servo + OLED birlikte.
// IP'ye eklemeden once OLED metninin gercek degerlerle dogru gorundugunu
// kontrol etmek icin. servo_ctrl IP'sindeki baglantilarin aynisi, AXI'siz.
//
//  SW0  : servo etkin (OLED'de ETKIN / KAPALI)
//  BTN0 : reset
//  Encoder: JE,  Servo: JD1,  OLED: JC

`timescale 1ns/1ps

module oled_system_test_top (
    input  wire       clk,          // 125 MHz
    input  wire       btn0,
    input  wire       sw0,
    input  wire       enc_a,
    input  wire       enc_b,
    input  wire       enc_sw,
    output wire       servo_out,
    output wire [3:0] led,

    output wire       oled_mosi,
    output wire       oled_sclk,
    output wire       oled_cs_n,
    output wire       oled_dc,
    output wire       oled_res_n
);

    localparam integer CLK_HZ = 125_000_000;

    (* ASYNC_REG = "TRUE" *) reg [1:0] s1 = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] s2 = 2'b00;
    always @(posedge clk) begin
        s1 <= {sw0, btn0};
        s2 <= s1;
    end
    wire rst = s2[0];
    wire en  = s2[1];

    // Encoder
    wire step, dir, btn_press, btn_level;
    rotary_encoder #(.CLK_HZ(CLK_HZ), .EDGES_PER_DETENT(2)) u_enc (
        .clk(clk), .rst(rst), .enc_a(enc_a), .enc_b(enc_b), .enc_sw(enc_sw),
        .step(step), .dir(dir), .btn_press(btn_press), .btn_level(btn_level)
    );

    // Aci kontrolu (IP'deki ile ayni modul, PS komutlari baglanmamis)
    wire [7:0]  angle;
    wire [11:0] pulse_us;
    angle_ctrl_rt #(.INIT_DEG(90)) u_ctrl (
        .clk(clk), .rst(rst),
        .step(step), .dir(dir), .center(btn_press),
        .move_stb(1'b0), .move_deg(16'sd0), .set_stb(1'b0), .set_deg(16'd0),
        .step_deg(8'd5), .min_us(12'd500), .max_us(12'd2500),
        .angle(angle), .pulse_us(pulse_us)
    );

    // Servo
    servo_pwm #(.CLK_HZ(CLK_HZ)) u_pwm (
        .clk(clk), .rst(rst), .en(en), .pulse_us(pulse_us), .pwm_out(servo_out)
    );

    // OLED
    wire [1:0] page;
    wire [6:0] col;
    wire [7:0] pix;
    wire       frame_start, oled_ready;

    oled_ctrl #(
        .CLK_HZ(CLK_HZ), .HALF_DIV(13), .COL_OFFSET(4), .PIX_LAT(3)
    ) u_oled (
        .clk(clk), .rst(rst),
        .page(page), .col(col), .pix(pix),
        .frame_start(frame_start), .ready(oled_ready),
        .contrast(8'h80), .disp_on(1'b1),
        .oled_sclk(oled_sclk), .oled_mosi(oled_mosi), .oled_dc(oled_dc),
        .oled_cs_n(oled_cs_n), .oled_res_n(oled_res_n)
    );

    oled_text u_text (
        .clk(clk), .frame_start(frame_start),
        .angle(angle), .pulse_us(pulse_us), .step_deg(8'd5),
        .en(en), .at_min(angle == 8'd0), .at_max(angle == 8'd180),
        .page(page), .col(col), .pix(pix)
    );

    assign led = {servo_out, (angle == 8'd180), (angle == 8'd0), oled_ready};

endmodule
