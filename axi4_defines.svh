`ifndef AXI4_DEFINES_SVH
`define AXI4_DEFINES_SVH

// AXI4 Data Width Parameters
`define AXI4_DATA_WIDTH      256
`define AXI4_ADDR_WIDTH      32
`define AXI4_ID_WIDTH        8
`define AXI4_USER_WIDTH      8

// Derived parameters
`define AXI4_STRB_WIDTH      (`AXI4_DATA_WIDTH / 8)

`endif // AXI4_DEFINES_SVH
