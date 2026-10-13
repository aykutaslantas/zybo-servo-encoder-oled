// servo_test_top.v
// PS'siz kart testi: servo_pwm modulunu switch'lerle surer.
//
//  SW0      : servo etkin (kapaliyken hic darbe yok)
//  SW2:SW1  : 00 -> notr (1500 us), 01 -> nötr - ofset, 10 -> notr + ofset, 11 -> notr
//  SW3      : ofset = 100 us (kapali) / 200 us (acik)
//  BTN0     : reset
//  LED0     : etkin, LED1: PWM sinyali (sonuk yanar), LED2-3: yon secimi

`timescale 1ns/1ps

module servo_test_top (
    input  wire       clk,         // 125 MHz, K17
    input  wire [3:0] sw,
    input  wire       btn0,
    output wire [3:0] led,
    output wire       servo_out    // Pmod JD1
);

    localparam integer NEUTRAL_US = 1500;

    // ------------------------------------------------------------------
    // Asenkron girisler icin 2-FF senkronizor
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [4:0] sync1;
    (* ASYNC_REG = "TRUE" *) reg [4:0] sync2;

    always @(posedge clk) begin
        sync1 <= {btn0, sw};
        sync2 <= sync1;
    end

    wire [3:0] sw_s = sync2[3:0];
    wire       rst  = sync2[4];

    // ------------------------------------------------------------------
    // Darbe genisligi secimi
    // ------------------------------------------------------------------
    wire [11:0] offset_us = sw_s[3] ? 12'd200 : 12'd100;
    reg  [11:0] pulse_sel;

    always @(*) begin
        case (sw_s[2:1])
            2'b01:   pulse_sel = NEUTRAL_US - offset_us;
            2'b10:   pulse_sel = NEUTRAL_US + offset_us;
            default: pulse_sel = NEUTRAL_US;
        endcase
    end

    // ------------------------------------------------------------------
    // Servo PWM
    // ------------------------------------------------------------------
    servo_pwm #(
        .CLK_HZ   (125_000_000),
        .PERIOD_US(20_000)
    ) u_servo_pwm (
        .clk     (clk),
        .rst     (rst),
        .en      (sw_s[0]),
        .pulse_us(pulse_sel),
        .pwm_out (servo_out)
    );

    assign led = {sw_s[2], sw_s[1], servo_out, sw_s[0]};

endmodule
