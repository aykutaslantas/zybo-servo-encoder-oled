// debounce.v
// Genel amacli debounce filtresi.
//
// Giris, cikistan farkli bir degere gectiginde sayac tick'lerle ilerler.
// Giris STABLE_TICKS tick boyunca kesintisiz yeni degerde kalirsa cikis
// guncellenir. Arada eski degere donerse (ziplama) sayac sifirlanir.
// Giris senkronize edilmis olmalidir (bu modul senkronizor icermez).

`timescale 1ns/1ps

module debounce #(
    parameter integer STABLE_TICKS = 50,    // gereken kararli tick sayisi
    parameter         INIT         = 1'b1   // reset sonrasi cikis degeri
)(
    input  wire clk,
    input  wire rst,     // senkron, aktif-yuksek
    input  wire tick,    // zaman tabani (ornegin 10 us'de bir, tek cevrim)
    input  wire din,     // senkronize edilmis giris
    output reg  dout
);

    reg [15:0] cnt;

    initial begin
        dout = INIT;
        cnt  = 16'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            dout <= INIT;
            cnt  <= 16'd0;
        end else if (din == dout) begin
            cnt <= 16'd0;                         // fark yok veya ziplama geri dondu
        end else if (tick) begin
            if (cnt >= STABLE_TICKS - 1) begin
                dout <= din;                      // yeterince kararli kaldi, kabul et
                cnt  <= 16'd0;
            end else begin
                cnt <= cnt + 16'd1;
            end
        end
    end

endmodule
