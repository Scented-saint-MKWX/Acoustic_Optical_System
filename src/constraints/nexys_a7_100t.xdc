## =============================================================================
## Nexys A7-100T (XC7A100T-1CSG324C) Pin Constraints
## Acoustic-Optical SoC
## =============================================================================

## ---- Clock ----
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -period 10.000 -name sys_clk [get_ports CLK100MHZ]

## ---- Reset (active-low pushbutton) ----
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]

## ---- USB-UART ----
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports UART_RXD_OUT]
set_property -dict { PACKAGE_PIN C4  IOSTANDARD LVCMOS33 } [get_ports UART_TXD_IN]

## ---- LEDs ----
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {LED[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {LED[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {LED[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {LED[3]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {LED[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {LED[5]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {LED[6]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {LED[7]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {LED[8]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports {LED[9]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {LED[10]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports {LED[11]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {LED[12]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {LED[13]}]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {LED[14]}]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports {LED[15]}]

## ---- Switches ----
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {SW[0]}]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {SW[1]}]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports {SW[2]}]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports {SW[3]}]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports {SW[4]}]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {SW[5]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {SW[6]}]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports {SW[7]}]
set_property -dict { PACKAGE_PIN T8  IOSTANDARD LVCMOS18 } [get_ports {SW[8]}]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS18 } [get_ports {SW[9]}]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports {SW[10]}]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports {SW[11]}]
set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports {SW[12]}]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports {SW[13]}]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports {SW[14]}]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {SW[15]}]

## ---- Pmod JA: PDM Microphone Array ----
## JA[1] = PDM_CLK (output)
## JA[2] = PDM_DATA[0] (input)
## JA[3] = PDM_DATA[1] (input)
## JA[4] = PDM_DATA[2] (input)
## JA[7] = PDM_DATA[3] (input)
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports JA_PDM_CLK]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {JA_PDM_DATA[0]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {JA_PDM_DATA[1]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {JA_PDM_DATA[2]}]
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports {JA_PDM_DATA[3]}]

## ---- Pmod JB: Laser Vibrometer ADC (SPI) ----
## JB[1] = ADC_CS_N   (output)
## JB[2] = ADC_MOSI   (output)
## JB[3] = ADC_MISO   (input)
## JB[4] = ADC_SCLK   (output)
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports JB_ADC_CS_N]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports JB_ADC_MOSI]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports JB_ADC_MISO]
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports JB_ADC_SCLK]

## ---- Timing Constraints ----
## All I/O assumed synchronous to the 100 MHz clock
set_input_delay  -clock sys_clk -max 5.0 [get_ports {JA_PDM_DATA[*]}]
set_input_delay  -clock sys_clk -min 0.0 [get_ports {JA_PDM_DATA[*]}]
set_output_delay -clock sys_clk -max 5.0 [get_ports JA_PDM_CLK]

set_input_delay  -clock sys_clk -max 5.0 [get_ports JB_ADC_MISO]
set_input_delay  -clock sys_clk -min 0.0 [get_ports JB_ADC_MISO]
set_output_delay -clock sys_clk -max 5.0 [get_ports {JB_ADC_SCLK JB_ADC_CS_N JB_ADC_MOSI}]

## ---- Configuration ----
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
