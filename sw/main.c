/*
 * main.c - servo_ctrl IP icin terminal arayuzu (bare-metal, Zynq PS)
 *
 * PS'in tek gorevi: UART'tan komut okumak ve servo_ctrl register'larina
 * yazmak/okumak. Encoder, aci hesabi ve PWM tamamen PL'de calisir.
 *
 * Komutlar (115200 8N1):
 *   +30 / -45     goreceli don            (MOVE)
 *   =90           bu aciya git            (ANGLE)
 *   c             ortala (90)             (CTRL bit1)
 *   on / off      yazilimla etkinlestir   (CTRL bit0)
 *   step 10       encoder tik basina derece
 *   min 500       0 derecenin darbesi (us)
 *   max 2500      180 derecenin darbesi (us)
 *   ?             durumu yaz
 *   h             yardim
 */

#include <string.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"

extern char inbyte(void);

/* ------------------------------------------------------------------ */
/* IP taban adresi: Vitis'in xparameters.h'si verir, yoksa elle        */
/* ------------------------------------------------------------------ */
#if defined(XPAR_SERVO_CTRL_0_BASEADDR)
#define SERVO_BASE  XPAR_SERVO_CTRL_0_BASEADDR
#elif defined(XPAR_SERVO_CTRL_0_S00_AXI_BASEADDR)
#define SERVO_BASE  XPAR_SERVO_CTRL_0_S00_AXI_BASEADDR
#else
#define SERVO_BASE  0x43C00000U      /* Vivado Address Editor'deki deger */
#endif

/* Register ofsetleri */
#define REG_CTRL     0x00
#define REG_MOVE     0x04
#define REG_ANGLE    0x08
#define REG_STEP     0x0C
#define REG_MIN      0x10
#define REG_MAX      0x14
#define REG_STATUS   0x18
#define REG_PULSE    0x1C

#define CTRL_EN      0x1
#define CTRL_CENTER  0x2

static inline void reg_wr(u32 off, u32 val) { Xil_Out32(SERVO_BASE + off, val); }
static inline u32  reg_rd(u32 off)          { return Xil_In32(SERVO_BASE + off); }

/* ------------------------------------------------------------------ */
/* UART'tan bir satir oku (yankili, backspace destekli)               */
/* ------------------------------------------------------------------ */
static int read_line(char *buf, int max)
{
    int n = 0;
    for (;;) {
        char c = inbyte();
        if (c == '\r' || c == '\n') {
            if (n == 0) continue;               /* bos satirlari yut */
            xil_printf("\r\n");
            buf[n] = '\0';
            return n;
        }
        if ((c == 0x08 || c == 0x7F) && n > 0) { /* backspace */
            n--;
            xil_printf("\b \b");
            continue;
        }
        if (c >= 0x20 && c < 0x7F && n < max - 1) {
            buf[n++] = c;
            xil_printf("%c", c);
        }
    }
}

/* ------------------------------------------------------------------ */
/* Isaretli tam sayi ayristir. Basarili ise 1 doner.                   */
/* ------------------------------------------------------------------ */
static int parse_int(const char *s, int *out)
{
    int sign = 1, val = 0, digits = 0;

    while (*s == ' ') s++;
    if (*s == '+') s++;
    else if (*s == '-') { sign = -1; s++; }

    while (*s >= '0' && *s <= '9') {
        val = val * 10 + (*s - '0');
        if (val > 100000) return 0;             /* sacma buyuk */
        s++; digits++;
    }
    while (*s == ' ') s++;
    if (digits == 0 || *s != '\0') return 0;

    *out = sign * val;
    return 1;
}

/* ------------------------------------------------------------------ */
/* Durum yazdir                                                        */
/* ------------------------------------------------------------------ */
static void print_status(void)
{
    u32 st = reg_rd(REG_STATUS);

    xil_printf("  aci=%d  darbe=%d us  [min=%d max=%d adim=%d]",
               (int)reg_rd(REG_ANGLE), (int)reg_rd(REG_PULSE),
               (int)reg_rd(REG_MIN), (int)reg_rd(REG_MAX),
               (int)reg_rd(REG_STEP));

    xil_printf("  %s", (st & 0x4) ? "ETKIN" : "KAPALI (SW0 veya off)");
    if (st & 0x1) xil_printf("  <alt sinir>");
    if (st & 0x2) xil_printf("  <ust sinir>");
    xil_printf("\r\n");
}

static void print_help(void)
{
    xil_printf("\r\nKomutlar:\r\n");
    xil_printf("  +30 / -45    goreceli don\r\n");
    xil_printf("  =90          bu aciya git (0..180)\r\n");
    xil_printf("  c            ortala\r\n");
    xil_printf("  on / off     servoyu yazilimla ac / kapat\r\n");
    xil_printf("  step N       encoder tik basina derece (1..90)\r\n");
    xil_printf("  min N        0 derece darbesi, us\r\n");
    xil_printf("  max N        180 derece darbesi, us\r\n");
    xil_printf("  ?            durum\r\n");
    xil_printf("  h            bu yardim\r\n\r\n");
}

/* ------------------------------------------------------------------ */
/* Komut yorumlayici                                                   */
/* ------------------------------------------------------------------ */
static void handle(char *cmd)
{
    int v;

    if (cmd[0] == '+' || cmd[0] == '-') {               /* goreceli */
        if (!parse_int(cmd, &v)) goto bad;
        reg_wr(REG_MOVE, (u32)v);
    }
    else if (cmd[0] == '=') {                           /* mutlak */
        if (!parse_int(cmd + 1, &v) || v < 0) goto bad;
        reg_wr(REG_ANGLE, (u32)v);
    }
    else if (strcmp(cmd, "c") == 0) {
        reg_wr(REG_CTRL, reg_rd(REG_CTRL) | CTRL_CENTER);
    }
    else if (strcmp(cmd, "on") == 0) {
        reg_wr(REG_CTRL, CTRL_EN);
    }
    else if (strcmp(cmd, "off") == 0) {
        reg_wr(REG_CTRL, 0);
    }
    else if (strncmp(cmd, "step ", 5) == 0) {
        if (!parse_int(cmd + 5, &v) || v < 1 || v > 90) goto bad;
        reg_wr(REG_STEP, (u32)v);
    }
    else if (strncmp(cmd, "min ", 4) == 0) {
        if (!parse_int(cmd + 4, &v) || v < 300 || v >= (int)reg_rd(REG_MAX)) {
            xil_printf("  min 300..(max-1) arasinda olmali\r\n");
            return;
        }
        reg_wr(REG_MIN, (u32)v);
    }
    else if (strncmp(cmd, "max ", 4) == 0) {
        if (!parse_int(cmd + 4, &v) || v > 2700 || v <= (int)reg_rd(REG_MIN)) {
            xil_printf("  max (min+1)..2700 arasinda olmali\r\n");
            return;
        }
        reg_wr(REG_MAX, (u32)v);
    }
    else if (strcmp(cmd, "?") == 0) {
        /* sadece durum yazilacak */
    }
    else if (strcmp(cmd, "h") == 0) {
        print_help();
        return;
    }
    else {
        goto bad;
    }

    print_status();
    return;

bad:
    xil_printf("  anlasilmadi: '%s'  (yardim icin h)\r\n", cmd);
}

int main(void)
{
    char line[32];

    xil_printf("\r\n=== Zybo servo kontrol ===\r\n");
    xil_printf("servo_ctrl taban adresi: 0x%08x\r\n", (unsigned)SERVO_BASE);
    print_help();
    print_status();

    for (;;) {
        xil_printf("> ");
        read_line(line, sizeof(line));
        handle(line);
    }
    return 0;
}
