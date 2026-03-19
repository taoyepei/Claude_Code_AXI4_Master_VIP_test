`ifndef AXI4_IF_SV
`define AXI4_IF_SV

`include "axi4_defines.svh"
`include "axi4_pkg.sv"

interface axi4_if (
  input logic aclk,
  input logic areset_n
);

  // Signal declarations - must be before clocking blocks
  // Write address channel
  logic [`AXI4_ID_WIDTH-1:0]   awid;
  logic [`AXI4_ADDR_WIDTH-1:0] awaddr;
  logic [7:0]                  awlen;
  logic [2:0]                  awsize;
  logic [1:0]                  awburst;
  logic                        awlock;
  logic [3:0]                  awcache;
  logic [2:0]                  awprot;
  logic [3:0]                  awqos;
  logic [3:0]                  awregion;
  logic [`AXI4_USER_WIDTH-1:0] awuser;
  logic                        awvalid;
  logic                        awready;

  // Write data channel
  logic [`AXI4_DATA_WIDTH-1:0] wdata;
  logic [`AXI4_STRB_WIDTH-1:0] wstrb;
  logic                        wlast;
  logic [`AXI4_USER_WIDTH-1:0] wuser;
  logic                        wvalid;
  logic                        wready;

  // Write response channel
  logic [`AXI4_ID_WIDTH-1:0]   bid;
  logic [1:0]                  bresp;
  logic [`AXI4_USER_WIDTH-1:0] buser;
  logic                        bvalid;
  logic                        bready;

  // Read address channel
  logic [`AXI4_ID_WIDTH-1:0]   arid;
  logic [`AXI4_ADDR_WIDTH-1:0] araddr;
  logic [7:0]                  arlen;
  logic [2:0]                  arsize;
  logic [1:0]                  arburst;
  logic                        arlock;
  logic [3:0]                  arcache;
  logic [2:0]                  arprot;
  logic [3:0]                  arqos;
  logic [3:0]                  arregion;
  logic [`AXI4_USER_WIDTH-1:0] aruser;
  logic                        arvalid;
  logic                        arready;

  // Read data channel
  logic [`AXI4_ID_WIDTH-1:0]   rid;
  logic [`AXI4_DATA_WIDTH-1:0] rdata;
  logic [1:0]                  rresp;
  logic                        rlast;
  logic [`AXI4_USER_WIDTH-1:0] ruser;
  logic                        rvalid;
  logic                        rready;

  // Clocking blocks - after signal declarations
  clocking m_cb @(posedge aclk);
    default input #1ns output #1ns;

    // Write address channel
    output awid;
    output awaddr;
    output awlen;
    output awsize;
    output awburst;
    output awlock;
    output awcache;
    output awprot;
    output awqos;
    output awregion;
    output awuser;
    output awvalid;
    input  awready;

    // Write data channel
    output wdata;
    output wstrb;
    output wlast;
    output wuser;
    output wvalid;
    input  wready;

    // Write response channel
    input  bid;
    input  bresp;
    input  buser;
    input  bvalid;
    output bready;

    // Read address channel
    output arid;
    output araddr;
    output arlen;
    output arsize;
    output arburst;
    output arlock;
    output arcache;
    output arprot;
    output arqos;
    output arregion;
    output aruser;
    output arvalid;
    input  arready;

    // Read data channel
    input  rid;
    input  rdata;
    input  rresp;
    input  rlast;
    input  ruser;
    input  rvalid;
    output rready;
  endclocking : m_cb

  clocking s_cb @(posedge aclk);
    default input #1ns output #1ns;

    input  awid;
    input  awaddr;
    input  awlen;
    input  awsize;
    input  awburst;
    input  awlock;
    input  awcache;
    input  awprot;
    input  awqos;
    input  awregion;
    input  awuser;
    input  awvalid;
    output awready;

    input  wdata;
    input  wstrb;
    input  wlast;
    input  wuser;
    input  wvalid;
    output wready;

    output bid;
    output bresp;
    output buser;
    output bvalid;
    input  bready;

    input  arid;
    input  araddr;
    input  arlen;
    input  arsize;
    input  arburst;
    input  arlock;
    input  arcache;
    input  arprot;
    input  arqos;
    input  arregion;
    input  aruser;
    input  arvalid;
    output arready;

    output rid;
    output rdata;
    output rresp;
    output rlast;
    output ruser;
    output rvalid;
    input  rready;
  endclocking : s_cb

  clocking mon_cb @(posedge aclk);
    default input #1ns output #1ns;

    input awid;
    input awaddr;
    input awlen;
    input awsize;
    input awburst;
    input awlock;
    input awcache;
    input awprot;
    input awqos;
    input awregion;
    input awuser;
    input awvalid;
    input awready;

    input wdata;
    input wstrb;
    input wlast;
    input wuser;
    input wvalid;
    input wready;

    input bid;
    input bresp;
    input buser;
    input bvalid;
    input bready;

    input arid;
    input araddr;
    input arlen;
    input arsize;
    input arburst;
    input arlock;
    input arcache;
    input arprot;
    input arqos;
    input arregion;
    input aruser;
    input arvalid;
    input arready;

    input rid;
    input rdata;
    input rresp;
    input rlast;
    input ruser;
    input rvalid;
    input rready;
  endclocking : mon_cb

  // Assertion properties
  property awvalid_stable;
    @(posedge aclk) disable iff (!areset_n)
    (awvalid && !awready) |=> awvalid;
  endproperty

  property arvalid_stable;
    @(posedge aclk) disable iff (!areset_n)
    (arvalid && !arready) |=> arvalid;
  endproperty

  property wvalid_stable;
    @(posedge aclk) disable iff (!areset_n)
    (wvalid && !wready) |=> wvalid;
  endproperty

  property wlast_correct;
    logic [7:0] beat_cnt;
    @(posedge aclk) disable iff (!areset_n)
    ($rose(wvalid && wready), beat_cnt = 0) ##0
    (wvalid && wready, beat_cnt++)[*1:$] ##0
    (wlast && wvalid && wready) |-> (beat_cnt == $past(awlen) + 1);
  endproperty

  property rlast_correct;
    @(posedge aclk) disable iff (!areset_n)
    (rvalid && rlast) |-> (rvalid && rlast);
  endproperty

  property axlen_range_valid;
    @(posedge aclk) disable iff (!areset_n)
    (awvalid |-> (awlen <= 8'd255));
  endproperty

  property axlen_range_valid_ar;
    @(posedge aclk) disable iff (!areset_n)
    (arvalid |-> (arlen <= 8'd255));
  endproperty

  property fixed_burst_len_aw;
    @(posedge aclk) disable iff (!areset_n)
    ((awvalid && awburst == 2'b00) |-> (awlen <= 8'd15));
  endproperty

  property fixed_burst_len_ar;
    @(posedge aclk) disable iff (!areset_n)
    ((arvalid && arburst == 2'b00) |-> (arlen <= 8'd15));
  endproperty

  property wrap_burst_len_aw;
    @(posedge aclk) disable iff (!areset_n)
    ((awvalid && awburst == 2'b10) |-> (awlen inside {8'd1, 8'd3, 8'd7, 8'd15}));
  endproperty

  property wrap_burst_len_ar;
    @(posedge aclk) disable iff (!areset_n)
    ((arvalid && arburst == 2'b10) |-> (arlen inside {8'd1, 8'd3, 8'd7, 8'd15}));
  endproperty

  property axburst_encoding_aw;
    @(posedge aclk) disable iff (!areset_n)
    (awvalid |-> (awburst != 2'b11));
  endproperty

  property axburst_encoding_ar;
    @(posedge aclk) disable iff (!areset_n)
    (arvalid |-> (arburst != 2'b11));
  endproperty

  property axsize_range_aw;
    @(posedge aclk) disable iff (!areset_n)
    (awvalid |-> ((1 << awsize) <= (`AXI4_DATA_WIDTH / 8)));
  endproperty

  property axsize_range_ar;
    @(posedge aclk) disable iff (!areset_n)
    (arvalid |-> ((1 << arsize) <= (`AXI4_DATA_WIDTH / 8)));
  endproperty

  property wdata_stable;
    @(posedge aclk) disable iff (!areset_n)
    (wvalid && !wready) |=> ($stable(wdata) && $stable(wstrb) && $stable(wlast));
  endproperty

  property ardata_stable;
    @(posedge aclk) disable iff (!areset_n)
    (arvalid && !arready) |=>
    ($stable(arid) && $stable(araddr) && $stable(arlen) &&
     $stable(arsize) && $stable(arburst) && $stable(arlock) &&
     $stable(arcache) && $stable(arprot) && $stable(arqos) &&
     $stable(arregion) && $stable(aruser));
  endproperty

  property wstrb_width_match;
    @(posedge aclk) disable iff (!areset_n)
    (wvalid |-> ($bits(wstrb) == `AXI4_DATA_WIDTH / 8));
  endproperty

  // Unaligned first beat WSTRB check
  property unaligned_first_beat_wstrb;
    logic [`AXI4_ADDR_WIDTH-1:0] awaddr_sample;
    logic [2:0] awsize_sample;
    int lower_byte;
    int bytes_per_beat;
    @(posedge aclk) disable iff (!areset_n)
    ($rose(awvalid && awready), awaddr_sample = awaddr, awsize_sample = awsize) ##0
    (1'b1, bytes_per_beat = (1 << awsize_sample),
          lower_byte = awaddr_sample % bytes_per_beat) ##[0:$]
    ((wvalid && wready && !wlast) |->
     (lower_byte == 0) ||
     (wstrb == (((1 << bytes_per_beat) - 1) << lower_byte)));
  endproperty

  // Assertions
  assert_awvalid_stable : assert property (awvalid_stable)
    else `uvm_error("AXI4_IF", "AWVALID not stable until AWREADY")

  assert_arvalid_stable : assert property (arvalid_stable)
    else `uvm_error("AXI4_IF", "ARVALID not stable until ARREADY")

  assert_wvalid_stable : assert property (wvalid_stable)
    else `uvm_error("AXI4_IF", "WVALID not stable until WREADY")

  assert_wlast_correct : assert property (wlast_correct)
    else `uvm_error("AXI4_IF", "WLAST not asserted at correct beat")

  assert_rlast_correct : assert property (rlast_correct)
    else `uvm_error("AXI4_IF", "RLAST not asserted at correct beat")

  assert_axlen_range_aw : assert property (axlen_range_valid)
    else `uvm_error("AXI4_IF", "AWLEN out of range (0-255)")

  assert_axlen_range_ar : assert property (axlen_range_valid_ar)
    else `uvm_error("AXI4_IF", "ARLEN out of range (0-255)")

  assert_fixed_burst_len_aw : assert property (fixed_burst_len_aw)
    else `uvm_error("AXI4_IF", "AW FIXED burst length must be <= 16")

  assert_fixed_burst_len_ar : assert property (fixed_burst_len_ar)
    else `uvm_error("AXI4_IF", "AR FIXED burst length must be <= 16")

  assert_wrap_burst_len_aw : assert property (wrap_burst_len_aw)
    else `uvm_error("AXI4_IF", "AW WRAP burst length must be 2,4,8,16")

  assert_wrap_burst_len_ar : assert property (wrap_burst_len_ar)
    else `uvm_error("AXI4_IF", "AR WRAP burst length must be 2,4,8,16")

  assert_axburst_encoding_aw : assert property (axburst_encoding_aw)
    else `uvm_error("AXI4_IF", "AWBURST encoding invalid (cannot be 2'b11)")

  assert_axburst_encoding_ar : assert property (axburst_encoding_ar)
    else `uvm_error("AXI4_IF", "ARBURST encoding invalid (cannot be 2'b11)")

  assert_axsize_range_aw : assert property (axsize_range_aw)
    else `uvm_error("AXI4_IF", "AWSIZE exceeds data width")

  assert_axsize_range_ar : assert property (axsize_range_ar)
    else `uvm_error("AXI4_IF", "ARSIZE exceeds data width")

  assert_wdata_stable : assert property (wdata_stable)
    else `uvm_error("AXI4_IF", "WDATA/WSTRB/WLAST not stable during handshake")

  assert_ardata_stable : assert property (ardata_stable)
    else `uvm_error("AXI4_IF", "AR channel signals not stable until ARREADY")

  assert_wstrb_width : assert property (wstrb_width_match)
    else `uvm_error("AXI4_IF", "WSTRB width mismatch")

  assert_unaligned_first_beat : assert property (unaligned_first_beat_wstrb)
    else `uvm_error("AXI4_IF", "Unaligned first beat WSTRB incorrect - lower bytes must be 0")

endinterface : axi4_if

`endif // AXI4_IF_SV
