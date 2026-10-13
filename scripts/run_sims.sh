#!/usr/bin/env bash
# Butun testbench'leri Icarus Verilog ile calistirir.
# Kullanim:  ./scripts/run_sims.sh        (repo kok dizininden)
set -u
cd "$(dirname "$0")/.."
mkdir -p build
RTL=rtl; IP=ip/servo_ctrl; TB=sim
pass=0; fail=0

run() {   # run <isim> <dosyalar...>
    local name=$1; shift
    if ! iverilog -g2005 -o build/$name.vvp "$@" 2> build/$name.log; then
        echo "[DERLEME HATASI] $name"; cat build/$name.log; fail=$((fail+1)); return
    fi
    if vvp -n build/$name.vvp > build/$name.out 2>&1 && grep -q "SONUC: PASS" build/$name.out; then
        echo "[PASS] $name"; pass=$((pass+1))
    else
        echo "[FAIL] $name  (ayrinti: build/$name.out)"; fail=$((fail+1))
    fi
}

run tb_servo_pwm      $RTL/servo_pwm.v $TB/tb_servo_pwm.v
run tb_rotary_encoder $RTL/debounce.v $RTL/rotary_encoder.v $TB/tb_rotary_encoder.v
run tb_angle_ctrl     $RTL/angle_ctrl.v $TB/tb_angle_ctrl.v
run tb_angle_ctrl_rt  $RTL/angle_ctrl_rt.v $TB/tb_angle_ctrl_rt.v
run tb_spi_tx         $RTL/spi_tx.v $TB/tb_spi_tx.v
run tb_oled_ctrl      $RTL/spi_tx.v $RTL/oled_ctrl.v $TB/tb_oled_ctrl.v
run tb_oled_text      $RTL/bin2bcd.v $RTL/font_rom.v $RTL/oled_text.v $TB/tb_oled_text.v
run tb_servo_ctrl     $IP/servo_ctrl.v $IP/servo_ctrl_regs.v $RTL/*.v $TB/tb_servo_ctrl.v

echo "------------------------------"
echo "PASS: $pass   FAIL: $fail"
[ $fail -eq 0 ]
