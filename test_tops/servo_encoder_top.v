// servo_encoder_top.v
// PS'siz sistem: KY-040 encoder ile MG995 servoyu surer.
//
//  Encoder saat yonu   -> aci artar (STEP_DEG kadar)
//  Encoder ters yon    -> aci azalir
//  Encoder butonu      -> aci 90'a (orta) doner
//  SW0                 -> servo etkin (kapaliyken darbe yok)
//  BTN0                -> reset
//  LED0: etkin, LED1: alt sinirda (0), LED2: ust sinirda (180), LED3: PWM

`timescale 1ns/1ps

module servo_encoder_top (
    input  wire       clk,         // 125 MHz, K17
    input  wire       btn0,
    input  wire       sw0,
    input  wire       enc_a,       // JE1 <- KY-040 CLK
    input  wire       enc_b,       // JE2 <- KY-040 DT
    input  wire       enc_sw,      // JE3 <- KY-040 SW
    output wire [3:0] led,
    output wire       servo_out    // JD1 -> servo sinyal
);

    localparam integer CLK_HZ = 125_000_000;

    // ------------------------------------------------------------------
    // Reset ve SW0 icin senkronizor
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync1 = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync2 = 2'b00;

    always @(posedge clk) begin
        sync1 <= {sw0, btn0};
        sync2 <= sync1;
    end

    wire rst = sync2[0];
    wire en  = sync2[1];

    // ------------------------------------------------------------------
    // Encoder
    // ------------------------------------------------------------------
    wire step, dir, btn_press, btn_level;

    rotary_encoder #(
        .CLK_HZ          (CLK_HZ),
        .AB_DEBOUNCE_US  (500),
        .SW_DEBOUNCE_US  (10_000),
        .EDGES_PER_DETENT(2),
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
    wire [7:0]  angle;
    wire [11:0] pulse_us;

    angle_ctrl #(
        .MIN_US  (500),      // kartta olculen guvenli aralik
        .MAX_US  (2500),
        .STEP_DEG(5),
        .INIT_DEG(90)
    ) u_ctrl (
        .clk     (clk),
        .rst     (rst),
        .step    (step),
        .dir     (dir),
        .center  (btn_press),
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
        .en      (en),
        .pulse_us(pulse_us),
        .pwm_out (servo_out)
    );

    assign led = {servo_out, (angle == 8'd180), (angle == 8'd0), en};

endmodule
