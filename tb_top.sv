# AXI4 Master VIP

AXI4 Master VIP (Verification IP) for UVM-based verification environments.

## File Structure

| File | Description |
|------|-------------|
| `axi4_defines.svh` | Macro definitions for data width, address width, ID width, etc. |
| `axi4_pkg.sv` | Package definition including burst types, response types, and configuration class (`axi4_cfg`) |
| `axi4_if.sv` | AXI4 interface with clocking blocks (m_cb/s_cb/mon_cb) and SVA assertions |
| `axi4_transaction.sv` | Transaction class with address, data, response fields and timing info |
| `axi4_sequence.sv` | Base sequence class for generating transactions |
| `axi4_sequencer.sv` | UVM sequencer connecting sequence to driver |
| `axi4_master_driver.sv` | Master driver implementing AXI4 protocol with burst splitting and outstanding support |
| `axi4_monitor.sv` | Monitor with bandwidth efficiency and latency statistics |
| `axi4_master_agent.sv` | Agent containing driver, sequencer, and monitor |
| `axi4_env.sv` | Top-level environment class |
| `files.f` | File list for compilation |

## Configuration Options

The VIP is configured through the `axi4_cfg` class:

```systemverilog
class axi4_cfg extends uvm_object;
  // Bus width parameters (must match `axi4_defines.svh` settings)
  int m_data_width;      // Data bus width (default: 32, modify axi4_defines.svh for other widths)
  int m_addr_width;      // Address bus width (default: 32)
  int m_id_width;        // ID bus width (default: 4)

  // Protocol parameters
  int m_max_outstanding;       // Max outstanding transactions (default: 8)
  int m_trans_interval;        // Cycles between transactions (default: 0)
  int m_data_before_addr_osd;  // Max W beats before AW (default: 0)

  // Timeout parameters (in clock cycles)
  int m_wtimeout;        // Write timeout threshold (default: 1000)
  int m_rtimeout;        // Read timeout threshold (default: 1000)

  // Feature enables
  bit m_support_data_before_addr;  // Enable W before AW mode (default: 0)
endclass
```

### Modifying Bus Widths

To change bus widths, edit `axi4_defines.svh`:

```systemverilog
// Example: 64-bit data bus
`define AXI4_DATA_WIDTH      64
`define AXI4_ADDR_WIDTH      32
`define AXI4_ID_WIDTH        8
`define AXI4_USER_WIDTH      1
```

## Complete Usage Example

### Step 1: Create Testbench File

Create a file named `tb_top.sv`:

```systemverilog
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// Include VIP files
`include "axi4_defines.svh"
`include "axi4_pkg.sv"
`include "axi4_if.sv"
`include "axi4_transaction.sv"
`include "axi4_sequence.sv"
`include "axi4_sequencer.sv"
`include "axi4_master_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_master_agent.sv"
`include "axi4_env.sv"

import axi4_pkg::*;

// Simple AXI4 Slave (example DUT)
module axi4_slave (
  input  logic aclk,
  input  logic areset_n,
  // Write address channel
  input  logic [`AXI4_ID_WIDTH-1:0]   awid,
  input  logic [`AXI4_ADDR_WIDTH-1:0] awaddr,
  input  logic [7:0]                  awlen,
  input  logic [2:0]                  awsize,
  input  logic [1:0]                  awburst,
  input  logic                        awlock,
  input  logic [3:0]                  awcache,
  input  logic [2:0]                  awprot,
  input  logic [3:0]                  awqos,
  input  logic [3:0]                  awregion,
  input  logic [`AXI4_USER_WIDTH-1:0] awuser,
  input  logic                        awvalid,
  output logic                        awready,
  // Write data channel
  input  logic [`AXI4_DATA_WIDTH-1:0] wdata,
  input  logic [`AXI4_STRB_WIDTH-1:0] wstrb,
  input  logic                        wlast,
  input  logic [`AXI4_USER_WIDTH-1:0] wuser,
  input  logic                        wvalid,
  output logic                        wready,
  // Write response channel
  output logic [`AXI4_ID_WIDTH-1:0]   bid,
  output logic [1:0]                  bresp,
  output logic [`AXI4_USER_WIDTH-1:0] buser,
  output logic                        bvalid,
  input  logic                        bready,
  // Read address channel
  input  logic [`AXI4_ID_WIDTH-1:0]   arid,
  input  logic [`AXI4_ADDR_WIDTH-1:0] araddr,
  input  logic [7:0]                  arlen,
  input  logic [2:0]                  arsize,
  input  logic [1:0]                  arburst,
  input  logic                        arlock,
  input  logic [3:0]                  arcache,
  input  logic [2:0]                  arprot,
  input  logic [3:0]                  arqos,
  input  logic [3:0]                  arregion,
  input  logic [`AXI4_USER_WIDTH-1:0] aruser,
  input  logic                        arvalid,
  output logic                        arready,
  // Read data channel
  output logic [`AXI4_ID_WIDTH-1:0]   rid,
  output logic [`AXI4_DATA_WIDTH-1:0] rdata,
  output logic [1:0]                  rresp,
  output logic                        rlast,
  output logic [`AXI4_USER_WIDTH-1:0] ruser,
  output logic                        rvalid,
  input  logic                        rready
);

  // Simple slave implementation
  logic [`AXI4_ID_WIDTH-1:0]   awid_reg;
  logic [7:0]                  awlen_reg;
  logic [7:0]                  wcount;

  // AW channel
  always_ff @(posedge aclk or negedge areset_n) begin
    if (!areset_n) begin
      awready <= 1'b0;
      awid_reg <= '0;
      awlen_reg <= '0;
    end else begin
      if (awvalid && !awready) begin
        awready <= 1'b1;
        awid_reg <= awid;
        awlen_reg <= awlen;
      end else begin
        awready <= 1'b0;
      end
    end
  end

  // W channel
  always_ff @(posedge aclk or negedge areset_n) begin
    if (!areset_n) begin
      wready <= 1'b0;
      wcount <= '0;
    end else begin
      if (wvalid && !wready) begin
        wready <= 1'b1;
        if (wlast) wcount <= '0;
        else wcount <= wcount + 1;
      end else begin
        wready <= 1'b0;
      end
    end
  end

  // B channel
  always_ff @(posedge aclk or negedge areset_n) begin
    if (!areset_n) begin
      bvalid <= 1'b0;
      bid <= '0;
      bresp <= '0;
      buser <= '0;
    end else begin
      if (wvalid && wready && wlast && !bvalid) begin
        bvalid <= 1'b1;
        bid <= awid_reg;
        bresp <= 2'b00; // OKAY
      end else if (bvalid && bready) begin
        bvalid <= 1'b0;
      end
    end
  end

  // AR channel
  logic [`AXI4_ID_WIDTH-1:0]   arid_reg;
  logic [`AXI4_ADDR_WIDTH-1:0] araddr_reg;
  logic [7:0]                  arlen_reg;

  always_ff @(posedge aclk or negedge areset_n) begin
    if (!areset_n) begin
      arready <= 1'b0;
      arid_reg <= '0;
      araddr_reg <= '0;
      arlen_reg <= '0;
    end else begin
      if (arvalid && !arready) begin
        arready <= 1'b1;
        arid_reg <= arid;
        araddr_reg <= araddr;
        arlen_reg <= arlen;
      end else begin
        arready <= 1'b0;
      end
    end
  end

  // R channel
  logic [7:0] rcount;

  always_ff @(posedge aclk or negedge areset_n) begin
    if (!areset_n) begin
      rvalid <= 1'b0;
      rid <= '0;
      rdata <= '0;
      rresp <= '0;
      rlast <= 1'b0;
      ruser <= '0;
      rcount <= '0;
    end else begin
      if (arvalid && arready) begin
        rvalid <= 1'b1;
        rid <= arid_reg;
        rdata <= {`AXI4_DATA_WIDTH/32{32'hA5A5A5A5 + araddr_reg[15:0]}};
        rresp <= 2'b00;
        ruser <= '0;
        if (arlen_reg == 0) begin
          rlast <= 1'b1;
        end else begin
          rlast <= 1'b0;
          rcount <= 8'd1;
        end
      end else if (rvalid && !rready) begin
        // Hold values
      end else if (rvalid && rready && !rlast) begin
        rcount <= rcount + 1;
        if (rcount == arlen_reg) begin
          rlast <= 1'b1;
        end
      end else if (rvalid && rready && rlast) begin
        rvalid <= 1'b0;
        rlast <= 1'b0;
      end
    end
  end

endmodule

// UVM Test
class axi4_base_test extends uvm_test;
  `uvm_component_utils(axi4_base_test)

  axi4_env m_env;
  axi4_cfg m_cfg;
  virtual axi4_if m_vif;

  function new(string name = "axi4_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get virtual interface from top
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", m_vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found")

    // Create and configure VIP
    m_cfg = axi4_cfg::type_id::create("m_cfg");

    // Set configuration in config_db for env
    uvm_config_db#(axi4_cfg)::set(this, "m_env", "cfg", m_cfg);
    uvm_config_db#(virtual axi4_if)::set(this, "m_env", "vif", m_vif);

    // Create environment
    m_env = axi4_env::type_id::create("m_env", this);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_sequence seq = axi4_sequence::type_id::create("seq");

    phase.raise_objection(this);

    // Configure sequence
    seq.randomize() with {
      m_num_transactions == 10;
      m_default_trans_type == WRITE;
      m_default_burst == INCR;
      m_min_len == 0;
      m_max_len == 7;
    };

    // Start sequence on the agent's sequencer
    seq.start(m_env.m_master_agent.m_sequencer);

    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Test completed successfully!", UVM_LOW)
  endfunction
endclass

// Top-level testbench
module tb_top;
  logic aclk;
  logic areset_n;

  // Instantiate AXI4 interface
  axi4_if axi_if (.aclk(aclk), .areset_n(areset_n));

  // Instantiate DUT (slave)
  axi4_slave dut (
    .aclk(aclk),
    .areset_n(areset_n),
    .awid(axi_if.awid),
    .awaddr(axi_if.awaddr),
    .awlen(axi_if.awlen),
    .awsize(axi_if.awsize),
    .awburst(axi_if.awburst),
    .awlock(axi_if.awlock),
    .awcache(axi_if.awcache),
    .awprot(axi_if.awprot),
    .awqos(axi_if.awqos),
    .awregion(axi_if.awregion),
    .awuser(axi_if.awuser),
    .awvalid(axi_if.awvalid),
    .awready(axi_if.awready),
    .wdata(axi_if.wdata),
    .wstrb(axi_if.wstrb),
    .wlast(axi_if.wlast),
    .wuser(axi_if.wuser),
    .wvalid(axi_if.wvalid),
    .wready(axi_if.wready),
    .bid(axi_if.bid),
    .bresp(axi_if.bresp),
    .buser(axi_if.buser),
    .bvalid(axi_if.bvalid),
    .bready(axi_if.bready),
    .arid(axi_if.arid),
    .araddr(axi_if.araddr),
    .arlen(axi_if.arlen),
    .arsize(axi_if.arsize),
    .arburst(axi_if.arburst),
    .arlock(axi_if.arlock),
    .arcache(axi_if.arcache),
    .arprot(axi_if.arprot),
    .arqos(axi_if.arqos),
    .arregion(axi_if.arregion),
    .aruser(axi_if.aruser),
    .arvalid(axi_if.arvalid),
    .arready(axi_if.arready),
    .rid(axi_if.rid),
    .rdata(axi_if.rdata),
    .rresp(axi_if.rresp),
    .rlast(axi_if.rlast),
    .ruser(axi_if.ruser),
    .rvalid(axi_if.rvalid),
    .rready(axi_if.rready)
  );

  // Clock generation
  initial begin
    aclk = 0;
    forever #5 aclk = ~aclk;  // 100MHz
  end

  // Reset generation
  initial begin
    areset_n = 0;
    #100 areset_n = 1;
  end

  // UVM start
  initial begin
    // Set virtual interface in config_db
    uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);

    // Run test
    run_test("axi4_base_test");
  end

endmodule
