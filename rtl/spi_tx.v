// spi_tx.v
// Tek yonlu SPI verici (mod 0: CLK bosta 0, veri yukselen kenarda okunur).
//
//  - start darbesiyle bir bayt (MSB once) ve DC biti gonderilir.
//  - Her bayt icin CS dusurulur, bayt bitince tekrar kaldirilir.
//  - SCLK frekansi = clk / (2 * HALF_DIV).  100 MHz, HALF_DIV=10 -> 5 MHz
//  - busy=1 iken yeni start yok sayilir; bayt bitince done tek cevrim 1 olur.

`timescale 1ns/1ps

module spi_tx #(
    parameter integer HALF_DIV = 10          // yarim SPI periyodu, saat cevrimi
)(
    input  wire       clk,
    input  wire       rst,                   // senkron, aktif-yuksek

    input  wire       start,                 // tek cevrimlik "gonder"
    input  wire [7:0] data,
    input  wire       dc_in,                 // 0 = komut, 1 = veri
    output wire       busy,
    output reg        done,                  // bayt bitti (tek cevrim)

    output reg        sclk,
    output wire       mosi,
    output reg        dc,
    output reg        cs_n
);

    localparam [2:0] S_IDLE = 3'd0,
                     S_LEAD = 3'd1,          // CS dustu, ilk bit hatta, yarim periyot bekle
                     S_HIGH = 3'd2,          // SCLK = 1 (ekran bu kenarda okur)
                     S_LOW  = 3'd3,          // SCLK = 0, sonraki bit hatta
                     S_TAIL = 3'd4;          // son bitten sonra yarim periyot, sonra CS kalkar

    reg [2:0]  state = S_IDLE;
    reg [7:0]  shreg = 8'd0;                 // kaydirma register'i, MSB hatta
    reg [2:0]  bitn  = 3'd0;                 // gonderilen bit sayaci
    reg [15:0] div   = 16'd0;                // yarim periyot sayaci

    wire half_done = (div == HALF_DIV - 1);

    assign mosi = shreg[7];
    assign busy = (state != S_IDLE);

    initial begin
        sclk = 1'b0;
        cs_n = 1'b1;
        dc   = 1'b0;
        done = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            sclk  <= 1'b0;
            cs_n  <= 1'b1;
            done  <= 1'b0;
            div   <= 16'd0;
        end else begin
            done <= 1'b0;
            div  <= half_done ? 16'd0 : div + 16'd1;

            case (state)
                S_IDLE: begin
                    div <= 16'd0;
                    if (start) begin
                        shreg <= data;
                        dc    <= dc_in;
                        cs_n  <= 1'b0;
                        bitn  <= 3'd0;
                        state <= S_LEAD;
                    end
                end

                S_LEAD: if (half_done) begin
                    sclk  <= 1'b1;
                    state <= S_HIGH;
                end

                S_HIGH: if (half_done) begin
                    sclk <= 1'b0;
                    if (bitn == 3'd7) begin
                        state <= S_TAIL;
                    end else begin
                        shreg <= {shreg[6:0], 1'b0};      // sonraki bit hatta
                        bitn  <= bitn + 3'd1;
                        state <= S_LOW;
                    end
                end

                S_LOW: if (half_done) begin
                    sclk  <= 1'b1;
                    state <= S_HIGH;
                end

                S_TAIL: if (half_done) begin
                    cs_n  <= 1'b1;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
