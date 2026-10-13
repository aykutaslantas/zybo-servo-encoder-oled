// font_rom.v  (scripts/genrom.py ile uretildi: DejaVu Sans Mono Bold 15pt, 8x16)
// Karakter (ASCII) + yari (0 = ust 8 satir, 1 = alt 8 satir) + sutun (0..7)
// -> SSD1305 sutun bayti (bit0 = en ustteki piksel).
// Bir cevrim gecikmeli (registered) cikis. Tanimsiz karakterler bos goruntulenir.
// Font: DejaVu Sans Mono (Bitstream Vera lisansi, serbest kullanim).

`timescale 1ns/1ps

module font_rom (
    input  wire       clk,
    input  wire [6:0] ch,
    input  wire       half,
    input  wire [2:0] x,
    output reg  [7:0] data
);

    reg [127:0] g;

    always @(*) begin
        case (ch)
            7'h20: g = 128'h00000000000000000000000000000000;   // ' '
            7'h30: g = 128'h000F1F3021301F0F00E0F0188818F0E0;   // '0'
            7'h31: g = 128'h0020203F3F202020000000F8F8081000;   // '1'
            7'h32: g = 128'h002021272F3C383000E0F0F808080810;   // '2'
            7'h33: g = 128'h001E1F3120202010003078D888880810;   // '3'
            7'h34: g = 128'h00043F3F040407070000F8F878E0C000;   // '4'
            7'h35: g = 128'h000E1F3120202011000008888888F8F8;   // '5'
            7'h36: g = 128'h001F3F2020311F0F001088888898F0E0;   // '6'
            7'h37: g = 128'h000000071F3C30000038F8F888080808;   // '7'
            7'h38: g = 128'h001F3F3120313F1F0070F8D888D8F870;   // '8'
            7'h39: g = 128'h000F1F332222230100E0F0180808F8F0;   // '9'
            7'h41: g = 128'h203E3F0704073F3E0000E0F878F8E000;   // 'A'
            7'h43: g = 128'h00102020303C1F07001008081878F0C0;   // 'C'
            7'h44: g = 128'h000F1F3020203F3F00E0F0180808F8F8;   // 'D'
            7'h45: g = 128'h0021212121213F3F000808080808F8F8;   // 'E'
            7'h49: g = 128'h0020203F3F3F2020000808F8F8F80808;   // 'I'
            7'h4B: g = 128'h20383E0F03033F3F081838F0E080F8F8;   // 'K'
            7'h4C: g = 128'h20202020203F3F000000000000F8F800;   // 'L'
            7'h4D: g = 128'h003F3F0303033F3F00F8F8F080F0F8F8;   // 'M'
            7'h4E: g = 128'h003F3F1E07003F3F00F8F800C0F0F8F8;   // 'N'
            7'h50: g = 128'h0001030302023F3F00F0F8180808F8F8;   // 'P'
            7'h54: g = 128'h0000003F3F3F0000000808F8F8F80808;   // 'T'
            7'h73: g = 128'h001C3E3E262723110000804040C0C080;   // 's'
            7'h75: g = 128'h003F3F3020303F1F00C0C0000000C0C0;   // 'u'
            7'h3C: g = 128'h00180C0C0C0707030060C0C080808000;   // '<'
            7'h3E: g = 128'h000307070C0C0C1800008080C0C0C060;   // '>'
            default: g = 128'h0;
        endcase
    end

    always @(posedge clk) data <= g[{half, x} * 8 +: 8];

endmodule
