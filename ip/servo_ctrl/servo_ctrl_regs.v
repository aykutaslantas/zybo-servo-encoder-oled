// servo_ctrl_regs.v
// servo_ctrl IP'sinin AXI4-Lite register blogu (slave).
//
// Register haritasi (32 bit, bayt ofseti):
//   0x00 CTRL     R/W  bit0: EN (yazilim etkinlestirme, acilista 1)
//                      bit1: 1 yazilinca ortala (komut, okununca 0)
//   0x04 MOVE     W    isaretli goreceli aci [15:0], yazilinca uygulanir (komut)
//   0x08 ANGLE    R/W  okuma: simdiki aci, yazma: bu aciya git (komut)
//   0x0C STEP_DEG R/W  encoder tik basina derece           (acilis 5)
//   0x10 MIN_US   R/W  0 derecenin darbe genisligi          (acilis 500)
//   0x14 MAX_US   R/W  180 derecenin darbe genisligi        (acilis 2500)
//   0x18 STATUS   R    bit0: alt sinirda, bit1: ust sinirda, bit2: servo etkin
//   0x1C PULSE_US R    su an gonderilen darbe genisligi
//
// Basit AXI-Lite yapisi: yazma, adres ve veri kanallari ayni anda gecerli
// oldugunda tek cevrimde kabul edilir; okuma da tek cevrimde cevaplanir.

`timescale 1ns/1ps

module servo_ctrl_regs #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5
)(
    // ---------------- AXI4-Lite ----------------
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    output wire [1:0]                        S_AXI_BRESP,
    output reg                               S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output reg                               S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,

    // ---------------- Cekirdege giden ----------------
    output reg                ctrl_en,
    output reg                center_stb,
    output reg                move_stb,
    output reg  signed [15:0] move_deg,
    output reg                set_stb,
    output reg         [15:0] set_deg,
    output reg         [7:0]  step_deg,
    output reg         [11:0] min_us,
    output reg         [11:0] max_us,

    // ---------------- Cekirdekten gelen ----------------
    input  wire        [7:0]  angle,
    input  wire        [11:0] pulse_us,
    input  wire        [2:0]  status
);

    localparam [7:0]  STEP_INIT = 8'd5;
    localparam [11:0] MIN_INIT  = 12'd500;
    localparam [11:0] MAX_INIT  = 12'd2500;

    // ------------------------------------------------------------------
    // Yazma kanali: AW ve W ayni anda geldiginde kabul et
    // ------------------------------------------------------------------
    wire wr_en = S_AXI_AWVALID && S_AXI_WVALID && !S_AXI_BVALID;

    assign S_AXI_AWREADY = wr_en;
    assign S_AXI_WREADY  = wr_en;
    assign S_AXI_BRESP   = 2'b00;                     // OKAY

    wire [2:0]  wr_idx = S_AXI_AWADDR[4:2];
    wire [31:0] wd     = S_AXI_WDATA;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            ctrl_en      <= 1'b1;
            step_deg     <= STEP_INIT;
            min_us       <= MIN_INIT;
            max_us       <= MAX_INIT;
            move_deg     <= 16'sd0;
            set_deg      <= 16'd0;
            center_stb   <= 1'b0;
            move_stb     <= 1'b0;
            set_stb      <= 1'b0;
        end else begin
            // komut strobe'lari varsayilan olarak 0: sadece bir cevrim 1 olur
            center_stb <= 1'b0;
            move_stb   <= 1'b0;
            set_stb    <= 1'b0;

            if (wr_en) begin
                S_AXI_BVALID <= 1'b1;
                case (wr_idx)
                    3'd0: begin                                   // CTRL
                        ctrl_en    <= wd[0];
                        center_stb <= wd[1];
                    end
                    3'd1: begin                                   // MOVE
                        move_deg <= wd[15:0];
                        move_stb <= 1'b1;
                    end
                    3'd2: begin                                   // ANGLE
                        set_deg <= wd[15:0];
                        set_stb <= 1'b1;
                    end
                    3'd3: step_deg <= wd[7:0];                    // STEP_DEG
                    3'd4: min_us   <= wd[11:0];                   // MIN_US
                    3'd5: max_us   <= wd[11:0];                   // MAX_US
                    default: ;                                    // salt okunur
                endcase
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Okuma kanali
    // ------------------------------------------------------------------
    wire rd_en = S_AXI_ARVALID && !S_AXI_RVALID;

    assign S_AXI_ARREADY = rd_en;
    assign S_AXI_RRESP   = 2'b00;                     // OKAY

    wire [2:0] rd_idx = S_AXI_ARADDR[4:2];

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= 32'd0;
        end else if (rd_en) begin
            S_AXI_RVALID <= 1'b1;
            case (rd_idx)
                3'd0: S_AXI_RDATA <= {31'd0, ctrl_en};
                3'd1: S_AXI_RDATA <= 32'd0;                       // MOVE: salt yazilir
                3'd2: S_AXI_RDATA <= {24'd0, angle};
                3'd3: S_AXI_RDATA <= {24'd0, step_deg};
                3'd4: S_AXI_RDATA <= {20'd0, min_us};
                3'd5: S_AXI_RDATA <= {20'd0, max_us};
                3'd6: S_AXI_RDATA <= {29'd0, status};
                3'd7: S_AXI_RDATA <= {20'd0, pulse_us};
            endcase
        end else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

endmodule
