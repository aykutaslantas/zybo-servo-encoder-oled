// bin2bcd.v
// 12 bit ikili sayiyi 4 ondalik basamaga (BCD) cevirir: "double dabble".
//   ornek: 1500 -> {1, 5, 0, 0}
// Algoritma: sayiyi bit bit sola kaydirirken, her kaydirmadan once 5 veya
// daha buyuk olan basamaga 3 eklenir. 12 kaydirmadan sonra basamaklar hazir.
// Tamamen kombinasyonel; for dongusu sentezde 12 asamali bir devreye acilir.

`timescale 1ns/1ps

module bin2bcd (
    input  wire [11:0] bin,
    output reg  [3:0]  d3,      // binler
    output reg  [3:0]  d2,      // yuzler
    output reg  [3:0]  d1,      // onlar
    output reg  [3:0]  d0       // birler
);

    integer i;
    reg [27:0] s;               // {d3, d2, d1, d0, bin}

    always @(*) begin
        s = {16'd0, bin};
        for (i = 0; i < 12; i = i + 1) begin
            if (s[15:12] >= 4'd5) s[15:12] = s[15:12] + 4'd3;
            if (s[19:16] >= 4'd5) s[19:16] = s[19:16] + 4'd3;
            if (s[23:20] >= 4'd5) s[23:20] = s[23:20] + 4'd3;
            if (s[27:24] >= 4'd5) s[27:24] = s[27:24] + 4'd3;
            s = s << 1;
        end
        d3 = s[27:24];
        d2 = s[23:20];
        d1 = s[19:16];
        d0 = s[15:12];
    end

endmodule
