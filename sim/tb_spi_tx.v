// tb_spi_tx.v
// spi_tx icin kendi kendini kontrol eden testbench.
// Bir SPI "ekran" modeli hatti dinler: CS dusukken her SCLK yukselen
// kenarinda MOSI'yi okur, 8 bit dolunca bayti DC ile birlikte kaydeder.
// Vivado'da: Run Simulation -> "run all"

`timescale 1ns/1ps

module tb_spi_tx;

    reg clk = 1'b0;
    always #5 clk = ~clk;                        // 100 MHz

    reg        rst = 1'b1;
    reg        start = 1'b0;
    reg  [7:0] data = 8'd0;
    reg        dc_in = 1'b0;
    wire       busy, done, sclk, mosi, dc, cs_n;

    spi_tx #(.HALF_DIV(10)) dut (
        .clk(clk), .rst(rst),
        .start(start), .data(data), .dc_in(dc_in),
        .busy(busy), .done(done),
        .sclk(sclk), .mosi(mosi), .dc(dc), .cs_n(cs_n)
    );

    integer errors = 0;

    // ------------------------------------------------------------------
    // Ekran modeli
    // ------------------------------------------------------------------
    reg [7:0] rx_shift;
    integer   rx_bits  = 0;
    integer   rx_count = 0;
    reg [8:0] rx_log [0:15];                     // {dc, bayt}

    always @(negedge cs_n) rx_bits = 0;

    always @(posedge sclk) begin
        if (!cs_n) begin
            rx_shift = {rx_shift[6:0], mosi};
            rx_bits  = rx_bits + 1;
            if (rx_bits == 8) begin
                rx_log[rx_count] = {dc, rx_shift};
                rx_count = rx_count + 1;
            end
        end else begin
            $display("[FAIL] CS yuksekken SCLK kenari");
            errors = errors + 1;
        end
    end

    // CS kalktiginda tam 8 bit gelmis olmali
    always @(posedge cs_n) begin
        if ($time > 100 && rx_bits != 8) begin
            $display("[FAIL] CS kalktiginda %0d bit alinmis", rx_bits);
            errors = errors + 1;
        end
    end

    // SCLK periyodu olcumu
    realtime t_last = 0, period = 0;
    always @(posedge sclk) begin
        if (t_last > 0 && ($realtime - t_last) < 1000) period = $realtime - t_last;
        t_last = $realtime;
    end

    // ------------------------------------------------------------------
    // Yardimcilar
    // ------------------------------------------------------------------
    integer i;

    task send(input [7:0] b, input d);
        begin
            @(posedge clk);
            data <= b; dc_in <= d; start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
            @(posedge done);
            @(posedge clk);
        end
    endtask

    reg [8:0] expected [0:15];

    initial begin
        expected[0] = {1'b0, 8'hAE};             // komut: ekrani kapat
        expected[1] = {1'b0, 8'hB0};             // komut: sayfa 0
        expected[2] = {1'b1, 8'hA5};             // veri
        expected[3] = {1'b1, 8'h3C};
        expected[4] = {1'b1, 8'h00};
        expected[5] = {1'b1, 8'hFF};
        expected[6] = {1'b0, 8'h81};
        expected[7] = {1'b1, 8'h01};

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        if (sclk !== 1'b0 || cs_n !== 1'b1) begin
            $display("[FAIL] bosta SCLK=0, CS=1 olmali");
            errors = errors + 1;
        end else $display("[ OK ] bosta SCLK=0, CS=1");

        for (i = 0; i < 8; i = i + 1)
            send(expected[i][7:0], expected[i][8]);

        // busy iken start yok sayilmali
        @(posedge clk); data <= 8'h55; dc_in <= 1'b1; start <= 1'b1;
        @(posedge clk); data <= 8'h99; start <= 1'b1;          // mesgulken
        @(posedge clk); start <= 1'b0;
        @(posedge done); repeat (5) @(posedge clk);
        expected[8] = {1'b1, 8'h55};

        if (rx_count != 9) begin
            $display("[FAIL] %0d bayt alindi, beklenen 9", rx_count);
            errors = errors + 1;
        end else $display("[ OK ] 9 bayt alindi (mesgulken gelen start yok sayildi)");

        for (i = 0; i < 9; i = i + 1) begin
            if (rx_log[i] !== expected[i]) begin
                $display("[FAIL] bayt %0d: alinan dc=%b %h, beklenen dc=%b %h",
                         i, rx_log[i][8], rx_log[i][7:0], expected[i][8], expected[i][7:0]);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("[ OK ] butun baytlar ve DC bitleri dogru");

        if (period < 199.0 || period > 201.0) begin
            $display("[FAIL] SCLK periyodu %0.1f ns, beklenen 200 ns", period);
            errors = errors + 1;
        end else $display("[ OK ] SCLK periyodu %0.1f ns (5 MHz)", period);

        $display("==============================");
        if (errors == 0) $display("SONUC: PASS");
        else             $display("SONUC: FAIL (%0d hata)", errors);
        $display("==============================");
        $finish;
    end

endmodule
