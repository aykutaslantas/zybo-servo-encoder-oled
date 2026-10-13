// servo_ctrl.v
// servo_ctrl IP'sinin top modulu.
// AXI4-Lite register blogu + encoder + aci kontrolu + servo PWM + OLED.
// OLED (SSD1305, 128x32, SPI) aci, darbe, adim ve durumu PL'den dogrudan gosterir.
//
// Saat ve reset AXI'den gelir (PS'in FCLK_CLK0'i, 100 MHz).
// Servo ancak SW0 acik VE CTRL.EN = 1 ise darbe alir.

`timescale 1ns/1ps

module servo_ctrl #(
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 5,
    parameter integer CLK_HZ               = 100_000_000,
    parameter integer EDGES_PER_DETENT     = 2,
    parameter integer OLED_COL_OFFSET      = 4
)(
    // ---------------- Dis portlar ----------------
    input  wire       enc_a,        // KY-040 CLK
    input  wire       enc_b,        // KY-040 DT
    input  wire       enc_sw,       // KY-040 SW
    input  wire       sw0,          // donanimsal etkinlestirme / acil durdurma
    output wire       servo_out,
    output wire [3:0] led,

    // OLED (Pico-OLED-2.23, SPI)
    output wire       oled_mosi,
    output wire       oled_sclk,
    output wire       oled_cs_n,
    output wire       oled_dc,
    output wire       oled_res_n,

    // ---------------- AXI4-Lite (S00_AXI) ----------------
    input  wire                                  s00_axi_aclk,
    input  wire                                  s00_axi_aresetn,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]       s00_axi_awaddr,
    input  wire [2:0]                            s00_axi_awprot,
    input  wire                                  s00_axi_awvalid,
    output wire                                  s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]       s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0]   s00_axi_wstrb,
    input  wire                                  s00_axi_wvalid,
    output wire                                  s00_axi_wready,
    output wire [1:0]                            s00_axi_bresp,
    output wire                                  s00_axi_bvalid,
    input  wire                                  s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]       s00_axi_araddr,
    input  wire [2:0]                            s00_axi_arprot,
    input  wire                                  s00_axi_arvalid,
    output wire                                  s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0]       s00_axi_rdata,
    output wire [1:0]                            s00_axi_rresp,
    output wire                                  s00_axi_rvalid,
    input  wire                                  s00_axi_rready
);

    wire clk = s00_axi_aclk;
    wire rst = ~s00_axi_aresetn;             // AXI reset aktif-dusuk

    // ------------------------------------------------------------------
    // SW0 icin senkronizor
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg sw0_s1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg sw0_s2 = 1'b0;

    always @(posedge clk) begin
        sw0_s1 <= sw0;
        sw0_s2 <= sw0_s1;
    end

    // ------------------------------------------------------------------
    // Ic sinyaller
    // ------------------------------------------------------------------
    wire               ctrl_en, center_stb, move_stb, set_stb;
    wire signed [15:0] move_deg;
    wire        [15:0] set_deg;
    wire        [7:0]  step_deg;
    wire        [11:0] min_us, max_us;

    wire        [7:0]  angle;
    wire        [11:0] pulse_us;
    wire               step, dir, btn_press, btn_level;

    wire en_eff = sw0_s2 & ctrl_en;
    wire at_min = (angle == 8'd0);
    wire at_max = (angle == 8'd180);

    // ------------------------------------------------------------------
    // AXI4-Lite register blogu
    // ------------------------------------------------------------------
    servo_ctrl_regs #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) u_regs (
        .S_AXI_ACLK   (s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR (s00_axi_awaddr),
        .S_AXI_AWPROT (s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA  (s00_axi_wdata),
        .S_AXI_WSTRB  (s00_axi_wstrb),
        .S_AXI_WVALID (s00_axi_wvalid),
        .S_AXI_WREADY (s00_axi_wready),
        .S_AXI_BRESP  (s00_axi_bresp),
        .S_AXI_BVALID (s00_axi_bvalid),
        .S_AXI_BREADY (s00_axi_bready),
        .S_AXI_ARADDR (s00_axi_araddr),
        .S_AXI_ARPROT (s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA  (s00_axi_rdata),
        .S_AXI_RRESP  (s00_axi_rresp),
        .S_AXI_RVALID (s00_axi_rvalid),
        .S_AXI_RREADY (s00_axi_rready),

        .ctrl_en   (ctrl_en),
        .center_stb(center_stb),
        .move_stb  (move_stb),
        .move_deg  (move_deg),
        .set_stb   (set_stb),
        .set_deg   (set_deg),
        .step_deg  (step_deg),
        .min_us    (min_us),
        .max_us    (max_us),

        .angle   (angle),
        .pulse_us(pulse_us),
        .status  ({en_eff, at_max, at_min})
    );

    // ------------------------------------------------------------------
    // Encoder
    // ------------------------------------------------------------------
    rotary_encoder #(
        .CLK_HZ          (CLK_HZ),
        .AB_DEBOUNCE_US  (500),
        .SW_DEBOUNCE_US  (10_000),
        .EDGES_PER_DETENT(EDGES_PER_DETENT),
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

    // ------------------------------------------------------------------
    // Aci kontrolu
    // ------------------------------------------------------------------
    angle_ctrl_rt #(
        .INIT_DEG(90)
    ) u_ctrl (
        .clk     (clk),
        .rst     (rst),
        .step    (step),
        .dir     (dir),
        .center  (btn_press | center_stb),
        .move_stb(move_stb),
        .move_deg(move_deg),
        .set_stb (set_stb),
        .set_deg (set_deg),
        .step_deg(step_deg),
        .min_us  (min_us),
        .max_us  (max_us),
        .angle   (angle),
        .pulse_us(pulse_us)
    );

    // ------------------------------------------------------------------
    // Servo PWM
    // ------------------------------------------------------------------
    servo_pwm #(
        .CLK_HZ   (CLK_HZ),
        .PERIOD_US(20_000)
    ) u_pwm (
        .clk     (clk),
        .rst     (rst),
        .en      (en_eff),
        .pulse_us(pulse_us),
        .pwm_out (servo_out)
    );

    // ------------------------------------------------------------------
    // OLED
    // ------------------------------------------------------------------
    wire [1:0] oled_page;
    wire [6:0] oled_col;
    wire [7:0] oled_pix;
    wire       oled_frame, oled_ready;

    oled_ctrl #(
        .CLK_HZ    (CLK_HZ),
        .HALF_DIV  (CLK_HZ / 10_000_000),     // ~5 MHz SPI saati
        .COL_OFFSET(OLED_COL_OFFSET),
        .PIX_LAT   (3)
    ) u_oled (
        .clk        (clk),
        .rst        (rst),
        .page       (oled_page),
        .col        (oled_col),
        .pix        (oled_pix),
        .frame_start(oled_frame),
        .ready      (oled_ready),
        .contrast   (8'h80),
        .disp_on    (1'b1),
        .oled_sclk  (oled_sclk),
        .oled_mosi  (oled_mosi),
        .oled_dc    (oled_dc),
        .oled_cs_n  (oled_cs_n),
        .oled_res_n (oled_res_n)
    );

    oled_text u_text (
        .clk        (clk),
        .frame_start(oled_frame),
        .angle      (angle),
        .pulse_us   (pulse_us),
        .step_deg   (step_deg),
        .en         (en_eff),
        .at_min     (at_min),
        .at_max     (at_max),
        .page       (oled_page),
        .col        (oled_col),
        .pix        (oled_pix)
    );

    assign led = {servo_out, at_max, at_min, en_eff};

endmodule
