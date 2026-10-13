## servo_encoder.xdc - Zybo Z7-20
## Pin numaralari Digilent Zybo-Z7-Master.xdc ile karsilastirilarak dogrulanmalidir.

## 125 MHz sistem saati
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Reset butonu ve etkinlestirme switch'i
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn0 }];
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

## Asenkron girisler zamanlama analizinden cikarilir
set_false_path -from [get_ports { btn0 sw0 enc_a enc_b enc_sw }];
