// rotary_encoder.v
// KY-040 tipi mekanik quadrature encoder cozucu.
//
// Katmanlar:  senkronizor -> debounce -> quadrature cozucu -> tik algilayici
//
// Cikislar:
//   step      : tamamlanan her mekanik tik icin tek cevrimlik darbe
//   dir       : step aninda gecerli yon (1 = ileri, 0 = geri)
//   btn_press : butona basildigi an tek cevrimlik darbe
//   btn_level : buton basili oldugu surece 1
//
// "Ileri" yonu: AB = 11 -> 01 -> 00 -> 10 -> 11  (once A duser)
// Ters cikarsa INVERT_DIR = 1 yapilir.

`timescale 1ns/1ps

module rotary_encoder #(
    parameter integer CLK_HZ           = 100_000_000,
    parameter integer AB_DEBOUNCE_US   = 500,      // A/B icin kararlilik suresi
    parameter integer SW_DEBOUNCE_US   = 10_000,   // buton icin kararlilik suresi
    parameter integer EDGES_PER_DETENT = 4,        // tik basina gecis: 4 veya 2
    parameter integer INVERT_DIR       = 0
)(
    input  wire clk,
    input  wire rst,          // senkron, aktif-yuksek
    input  wire enc_a,        // KY-040 CLK pini
    input  wire enc_b,        // KY-040 DT pini
    input  wire enc_sw,       // KY-040 SW pini (aktif-dusuk)
    output reg  step,
    output reg  dir,
    output reg  btn_press,
    output wire btn_level
);

    localparam integer TICK_DIV = CLK_HZ / 100_000;      // 10 us tick
    localparam integer AB_TICKS = AB_DEBOUNCE_US / 10;
    localparam integer SW_TICKS = SW_DEBOUNCE_US / 10;

    // ------------------------------------------------------------------
    // 1) Senkronizor: {sw, b, a}, bosta hepsi 1 (pull-up)
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync1 = 3'b111;
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync2 = 3'b111;

    always @(posedge clk) begin
        sync1 <= {enc_sw, enc_b, enc_a};
        sync2 <= sync1;
    end

    // ------------------------------------------------------------------
    // 10 us tick ureteci (debounce zaman tabani)
    // ------------------------------------------------------------------
    reg [15:0] div_cnt = 16'd0;
    reg        tick    = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt <= 16'd0;
            tick    <= 1'b0;
        end else if (div_cnt == TICK_DIV - 1) begin
            div_cnt <= 16'd0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 16'd1;
            tick    <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // 2) Debounce
    // ------------------------------------------------------------------
    wire a_db, b_db, sw_db;

    debounce #(.STABLE_TICKS(AB_TICKS), .INIT(1'b1)) u_db_a (
        .clk(clk), .rst(rst), .tick(tick), .din(sync2[0]), .dout(a_db)
    );
    debounce #(.STABLE_TICKS(AB_TICKS), .INIT(1'b1)) u_db_b (
        .clk(clk), .rst(rst), .tick(tick), .din(sync2[1]), .dout(b_db)
    );
    debounce #(.STABLE_TICKS(SW_TICKS), .INIT(1'b1)) u_db_sw (
        .clk(clk), .rst(rst), .tick(tick), .din(sync2[2]), .dout(sw_db)
    );

    // ------------------------------------------------------------------
    // 3) Quadrature cozucu: onceki ve simdiki AB'den +1 / -1 / 0
    // ------------------------------------------------------------------
    wire [1:0] ab      = {a_db, b_db};
    reg  [1:0] ab_prev = 2'b11;

    reg signed [1:0] delta;
    always @(*) begin
        case ({ab_prev, ab})
            4'b11_01, 4'b01_00, 4'b00_10, 4'b10_11: delta =  2'sd1;   // ileri
            4'b11_10, 4'b10_00, 4'b00_01, 4'b01_11: delta = -2'sd1;   // geri
            default:                                 delta =  2'sd0;   // degisim yok / gecersiz
        endcase
    end

    // ------------------------------------------------------------------
    // 4) Tik algilayici: dinlenme durumuna donuldugunde net gecis sayisina bak
    // ------------------------------------------------------------------
    reg  signed [3:0] sub = 4'sd0;
    wire signed [3:0] sub_next = sub + delta;
    wire at_rest = (ab == 2'b11) || ((EDGES_PER_DETENT == 2) && (ab == 2'b00));

    always @(posedge clk) begin
        if (rst) begin
            ab_prev <= 2'b11;
            sub     <= 4'sd0;
            step    <= 1'b0;
            dir     <= 1'b0;
        end else begin
            step <= 1'b0;
            if (ab != ab_prev) begin
                ab_prev <= ab;
                if (at_rest) begin
                    sub <= 4'sd0;                              // her tik noktasinda hizala
                    if (sub_next >= EDGES_PER_DETENT) begin
                        step <= 1'b1;
                        dir  <= (INVERT_DIR == 0);
                    end else if (sub_next <= -EDGES_PER_DETENT) begin
                        step <= 1'b1;
                        dir  <= (INVERT_DIR != 0);
                    end
                end else begin
                    sub <= sub_next;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Buton: debounce edilmis sinyalin dusen kenari = basma ani
    // ------------------------------------------------------------------
    reg sw_prev = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            sw_prev   <= 1'b1;
            btn_press <= 1'b0;
        end else begin
            sw_prev   <= sw_db;
            btn_press <= sw_prev & ~sw_db;
        end
    end

    assign btn_level = ~sw_db;

endmodule
