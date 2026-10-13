// tb_oled_text.v
// bin2bcd ve oled_text icin testbench.
//  1) bin2bcd: 0..4095 arasi butun sayilar.
//  2) oled_text: uc farkli durumda tum ekrani (4 sayfa x 128 sutun) okur,
//     beklenen metnin font baytlariyla karsilastirir ve ekrani konsola cizer.
// Vivado'da: Run Simulation -> "run all"

`timescale 1ns/1ps

module tb_oled_text;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    integer errors = 0;

    // ------------------------------------------------------------------
    // 1) bin2bcd
    // ------------------------------------------------------------------
    reg  [11:0] b_in = 12'd0;
    wire [3:0]  b3, b2, b1, b0;

    bin2bcd u_b2b (.bin(b_in), .d3(b3), .d2(b2), .d1(b1), .d0(b0));

    // ------------------------------------------------------------------
    // 2) oled_text
    // ------------------------------------------------------------------
    reg         frame_start = 1'b0;
    reg  [7:0]  angle = 0, step_deg = 0;
    reg  [11:0] pulse_us = 0;
    reg         en = 0, at_min = 0, at_max = 0;
    reg  [1:0]  page = 0;
    reg  [6:0]  col = 0;
    wire [7:0]  pix;

    oled_text dut (
        .clk(clk), .frame_start(frame_start),
        .angle(angle), .pulse_us(pulse_us), .step_deg(step_deg),
        .en(en), .at_min(at_min), .at_max(at_max),
        .page(page), .col(col), .pix(pix)
    );

    // Beklenen baytlar icin ayri bir font ROM'u
    reg  [6:0] r_ch = 0;
    reg        r_half = 0;
    reg  [2:0] r_x = 0;
    wire [7:0] r_data;

    font_rom u_ref (.clk(clk), .ch(r_ch), .half(r_half), .x(r_x), .data(r_data));

    reg [7:0] frame [0:3][0:127];

    // Ekrandan bir kare oku
    task read_frame;
        integer p, c;
        begin
            @(posedge clk); frame_start <= 1'b1;
            @(posedge clk); frame_start <= 1'b0;
            repeat (4) @(posedge clk);
            for (p = 0; p < 4; p = p + 1)
                for (c = 0; c < 128; c = c + 1) begin
                    @(posedge clk); page <= p; col <= c;
                    repeat (3) @(posedge clk);
                    frame[p][c] = pix;
                end
        end
    endtask

    // Ekrani konsola ciz (yatayda her sutun, dikeyde her satir)
    task draw;
        integer r, c;
        reg [8*128-1:0] s;
        begin
            $display("+%s+", {128{"-"}});
            for (r = 0; r < 32; r = r + 1) begin
                for (c = 0; c < 128; c = c + 1)
                    s[(127-c)*8 +: 8] = frame[r/8][c][r%8] ? "#" : " ";
                $display("|%s|", s);
            end
            $display("+%s+", {128{"-"}});
        end
    endtask

    // Kareyi beklenen iki satirla karsilastir
    task check(input [8*16-1:0] l0, input [8*16-1:0] l1, input [8*24-1:0] name);
        integer p, c, e0;
        reg [7:0] chr;
        begin
            e0 = errors;
            for (p = 0; p < 4; p = p + 1)
                for (c = 0; c < 128; c = c + 1) begin
                    chr = (p < 2) ? l0[(15 - c/8)*8 +: 8] : l1[(15 - c/8)*8 +: 8];
                    @(posedge clk); r_ch <= chr[6:0]; r_half <= p[0]; r_x <= c[2:0];
                    @(posedge clk); @(posedge clk);
                    if (frame[p][c] !== r_data) begin
                        if (errors - e0 < 5)
                            $display("[FAIL] %0s: sayfa %0d sutun %0d ('%c'): %h, beklenen %h",
                                     name, p, c, chr, frame[p][c], r_data);
                        errors = errors + 1;
                    end
                end
            if (errors == e0) $display("[ OK ] %0s: \"%s\" / \"%s\"", name, l0, l1);
        end
    endtask

    // ------------------------------------------------------------------
    // Senaryo
    // ------------------------------------------------------------------
    integer i, e0;

    initial begin
        // ---- bin2bcd ----
        e0 = errors;
        for (i = 0; i < 4096; i = i + 1) begin
            b_in = i;
            #1;
            if (b3 * 1000 + b2 * 100 + b1 * 10 + b0 != i || b3 > 9 || b2 > 9 || b1 > 9 || b0 > 9) begin
                if (errors - e0 < 5) $display("[FAIL] bin2bcd(%0d) = %0d%0d%0d%0d", i, b3, b2, b1, b0);
                errors = errors + 1;
            end
        end
        if (errors == e0) $display("[ OK ] bin2bcd: 0..4095 arasi tum sayilar dogru");

        // ---- Durum 1: normal ----
        angle = 135; pulse_us = 1750; step_deg = 5; en = 1; at_min = 0; at_max = 0;
        read_frame;
        check("ACI 135  ETKIN  ", "1750us  ADIM  5 ", "normal");
        draw;

        // ---- Durum 2: alt sinir, kapali, iki basamakli adim ----
        angle = 0; pulse_us = 500; step_deg = 15; en = 0; at_min = 1; at_max = 0;
        read_frame;
        check("ACI   0< KAPALI ", " 500us  ADIM 15 ", "alt sinir, kapali");
        draw;

        // ---- Durum 3: ust sinir ----
        angle = 180; pulse_us = 2500; step_deg = 5; en = 1; at_min = 0; at_max = 1;
        read_frame;
        check("ACI 180> ETKIN  ", "2500us  ADIM  5 ", "ust sinir");

        // ---- Kare ortasinda degisen deger goruntuyu bozmamali ----
        @(posedge clk); frame_start <= 1'b1;
        @(posedge clk); frame_start <= 1'b0;
        angle = 42;                                   // kopya alindiktan sonra degisti
        repeat (4) @(posedge clk);
        begin : midframe
            integer p, c;
            for (p = 0; p < 4; p = p + 1)
                for (c = 0; c < 128; c = c + 1) begin
                    @(posedge clk); page <= p; col <= c;
                    repeat (3) @(posedge clk);
                    frame[p][c] = pix;
                end
        end
        check("ACI 180> ETKIN  ", "2500us  ADIM  5 ", "kare ortasi degisim");

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
