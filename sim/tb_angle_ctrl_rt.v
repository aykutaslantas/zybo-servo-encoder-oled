// tb_angle_ctrl_rt.v
// angle_ctrl_rt icin kendi kendini kontrol eden testbench.
// Vivado'da: Run Simulation -> "run all"

`timescale 1ns/1ps

module tb_angle_ctrl_rt;

    reg clk = 1'b0;
    always #5 clk = ~clk;                       // 100 MHz

    reg               rst = 1'b1;
    reg               step = 1'b0, dir = 1'b0, center = 1'b0;
    reg               move_stb = 1'b0, set_stb = 1'b0;
    reg  signed [15:0] move_deg = 16'sd0;
    reg         [15:0] set_deg  = 16'd0;
    reg         [7:0]  step_deg = 8'd5;
    reg         [11:0] min_us   = 12'd500;
    reg         [11:0] max_us   = 12'd2500;
    wire        [7:0]  angle;
    wire        [11:0] pulse_us;

    angle_ctrl_rt #(.INIT_DEG(90)) dut (
        .clk(clk), .rst(rst),
        .step(step), .dir(dir), .center(center),
        .move_stb(move_stb), .move_deg(move_deg),
        .set_stb(set_stb), .set_deg(set_deg),
        .step_deg(step_deg), .min_us(min_us), .max_us(max_us),
        .angle(angle), .pulse_us(pulse_us)
    );

    integer errors = 0;
    integer i;

    // ------------------------------------------------------------------
    // Uyari uretecleri (hepsi tek cevrimlik)
    // ------------------------------------------------------------------
    task settle; begin repeat (6) @(posedge clk); end endtask

    task ticks(input integer n, input d);
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk); step <= 1'b1; dir <= d;
                @(posedge clk); step <= 1'b0;
            end
            settle;
        end
    endtask

    task move(input integer deg);
        begin
            @(posedge clk); move_stb <= 1'b1; move_deg <= deg;
            @(posedge clk); move_stb <= 1'b0;
            settle;
        end
    endtask

    task set_abs(input integer deg);
        begin
            @(posedge clk); set_stb <= 1'b1; set_deg <= deg;
            @(posedge clk); set_stb <= 1'b0;
            settle;
        end
    endtask

    task do_center;
        begin
            @(posedge clk); center <= 1'b1;
            @(posedge clk); center <= 1'b0;
            settle;
        end
    endtask

    // ------------------------------------------------------------------
    // Kontrol: aci tam, darbe ideal degere +/-1 us
    // ------------------------------------------------------------------
    task check(input [8*28-1:0] name, input integer exp_angle);
        real ideal;
        begin
            ideal = min_us + exp_angle * (max_us - min_us) / 180.0;
            if (angle != exp_angle || pulse_us < ideal - 1.0 || pulse_us > ideal + 1.0) begin
                $display("[FAIL] %0s: aci=%0d darbe=%0d us, beklenen aci=%0d darbe~%0.1f us",
                         name, angle, pulse_us, exp_angle, ideal);
                errors = errors + 1;
            end else begin
                $display("[ OK ] %0s: aci=%0d darbe=%0d us", name, angle, pulse_us);
            end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
        settle;

        $display("--- Encoder ---");
        check("acilis", 90);
        ticks(3, 1'b1);   check("3 tik ileri", 105);
        ticks(2, 1'b0);   check("2 tik geri", 95);
        step_deg = 8'd10;
        ticks(1, 1'b1);   check("adim 10, 1 tik ileri", 105);
        step_deg = 8'd5;

        $display("--- MOVE (goreceli) ---");
        move(30);         check("+30", 135);
        move(-45);        check("-45", 90);
        move(1000);       check("+1000 ust doyma", 180);
        move(-500);       check("-500 alt doyma", 0);
        move(-1);         check("0'da -1", 0);

        $display("--- ANGLE (mutlak) ---");
        set_abs(45);      check("=45", 45);
        set_abs(300);     check("=300 doyma", 180);
        set_abs(0);       check("=0", 0);

        $display("--- Ortalama ---");
        move(20);
        do_center;        check("center", 90);

        $display("--- Kalibrasyon degisimi ---");
        min_us = 12'd1000; max_us = 12'd2000; settle;
        check("min1000 max2000, 90", 90);
        set_abs(180);     check("min1000 max2000, 180", 180);
        set_abs(0);       check("min1000 max2000, 0", 0);
        set_abs(37);      check("min1000 max2000, 37", 37);

        min_us = 12'd500; max_us = 12'd2500;
        for (i = 0; i <= 180; i = i + 1) begin : sweep
            @(posedge clk); set_stb <= 1'b1; set_deg <= i;
            @(posedge clk); set_stb <= 1'b0;
            settle;
            if (pulse_us < 500 + i * 2000 / 180.0 - 1.0 ||
                pulse_us > 500 + i * 2000 / 180.0 + 1.0) begin
                $display("[FAIL] tarama: aci=%0d darbe=%0d", i, pulse_us);
                errors = errors + 1;
            end
        end
        $display("[ OK ] 0..180 tarama tamam (hatali deger yukarida listelenir)");

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
