// tb_rotary_encoder.v
// rotary_encoder icin kendi kendini kontrol eden testbench.
// Gercekci ziplama (bounce) modeli icerir.
// Vivado'da: Run Simulation -> Tcl konsolunda "run all"
// (simulasyon ~1 s surer; hiz icin modul 10 MHz saatle calistirilir)

`timescale 1ns/1ps

module tb_rotary_encoder;

    localparam integer CLK_HZ = 10_000_000;     // 100 ns periyot

    reg clk = 1'b0;
    always #50 clk = ~clk;

    reg        rst   = 1'b1;
    reg  [2:0] lines = 3'b111;                  // {sw, b, a}, bosta hepsi 1
    wire       step, dir, btn_press, btn_level;

    localparam integer A  = 0;
    localparam integer B  = 1;
    localparam integer SW = 2;

    rotary_encoder #(
        .CLK_HZ(CLK_HZ)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .enc_a    (lines[A]),
        .enc_b    (lines[B]),
        .enc_sw   (lines[SW]),
        .step     (step),
        .dir      (dir),
        .btn_press(btn_press),
        .btn_level(btn_level)
    );

    // ------------------------------------------------------------------
    // Sayaclar
    // ------------------------------------------------------------------
    integer fwd_cnt   = 0;
    integer rev_cnt   = 0;
    integer press_cnt = 0;
    integer errors    = 0;
    integer seed      = 12345;

    always @(posedge clk) begin
        if (step &&  dir) fwd_cnt   = fwd_cnt + 1;
        if (step && !dir) rev_cnt   = rev_cnt + 1;
        if (btn_press)    press_cnt = press_cnt + 1;
    end

    // ------------------------------------------------------------------
    // Ziplama modeli: hat 0-5 kez 10-150 us araliklarla titrer,
    // sonra yeni degerine oturur.
    // ------------------------------------------------------------------
    task bounce(input integer idx, input val);
        integer n, k;
        begin
            n = {$random(seed)} % 6;
            for (k = 0; k < n; k = k + 1) begin
                lines[idx] =  val; #(({$random(seed)} % 141 + 10) * 1000);
                lines[idx] = ~val; #(({$random(seed)} % 141 + 10) * 1000);
            end
            lines[idx] = val;
        end
    endtask

    // Ileri tik: 11 -> 01 -> 00 -> 10 -> 11
    task detent_fwd(input integer gap_us);
        begin
            bounce(A, 1'b0); #(gap_us * 1000);
            bounce(B, 1'b0); #(gap_us * 1000);
            bounce(A, 1'b1); #(gap_us * 1000);
            bounce(B, 1'b1); #(gap_us * 1000);
        end
    endtask

    // Geri tik: 11 -> 10 -> 00 -> 01 -> 11
    task detent_rev(input integer gap_us);
        begin
            bounce(B, 1'b0); #(gap_us * 1000);
            bounce(A, 1'b0); #(gap_us * 1000);
            bounce(B, 1'b1); #(gap_us * 1000);
            bounce(A, 1'b1); #(gap_us * 1000);
        end
    endtask

    // Yarim tik: yarisina kadar cevir, geri birak (11 -> 01 -> 00 -> 01 -> 11)
    task half_detent(input integer gap_us);
        begin
            bounce(A, 1'b0); #(gap_us * 1000);
            bounce(B, 1'b0); #(gap_us * 1000);
            bounce(B, 1'b1); #(gap_us * 1000);
            bounce(A, 1'b1); #(gap_us * 1000);
        end
    endtask

    task clear_counts;
        begin
            fwd_cnt   = 0;
            rev_cnt   = 0;
            press_cnt = 0;
        end
    endtask

    task check_steps(input [8*32-1:0] name, input integer exp_f, input integer exp_r);
        begin
            #(2_000_000);                       // son step'in cikmasini bekle
            if (fwd_cnt != exp_f || rev_cnt != exp_r) begin
                $display("[FAIL] %0s: ileri=%0d geri=%0d, beklenen ileri=%0d geri=%0d",
                         name, fwd_cnt, rev_cnt, exp_f, exp_r);
                errors = errors + 1;
            end else begin
                $display("[ OK ] %0s: ileri=%0d geri=%0d", name, fwd_cnt, rev_cnt);
            end
            clear_counts;
        end
    endtask

    // ------------------------------------------------------------------
    // Test senaryosu
    // ------------------------------------------------------------------
    integer i;

    initial begin
        repeat (20) @(posedge clk);
        rst = 1'b0;
        #(2_000_000);
        clear_counts;

        $display("--- Test 1: 10 tik ileri (normal hiz) ---");
        for (i = 0; i < 10; i = i + 1) detent_fwd(5000);
        check_steps("10 tik ileri", 10, 0);

        $display("--- Test 2: 10 tik geri (normal hiz) ---");
        for (i = 0; i < 10; i = i + 1) detent_rev(5000);
        check_steps("10 tik geri", 0, 10);

        $display("--- Test 3: 20 tik ileri (hizli) ---");
        for (i = 0; i < 20; i = i + 1) detent_fwd(1000);
        check_steps("20 tik hizli ileri", 20, 0);

        $display("--- Test 4: karisik (3 ileri, 2 geri) ---");
        detent_fwd(5000); detent_fwd(5000); detent_rev(5000);
        detent_fwd(5000); detent_rev(5000);
        check_steps("karisik", 3, 2);

        $display("--- Test 5: yarim tik, geri birakma ---");
        for (i = 0; i < 3; i = i + 1) half_detent(5000);
        check_steps("yarim tik", 0, 0);

        $display("--- Test 6: ziplayan buton ---");
        bounce(SW, 1'b0);
        #(50_000_000);                          // 50 ms basili tut
        bounce(SW, 1'b1);
        #(20_000_000);
        if (press_cnt != 1) begin
            $display("[FAIL] buton: %0d basma algilandi, beklenen 1", press_cnt);
            errors = errors + 1;
        end else begin
            $display("[ OK ] buton: tek basma algilandi");
        end

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
