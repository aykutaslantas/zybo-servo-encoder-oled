// tb_servo_ctrl.v
// servo_ctrl_v1_0 IP'si icin testbench.
// PS'in AXI-Lite yazma/okuma islemlerini gorevlerle taklit eder.
// Vivado'da: Run Simulation -> "run all"  (~5 ms simulasyon)

`timescale 1ns/1ps

module tb_servo_ctrl;

    // ------------------------------------------------------------------
    // Saat, reset, dis sinyaller
    // ------------------------------------------------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk;                       // 100 MHz

    reg aresetn = 1'b0;
    reg enc_a = 1'b1, enc_b = 1'b1, enc_sw = 1'b1;
    reg sw0   = 1'b1;
    wire       servo_out;
    wire [3:0] led;

    // AXI master sinyalleri
    reg  [4:0]  awaddr = 0, araddr = 0;
    reg         awvalid = 0, wvalid = 0, arvalid = 0;
    reg  [31:0] wdata = 0;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;

    servo_ctrl dut (
        .enc_a(enc_a), .enc_b(enc_b), .enc_sw(enc_sw), .sw0(sw0),
        .servo_out(servo_out), .led(led),
        .oled_mosi(), .oled_sclk(), .oled_cs_n(), .oled_dc(), .oled_res_n(),
        .s00_axi_aclk(clk), .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'b000),
        .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(4'hF),
        .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(1'b1),
        .s00_axi_araddr(araddr), .s00_axi_arprot(3'b000),
        .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
        .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid), .s00_axi_rready(1'b1)
    );

    // Register ofsetleri
    localparam [4:0] CTRL = 5'h00, MOVE = 5'h04, ANGLE = 5'h08, STEP = 5'h0C,
                     MIN  = 5'h10, MAX  = 5'h14, STAT  = 5'h18, PULSE = 5'h1C;

    // ------------------------------------------------------------------
    // AXI-Lite gorevleri (PS'in Xil_Out32 / Xil_In32'si)
    // ------------------------------------------------------------------
    task axi_write(input [4:0] a, input [31:0] d);
        begin
            @(posedge clk);
            awaddr <= a; wdata <= d; awvalid <= 1'b1; wvalid <= 1'b1;
            @(posedge clk);
            while (!(awready && wready)) @(posedge clk);
            awvalid <= 1'b0; wvalid <= 1'b0;          // el sikisma bu kenarda oldu
            @(posedge clk);
            while (!bvalid) @(posedge clk);           // yazma cevabi
            repeat (6) @(posedge clk);                // pipeline otursun
        end
    endtask

    task axi_read(input [4:0] a, output [31:0] d);
        begin
            @(posedge clk);
            araddr <= a; arvalid <= 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;
            @(posedge clk);
            while (!rvalid) @(posedge clk);
            d = rdata;
            repeat (2) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------
    // Kontrol yardimcilari
    // ------------------------------------------------------------------
    integer errors = 0;
    reg [31:0] v;

    task expect_reg(input [8*32-1:0] name, input [4:0] a, input [31:0] exp);
        begin
            axi_read(a, v);
            if (v !== exp) begin
                $display("[FAIL] %0s: okunan %0d, beklenen %0d", name, v, exp);
                errors = errors + 1;
            end else begin
                $display("[ OK ] %0s = %0d", name, v);
            end
        end
    endtask

    task expect_pulse(input [8*32-1:0] name, input real ideal);
        begin
            axi_read(PULSE, v);
            if (v < ideal - 1.0 || v > ideal + 1.0) begin
                $display("[FAIL] %0s: darbe %0d us, beklenen ~%0.1f us", name, v, ideal);
                errors = errors + 1;
            end else begin
                $display("[ OK ] %0s: darbe = %0d us", name, v);
            end
        end
    endtask

    // Encoder: tik basina 2 gecisli, saat yonunde bir tik (11 -> 01 -> 00)
    task enc_tick_fwd;
        begin
            enc_a = 1'b0; #(1_000_000);
            enc_b = 1'b0; #(1_000_000);
        end
    endtask

    // ------------------------------------------------------------------
    // Senaryo
    // ------------------------------------------------------------------
    initial begin
        repeat (10) @(posedge clk);
        aresetn = 1'b1;
        repeat (10) @(posedge clk);

        $display("--- Acilis degerleri ---");
        expect_reg("CTRL",     CTRL,  1);
        expect_reg("ANGLE",    ANGLE, 90);
        expect_reg("STEP_DEG", STEP,  5);
        expect_reg("MIN_US",   MIN,   500);
        expect_reg("MAX_US",   MAX,   2500);
        expect_reg("STATUS",   STAT,  32'b100);         // etkin, sinirda degil
        expect_pulse("90 derece", 1500.0);

        $display("--- MOVE (goreceli) ---");
        axi_write(MOVE, 30);
        expect_reg("+30 -> ANGLE", ANGLE, 120);
        expect_pulse("120 derece", 500 + 120 * 2000 / 180.0);
        axi_write(MOVE, -1000);                          // 32 bit ikiye tumleyen
        expect_reg("-1000 -> ANGLE", ANGLE, 0);
        expect_reg("STATUS alt sinir", STAT, 32'b101);
        axi_write(MOVE, 1000);
        expect_reg("+1000 -> ANGLE", ANGLE, 180);
        expect_reg("STATUS ust sinir", STAT, 32'b110);

        $display("--- ANGLE (mutlak) ---");
        axi_write(ANGLE, 45);
        expect_reg("=45 -> ANGLE", ANGLE, 45);
        axi_write(ANGLE, 999);
        expect_reg("=999 -> ANGLE", ANGLE, 180);

        $display("--- CTRL ---");
        axi_write(CTRL, 32'b11);                         // EN=1, ortala
        expect_reg("ortala -> ANGLE", ANGLE, 90);
        expect_reg("CTRL (ortala biti okunmaz)", CTRL, 1);
        axi_write(CTRL, 32'b00);                         // yazilimla kapat
        expect_reg("STATUS EN=0", STAT, 32'b000);
        axi_write(CTRL, 32'b01);

        $display("--- Kalibrasyon ---");
        axi_write(MIN, 1000);
        axi_write(MAX, 2000);
        expect_reg("MIN_US", MIN, 1000);
        expect_reg("MAX_US", MAX, 2000);
        expect_pulse("1000/2000, 90", 1500.0);
        axi_write(ANGLE, 180);
        expect_pulse("1000/2000, 180", 2000.0);
        axi_write(MIN, 500);
        axi_write(MAX, 2500);

        $display("--- Encoder + register birlikte ---");
        axi_write(ANGLE, 90);
        axi_write(STEP, 10);
        enc_tick_fwd;
        repeat (10) @(posedge clk);
        expect_reg("1 tik (adim 10)", ANGLE, 100);

        $display("--- SW0 (donanim durdurma) ---");
        sw0 = 1'b0;
        repeat (10) @(posedge clk);
        expect_reg("STATUS SW0=0", STAT, 32'b000);

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
