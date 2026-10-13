#!/usr/bin/env python3
"""rtl/font_rom.v dosyasini bir TrueType yazi tipinden uretir.

Kullanim:  python3 scripts/genrom.py [font.ttf] [punto] [y_kayma]
Varsayilan: DejaVu Sans Mono Bold, 15 punto, kayma 0 (8x16 hucre).
Her karakter 16 bayt: [ust yari 8 sutun][alt yari 8 sutun], bit0 = en ustteki piksel
(SSD1305'in sayfa/sutun formatinda).
"""
import os
import sys
from mkfont import render

FONT  = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
SIZE  = int(sys.argv[2]) if len(sys.argv) > 2 else 15
YOFF  = int(sys.argv[3]) if len(sys.argv) > 3 else 0
CHARS = " 0123456789ACDEIKLMNPTsu<>"
OUT   = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rtl", "font_rom.v")

g = render(FONT, SIZE, YOFF)
lines = []
for ch in CHARS:
    px = g[ch]
    bs = []
    for half in range(2):
        for x in range(8):
            b = 0
            for k in range(8):
                if px[half * 8 + k][x]:
                    b |= 1 << k
            bs.append(b)
    vec = "".join(f"{b:02X}" for b in reversed(bs))
    lines.append(f"            7'h{ord(ch):02X}: g = 128'h{vec};   // '{ch}'")

src = f'''// font_rom.v  (scripts/genrom.py ile uretildi: DejaVu Sans Mono Bold {SIZE}pt, 8x16)
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
{chr(10).join(lines)}
            default: g = 128'h0;
        endcase
    end

    always @(posedge clk) data <= g[{{half, x}} * 8 +: 8];

endmodule
'''
with open(OUT, "w") as f:
    f.write(src)
print("yazildi:", os.path.normpath(OUT))
