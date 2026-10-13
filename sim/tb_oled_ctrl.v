// tb_oled_ctrl.v
// oled_ctrl icin kendi kendini kontrol eden testbench.
// Ekran modeli SPI'dan gelen her bayti DC ile birlikte kaydeder; testbench
// reset darbesini, acilis dizisini ve iki tam kareyi (4 x (3 komut + 128 veri))
// beklenenle karsilastirir. Piksel ureteci her (sayfa, sutun) icin farkli bir
// bayt verir, boylece siralama ve gecikme hatalari yakalanir.
// Vivado'da: Run Simulation -> "run all"  (~5 ms)

`timescale 1ns/1ps

module tb_oled_ctrl;

    localparam integer INIT_LEN   = 25;
    localparam integer COL_OFFSET = 4;
    localparam integer RST_US     = 20;          // simulasyon icin kisa

    reg clk = 1'b0;
    always #5 clk = ~clk;                        // 100 MHz

    reg rst = 1'b1;

    wire [1:0] page;
    wire [6:0] col;
    reg  [7:0] pix = 8'd0;
    wire       frame_start, ready;
    wire       sclk, mosi, dc, cs_n, res_n;

    oled_ctrl #(
        .CLK_HZ    (100_000_000),
        .HALF_DIV  (10),
        .RST_US    (RST_US),
        .FRAME_US  (1500),
        .COL_OFFSET(COL_OFFSET),
        .PIX_LAT   (3)
    ) dut (
        .clk(clk), .rst(rst),
        .page(page), .col(col), .pix(pix),
        .frame_start(frame_start), .ready(ready),
        .contrast(8'h5A), .disp_on(1'b1),
        .oled_sclk(sclk), .oled_mosi(mosi), .oled_dc(dc),
        .oled_cs_n(cs_n), .oled_res_n(res_n)
    );

    // Piksel ureteci: bir cevrim gecikmeli, (sayfa, sutun)'a ozgu deger
    function [7:0] pix_of(input [1:0] p, input [6:0] c);
        pix_of = p * 8'd37 + c;
    endfunction

    always @(posedge clk) pix <= pix_of(page, col);

    // ------------------------------------------------------------------
    // Ekran modeli
    // ------------------------------------------------------------------
    integer   errors = 0;
    reg [7:0] sh;
    integer   nbits  = 0;
    integer   nbytes = 0;
    reg [8:0] rx [0:2047];                       // {dc, bayt}

    always @(negedge cs_n) nbits = 0;

    always @(posedge sclk) if (!cs_n) begin
        sh    = {sh[6:0], mosi};
        nbits = nbits + 1;
        if (nbits == 8) begin
            if (nbytes < 2048) rx[nbytes] = {dc, sh};
            nbytes = nbytes + 1;
        end
    end

    // Reset suresince SPI trafigi olmamali
    always @(negedge cs_n) if (!res_n) begin
        $display("[FAIL] RES# dusukken SPI trafigi");
        errors = errors + 1;
    end

    // Reset darbesinin suresi
    realtime t_res_rise = 0;
    always @(posedge res_n) t_res_rise = $realtime;

    integer frames = 0;
    always @(posedge clk) if (frame_start) frames = frames + 1;

    // ------------------------------------------------------------------
    // Beklenen acilis dizisi
    // ------------------------------------------------------------------
    reg [7:0] init_exp [0:INIT_LEN-1];
    initial begin
        init_exp[0]=8'hAE; init_exp[1]=8'h04; init_exp[2]=8'h10; init_exp[3]=8'h40;
        init_exp[4]=8'h81; init_exp[5]=8'h80; init_exp[6]=8'hA1; init_exp[7]=8'hA6;
        init_exp[8]=8'hA8; init_exp[9]=8'h1F; init_exp[10]=8'hC8; init_exp[11]=8'hD3;
        init_exp[12]=8'h00; init_exp[13]=8'hD5; init_exp[14]=8'hF0; init_exp[15]=8'hD8;
        init_exp[16]=8'h05; init_exp[17]=8'hD9; init_exp[18]=8'hC2; init_exp[19]=8'hDA;
        init_exp[20]=8'h12; init_exp[21]=8'hDB; init_exp[22]=8'h08; init_exp[23]=8'hA4;
        init_exp[24]=8'hAF;
    end

    task expect_byte(input integer k, input exp_dc, input [7:0] exp_b, input [8*24-1:0] what);
        begin
            if (rx[k] !== {exp_dc, exp_b}) begin
                if (errors < 10)
                    $display("[FAIL] bayt %0d (%0s): alinan dc=%b %h, beklenen dc=%b %h",
                             k, what, rx[k][8], rx[k][7:0], exp_dc, exp_b);
                errors = errors + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Senaryo
    // ------------------------------------------------------------------
    integer i, f, p, c, k, e0;

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;

        // Reset darbesi
        @(posedge res_n);
        if ($realtime < RST_US * 1000.0) begin
            $display("[FAIL] RES# darbesi cok kisa: %0t", $realtime);
            errors = errors + 1;
        end else $display("[ OK ] RES# darbesi >= %0d us", RST_US);

        // Iki kare bitene kadar bekle
        wait (frames == 3);
        repeat (100) @(posedge clk);

        // Acilis dizisi
        e0 = errors;
        for (i = 0; i < INIT_LEN; i = i + 1)
            expect_byte(i, 1'b0, init_exp[i], "acilis");
        if (errors == e0) $display("[ OK ] acilis dizisi (%0d komut) dogru", INIT_LEN);

        // Iki kare
        k = INIT_LEN;
        for (f = 0; f < 2; f = f + 1) begin
            e0 = errors;
            expect_byte(k,   1'b0, 8'h81, "kontrast komutu");
            expect_byte(k+1, 1'b0, 8'h5A, "kontrast degeri");
            expect_byte(k+2, 1'b0, 8'hAF, "ekran acik");
            k = k + 3;
            for (p = 0; p < 4; p = p + 1) begin
                expect_byte(k,   1'b0, 8'hB0 | p,                    "sayfa komutu");
                expect_byte(k+1, 1'b0, 8'h00 | (COL_OFFSET & 15),    "sutun alt");
                expect_byte(k+2, 1'b0, 8'h10 | (COL_OFFSET >> 4),    "sutun ust");
                k = k + 3;
                for (c = 0; c < 128; c = c + 1) begin
                    expect_byte(k, 1'b1, pix_of(p, c), "piksel");
                    k = k + 1;
                end
            end
            if (errors == e0) $display("[ OK ] kare %0d: 3 ayar komutu + 4 sayfa x (3 komut + 128 piksel) dogru", f);
        end

        if (!ready) begin
            $display("[FAIL] ready = 0");
            errors = errors + 1;
        end else $display("[ OK ] ready = 1");

        $display("Toplam alinan bayt: %0d", nbytes);
        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
