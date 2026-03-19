`ifndef AXI4_DEFINES_SVH
`define AXI4_DEFINES_SVH

// AXI4 Data Width Parameters
`define AXI4_DATA_WIDTH      32
`define AXI4_ADDR_WIDTH      32
`define AXI4_ID_WIDTH        4
`define AXI4_USER_WIDTH      1

// Derived parameters
`define AXI4_STRB_WIDTH      (`AXI4_DATA_WIDTH / 8)

// Maximum burst length (AXI4 supports up to 256 beats)
`define AXI4_MAX_BURST_LEN   256

// Timeout defaults (in clock cycles)
`define AXI4_DEFAULT_WTIMEOUT  1000
`define AXI4_DEFAULT_RTIMEOUT  1000

// Outstanding transaction defaults
`define AXI4_DEFAULT_MAX_OUTSTANDING  8

`endif // AXI4_DEFINES_SVH
