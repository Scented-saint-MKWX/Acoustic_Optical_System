# ===========================================================================
# Firmware Makefile for RISC-V RV32I
# Requires: riscv32-unknown-elf-gcc (or riscv64-unknown-elf-gcc with -march=rv32i)
# ===========================================================================

PREFIX   ?= riscv32-unknown-elf-
CC        = $(PREFIX)gcc
AS        = $(PREFIX)as
LD        = $(PREFIX)ld
OBJCOPY   = $(PREFIX)objcopy
OBJDUMP   = $(PREFIX)objdump

CFLAGS    = -march=rv32i -mabi=ilp32 -Os -Wall -Wextra \
            -ffreestanding -nostdlib -Iinclude
ASFLAGS   = -march=rv32i -mabi=ilp32
LDFLAGS   = -T linker.ld -nostdlib

SRCS_C    = main.c
SRCS_S    = startup.S

OBJS      = startup.o main.o

TARGET    = firmware

.PHONY: all clean hex

all: $(TARGET).hex $(TARGET).dis

# Assembly
startup.o: startup.S
	$(AS) $(ASFLAGS) -o $@ $<

# C source
main.o: main.c include/soc_regs.h include/uart.h include/gpio.h include/spi.h include/beamform.h include/fft_ctrl.h include/laser_ctrl.h
	$(CC) $(CFLAGS) -c -o $@ $<

# Link
$(TARGET).elf: $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Generate raw binary
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Generate Verilog hex file for $readmemh
$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

# Disassembly for debugging
$(TARGET).dis: $(TARGET).elf
	$(OBJDUMP) -d -M no-aliases $< > $@

clean:
	rm -f *.o *.elf *.bin *.hex *.dis
