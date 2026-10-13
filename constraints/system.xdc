## system.xdc - Zybo Z7-20, PS + servo_ctrl IP (encoder + servo + OLED)
## Saat PS'ten (FCLK_CLK0, 100 MHz) geldigi icin create_clock satiri yok;
## Vivado o kisiti Zynq blogundan kendisi uretir.

## Donanimsal etkinlestirme / acil durdurma
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { sw0 }];

## LED'ler
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## KY-040 - Pmod JE
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports { enc_a }];   # JE1 <- CLK
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports { enc_b }];   # JE2 <- DT
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports { enc_sw }];  # JE3 <- SW

## Servo sinyali - Pmod JD pin 1
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { servo_out }];

## OLED - Pmod JC
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { oled_mosi }];   # JC1 -> DIN
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports { oled_sclk }];   # JC2 -> CLK
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { oled_cs_n }];   # JC3 -> CS
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { oled_dc }];     # JC4 -> DC
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { oled_res_n }];  # JC7 -> RST

## Asenkron girisler zamanlama analizinden cikarilir
set_false_path -from [get_ports { sw0 enc_a enc_b enc_sw }];
