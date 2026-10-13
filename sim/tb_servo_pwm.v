// tb_servo_pwm.v
// servo_pwm icin kendi kendini kontrol eden testbench.
// Vivado'da: Run Simulation -> Tcl konsolunda "run all"
// (simulasyon ~250 ms surer, $finish ile kendisi durur)

`timescale 1ns/1ps

module tb_servo_pwm;

    localparam integer CLK_HZ    = 100_000_000;
    localparam real    CLK_NS    = 1.0e9 / CLK_HZ;
    localparam integer PERIOD_US = 20_000;
    localparam real    TOL_US    = 0.05;           // olcum toleransi

    reg        clk      = 1'b0;
    reg        rst      = 1'b1;
    reg        en       = 1'b0;
    reg [11:0] pulse_us = 12'd0;
    wire       pwm;

    always #(CLK_NS / 2.0) clk = ~clk;

    servo_pwm #(
        .CLK_HZ   (CLK_HZ),
        .PERIOD_US(PERIOD_US)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .en      (en),
        .pulse_us(pulse_us),
        .pwm_out (pwm)
    );

    // ------------------------------------------------------------------
    // Yardimcilar
    // ------------------------------------------------------------------
    integer  errors     = 0;
    integer  rise_count = 0;
    integer  n_before;
    realtime ta;
    real     wa;

    always @(posedge pwm) rise_count = rise_count + 1;

    task report(input [8*40-1:0] name, input real got, input real exp);
        begin
            if (got < exp - TOL_US || got > exp + TOL_US) begin
                $display("[FAIL] %0s: olculen %0.3f us, beklenen %0.3f us", name, got, exp);
                errors = errors + 1;
            end else begin
                $display("[ OK ] %0s: %0.3f us", name, got);
            end
        end
    endtask

    // Bir sonraki darbenin genisligini olcer
    task check_pulse(input integer exp_us);
        realtime t0;
        real     w;
        begin
            @(posedge pwm); t0 = $realtime;
            @(negedge pwm); w  = ($realtime - t0) / 1000.0;
            report("darbe genisligi", w, exp_us);
        end
    endtask

    // Iki ardisik yukselen kenar arasini olcer
    task check_period;
        realtime t0;
        real     p;
        begin
            @(posedge pwm); t0 = $realtime;
            @(posedge pwm); p  = ($realtime - t0) / 1000.0;
            report("periyot", p, PERIOD_US);
        end
    endtask

    // ------------------------------------------------------------------
    // Test senaryosu
    // ------------------------------------------------------------------
    initial begin
        repeat (10) @(posedge clk);
        rst = 1'b0;

        // Test 1: temel darbe genisligi
        $display("--- Test 1: 1500 us darbe ---");
        en       = 1'b1;
        pulse_us = 12'd1500;
        check_pulse(1500);
        check_pulse(1500);

        // Test 2: periyot
        $display("--- Test 2: periyot 20 ms ---");
        check_period;

        // Test 3: periyot ortasinda degisiklik o anki darbeyi bozmamali
        $display("--- Test 3: darbe ortasinda 1500 -> 1700 ---");
        @(posedge pwm); ta = $realtime;
        #(500_000);                          // darbenin 500. us'si
        pulse_us = 12'd1700;
        @(negedge pwm); wa = ($realtime - ta) / 1000.0;
        report("degisim sirasindaki darbe", wa, 1500);
        check_pulse(1700);

        // Test 4: en=0 iken darbe olmamali
        $display("--- Test 4: en=0 ---");
        @(negedge pwm);
        en       = 1'b0;
        n_before = rise_count;
        #(45_000_000);                       // iki periyottan uzun bekle
        if (rise_count != n_before || pwm !== 1'b0) begin
            $display("[FAIL] en=0 iken darbe uretildi");
            errors = errors + 1;
        end else begin
            $display("[ OK ] en=0 iken cikis sessiz");
        end

        // Test 5: tekrar etkinlestirme
        $display("--- Test 5: en=1, 1300 us ---");
        pulse_us = 12'd1300;
        en       = 1'b1;
        check_pulse(1300);

        // Sonuc
        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
