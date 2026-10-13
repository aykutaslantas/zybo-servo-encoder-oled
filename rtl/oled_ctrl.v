// oled_ctrl.v
// SSD1305 128x32 OLED (Waveshare Pico-OLED-2.23) icin surucu durum makinesi.
//
// Akis:
//   RESET : RES#=0 RST_US kadar, sonra RES#=1, RST_US bekle
//   INIT  : acilis komut dizisi (DC=0)
//   FRAME : frame_start darbesi (piksel ureteci degerlerin kopyasini alir)
//   FCMD  : kontrast (0x81, contrast) ve ekran acik/kapali (0xAF/0xAE) komutlari
//   PAGE p: "sayfa p, sutun 0" komutlari (DC=0) + 128 piksel bayti (DC=1)
//   WAIT  : FRAME_US doldurulana kadar bekle, sonra FRAME'e don
//
// Piksel arayuzu: oled_ctrl page/col'u verir, PIX_LAT cevrim sonra pix'i
// okuyup gonderir. pix, page/col'un (gecikmeli olabilir) bir fonksiyonu olmali.

`timescale 1ns/1ps

module oled_ctrl #(
    parameter integer CLK_HZ     = 100_000_000,
    parameter integer HALF_DIV   = 10,         // SCLK = CLK_HZ / (2*HALF_DIV)
    parameter integer RST_US     = 10_000,     // reset darbesi ve sonrasindaki bekleme
    parameter integer FRAME_US   = 33_000,     // kare periyodu (~30 Hz)
    parameter integer COL_OFFSET = 4,          // 132 sutunluk RAM'de goruntunun basladigi sutun
    parameter integer PIX_LAT    = 3           // page/col -> pix gecikme payi (cevrim)
)(
    input  wire       clk,
    input  wire       rst,

    // Piksel ureteci
    output reg  [1:0] page,
    output reg  [6:0] col,
    input  wire [7:0] pix,
    output reg        frame_start,             // her kare basinda tek cevrim

    // Calisma aninda ayarlar (her kare basinda ekrana gonderilir)
    input  wire [7:0] contrast,                // 0..255
    input  wire       disp_on,                 // 1 = ekran acik

    output wire       ready,                   // acilis bitti, kareler gidiyor

    // OLED pinleri
    output wire       oled_sclk,
    output wire       oled_mosi,
    output wire       oled_dc,
    output wire       oled_cs_n,
    output reg        oled_res_n
);

    // ------------------------------------------------------------------
    // Acilis komut dizisi (Waveshare Pico-OLED-2.23 ornek kodundaki sira)
    // ------------------------------------------------------------------
    localparam integer INIT_LEN = 25;

    function [7:0] init_rom(input [4:0] i);
        case (i)
            5'd0:  init_rom = 8'hAE;   // ekrani kapat
            5'd1:  init_rom = 8'h04;   // sutun adresi alt nibble
            5'd2:  init_rom = 8'h10;   // sutun adresi ust nibble
            5'd3:  init_rom = 8'h40;   // baslangic satiri 0
            5'd4:  init_rom = 8'h81;   // kontrast...
            5'd5:  init_rom = 8'h80;   //   ...0x80
            5'd6:  init_rom = 8'hA1;   // segment yeniden eslestirme (yatay ayna)
            5'd7:  init_rom = 8'hA6;   // normal (ters degil) goruntu
            5'd8:  init_rom = 8'hA8;   // coklama orani...
            5'd9:  init_rom = 8'h1F;   //   ...32 satir
            5'd10: init_rom = 8'hC8;   // COM tarama yonu (dikey ayna)
            5'd11: init_rom = 8'hD3;   // goruntu kaymasi...
            5'd12: init_rom = 8'h00;   //   ...0
            5'd13: init_rom = 8'hD5;   // ic saat bolucu...
            5'd14: init_rom = 8'hF0;   //   ...0xF0
            5'd15: init_rom = 8'hD8;   // alan renk / dusuk guc modu...
            5'd16: init_rom = 8'h05;   //   ...0x05
            5'd17: init_rom = 8'hD9;   // on-sarj suresi...
            5'd18: init_rom = 8'hC2;   //   ...0xC2
            5'd19: init_rom = 8'hDA;   // COM pin yapilandirmasi...
            5'd20: init_rom = 8'h12;   //   ...0x12
            5'd21: init_rom = 8'hDB;   // VCOMH seviyesi...
            5'd22: init_rom = 8'h08;   //   ...0x08
            5'd23: init_rom = 8'hA4;   // goruntu RAM'den
            5'd24: init_rom = 8'hAF;   // ekrani ac
            default: init_rom = 8'hE3; // NOP
        endcase
    endfunction

    // ------------------------------------------------------------------
    // SPI verici
    // ------------------------------------------------------------------
    reg        tx_start = 1'b0;
    reg  [7:0] tx_data  = 8'd0;
    reg        tx_dc    = 1'b0;
    wire       tx_busy, tx_done;

    spi_tx #(.HALF_DIV(HALF_DIV)) u_spi (
        .clk(clk), .rst(rst),
        .start(tx_start), .data(tx_data), .dc_in(tx_dc),
        .busy(tx_busy), .done(tx_done),
        .sclk(oled_sclk), .mosi(oled_mosi), .dc(oled_dc), .cs_n(oled_cs_n)
    );

    // ------------------------------------------------------------------
    // Mikrosaniye sayaci (bekleme durumlari icin)
    // ------------------------------------------------------------------
    localparam integer US_DIV = CLK_HZ / 1_000_000;

    reg  [7:0]  us_div = 8'd0;
    reg  [19:0] us_cnt = 20'd0;                 // en fazla ~1 s
    reg         us_clr;

    always @(posedge clk) begin
        if (rst || us_clr) begin
            us_div <= 8'd0;
            us_cnt <= 20'd0;
        end else if (us_div == US_DIV - 1) begin
            us_div <= 8'd0;
            us_cnt <= us_cnt + 20'd1;
        end else begin
            us_div <= us_div + 8'd1;
        end
    end

    // ------------------------------------------------------------------
    // Ana durum makinesi
    // ------------------------------------------------------------------
    localparam [3:0] S_RST_LO = 4'd0,
                     S_RST_HI = 4'd1,
                     S_INIT   = 4'd2,
                     S_FRAME  = 4'd3,
                     S_PCMD   = 4'd4,          // sayfa basi komutlari
                     S_PSET   = 4'd5,          // page/col ayarla, pix'i bekle
                     S_PDATA  = 4'd6,          // pix'i gonder
                     S_WAIT   = 4'd7,
                     S_TX     = 4'd8,          // bayt gonderiliyor
                     S_TXWAIT = 4'd9,
                     S_FCMD   = 4'd10;         // kare basi ayar komutlari

    reg [3:0] state = S_RST_LO;
    reg [3:0] ret   = S_RST_LO;                // S_TX bitince donulecek durum
    reg [4:0] idx   = 5'd0;                    // init / sayfa komut sayaci
    reg [3:0] lat   = 4'd0;
    reg       rdy   = 1'b0;

    assign ready = rdy;

    initial begin
        oled_res_n  = 1'b0;
        page        = 2'd0;
        col         = 7'd0;
        frame_start = 1'b0;
    end

    // Sayfa basi komutu (idx 0..2)
    wire [7:0] pcmd = (idx == 5'd0) ? (8'hB0 | {6'd0, page})                 :
                      (idx == 5'd1) ? (8'h00 | (COL_OFFSET[7:0] & 8'h0F))      :
                                      (8'h10 | ((COL_OFFSET[7:0] >> 4) & 8'h0F));

    always @(posedge clk) begin
        us_clr      <= 1'b0;
        tx_start    <= 1'b0;
        frame_start <= 1'b0;

        if (rst) begin
            state      <= S_RST_LO;
            oled_res_n <= 1'b0;
            us_clr     <= 1'b1;
            idx        <= 5'd0;
            rdy        <= 1'b0;
        end else begin
            case (state)
                // ---------------- Reset ----------------
                S_RST_LO: begin
                    oled_res_n <= 1'b0;
                    if (us_cnt >= RST_US) begin
                        oled_res_n <= 1'b1;
                        us_clr     <= 1'b1;
                        state      <= S_RST_HI;
                    end
                end

                S_RST_HI: if (us_cnt >= RST_US) begin
                    idx   <= 5'd0;
                    state <= S_INIT;
                end

                // ---------------- Acilis komutlari ----------------
                S_INIT: begin
                    if (idx == INIT_LEN) begin
                        rdy   <= 1'b1;
                        state <= S_FRAME;
                    end else begin
                        tx_data <= init_rom(idx);
                        tx_dc   <= 1'b0;
                        idx     <= idx + 5'd1;
                        ret     <= S_INIT;
                        state   <= S_TX;
                    end
                end

                // ---------------- Kare ----------------
                S_FRAME: begin
                    frame_start <= 1'b1;
                    us_clr      <= 1'b1;
                    page        <= 2'd0;
                    idx         <= 5'd0;
                    state       <= S_FCMD;
                end

                S_FCMD: begin
                    if (idx == 5'd3) begin
                        idx   <= 5'd0;
                        state <= S_PCMD;
                    end else begin
                        tx_data <= (idx == 5'd0) ? 8'h81 :
                                   (idx == 5'd1) ? contrast :
                                   (disp_on ? 8'hAF : 8'hAE);
                        tx_dc   <= 1'b0;
                        idx     <= idx + 5'd1;
                        ret     <= S_FCMD;
                        state   <= S_TX;
                    end
                end

                S_PCMD: begin
                    if (idx == 5'd3) begin
                        col   <= 7'd0;
                        lat   <= 4'd0;
                        state <= S_PSET;
                    end else begin
                        tx_data <= pcmd;
                        tx_dc   <= 1'b0;
                        idx     <= idx + 5'd1;
                        ret     <= S_PCMD;
                        state   <= S_TX;
                    end
                end

                S_PSET: begin                          // pix'in oturmasini bekle
                    if (lat == PIX_LAT) state <= S_PDATA;
                    else                lat   <= lat + 4'd1;
                end

                S_PDATA: begin
                    tx_data <= pix;
                    tx_dc   <= 1'b1;
                    ret     <= S_PDATA;                // donuste asagidaki dal calisir
                    state   <= S_TX;
                    lat     <= 4'd0;
                end

                // ---------------- Bekleme ----------------
                S_WAIT: if (us_cnt >= FRAME_US) state <= S_FRAME;

                // ---------------- Bayt gonder ----------------
                S_TX: begin
                    tx_start <= 1'b1;
                    state    <= S_TXWAIT;
                end

                S_TXWAIT: if (tx_done) begin
                    if (ret == S_PDATA) begin
                        // bir piksel bayti bitti: sonraki sutun / sayfa / bekleme
                        if (col != 7'd127) begin
                            col   <= col + 7'd1;
                            state <= S_PSET;
                        end else if (page != 2'd3) begin
                            page  <= page + 2'd1;
                            idx   <= 5'd0;
                            state <= S_PCMD;
                        end else begin
                            state <= S_WAIT;
                        end
                    end else begin
                        state <= ret;
                    end
                end

                default: state <= S_RST_LO;
            endcase
        end
    end

endmodule
