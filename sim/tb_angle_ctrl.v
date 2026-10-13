// tb_angle_ctrl.v
// angle_ctrl icin kendi kendini kontrol eden testbench.
// Vivado'da: Run Simulation -> "run all"

`timescale 1ns/1ps

module tb_angle_ctrl;

    localparam integer MIN_US   = 1000;
    localparam integer MAX_US   = 2000;
    localparam integer STEP_DEG = 5;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg  rst = 1'b1, step = 1'b0, dir = 1'b0, center = 1'b0;
    wire [7:0]  angle;
    wire [11:0] pulse_us;

    angle_ctrl #(
        .MIN_US(MIN_US), .MAX_US(MAX_US), .STEP_DEG(STEP_DEG), .INIT_DEG(90)
    ) dut (
        .clk(clk), .rst(rst), .step(step), .dir(dir), .center(center),
        .angle(angle), .pulse_us(pulse_us)
    );

    integer errors = 0;
    integer i;

    // n tik uret (tek cevrimlik step darbeleri)
    task ticks(input integer n, input d);
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk); step <= 1'b1; dir <= d;
                @(posedge clk); step <= 1'b0;
                repeat (3) @(posedge clk);
            end
            repeat (3) @(posedge clk);       // pulse_us'in guncellenmesini bekle
        end
    endtask

    task check(input [8*24-1:0] name, input integer exp_angle);
        real ideal;
        begin
            ideal = MIN_US + exp_angle * (MAX_US - MIN_US) / 180.0;
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
        repeat (3) @(posedge clk);

        check("acilis", 90);

        ticks(3, 1'b1);   check("3 tik ileri", 105);
        ticks(30, 1'b1);  check("ust sinirda doyma", 180);
        ticks(2, 1'b0);   check("2 tik geri", 170);
        ticks(50, 1'b0);  check("alt sinirda doyma", 0);

        @(posedge clk); center <= 1'b1;
        @(posedge clk); center <= 1'b0;
        repeat (3) @(posedge clk);
        check("ortalama", 90);

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
