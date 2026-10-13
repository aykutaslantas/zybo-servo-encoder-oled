## oled_test.xdc - Zybo Z7-20, OLED test deseni (PS'siz)

## 125 MHz sistem saati
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Reset butonu
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn0 }];

## LED'ler
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## OLED - Pmod JC
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { oled_mosi }];   # JC1 -> DIN
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports { oled_sclk }];   # JC2 -> CLK
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { oled_cs_n }];   # JC3 -> CS
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { oled_dc }];     # JC4 -> DC
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { oled_res_n }];  # JC7 -> RST

## Asenkron giris
set_false_path -from [get_ports { btn0 }];
