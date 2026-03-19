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
| `tb_top.sv` | Complete testbench example with sample slave DUT |

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

## Quick Start

### Step 1: Set Environment Variable

```bash
# Windows
set AI_GEN_AXI4_VIP_PATH=C:\path\to\vip

# Linux
export AI_GEN_AXI4_VIP_PATH=/path/to/vip
```

### Step 2: Compile and Run

```bash
# Using VCS
vcs -sverilog -ntb_opts uvm-1.2 -f files.f tb_top.sv +incdir+.
./simv

# Using Xcelium
xrun -sv -uvm -f files.f tb_top.sv

# Using Questa
vlib work
vlog -sv -f files.f tb_top.sv +incdir+.
vsim -c -do "run -all" tb_top
```

## Integration Guide

### 1. Basic Integration (Connect to Your DUT)

```systemverilog
module your_tb;
  logic aclk;
  logic areset_n;

  // Instantiate AXI4 interface
  axi4_if axi_if (.aclk(aclk), .areset_n(areset_n));

  // Connect to your DUT
  your_dut dut (
    .clk(aclk),
    .rst_n(areset_n),
    // Connect AXI4 signals
    .awid(axi_if.awid),
    .awaddr(axi_if.awaddr),
    // ... connect all other signals
  );

  // UVM test setup
  initial begin
    uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);
    run_test("your_test");
  end
endmodule
```

### 2. Create Custom Test

```systemverilog
class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  axi4_env m_env;
  axi4_cfg m_cfg;
  virtual axi4_if m_vif;

  function new(string name = "my_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get interface
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", m_vif))
      `uvm_fatal(get_type_name(), "No vif")

    // Configure VIP
    m_cfg = axi4_cfg::type_id::create("m_cfg");
    m_cfg.m_max_outstanding = 16;

    // Set in config_db
    uvm_config_db#(axi4_cfg)::set(this, "m_env", "cfg", m_cfg);
    uvm_config_db#(virtual axi4_if)::set(this, "m_env", "vif", m_vif);

    // Create env
    m_env = axi4_env::type_id::create("m_env", this);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_sequence seq = axi4_sequence::type_id::create("seq");

    phase.raise_objection(this);

    // Configure sequence
    seq.randomize() with {
      m_num_transactions == 20;
      m_default_trans_type == READ;
      m_min_len == 0;
      m_max_len == 15;
    };

    // Start sequence
    seq.start(m_env.m_master_agent.m_sequencer);

    phase.drop_objection(this);
  endtask
endclass
```

### 3. Config Database Hierarchy

```
test (uvm_config_db::set cfg, vif)
  └── env (gets cfg, vif from test)
      └── agent (gets cfg, vif from env)
          ├── monitor (gets cfg, vif from agent)
          └── driver (gets cfg, vif from agent)
```

## Key Features

- **Burst Types**: Supports FIXED, INCR, and WRAP bursts per AXI4 protocol
- **Burst Splitting**: Automatically splits INCR bursts >16 beats into smaller bursts (max 32 beats), each with unique ID
- **2KB Boundary**: Handles 2KB address boundary splitting as required by AXI4
- **Outstanding Support**: Configurable max outstanding transactions
- **Data Before Address**: Optional mode to send W channel before AW channel
- **Statistics**: Bandwidth efficiency and latency reporting at simulation end
- **Timeout Detection**: Configurable timeout warnings for stuck transactions
- **SVA Assertions**: 12 protocol assertions checking AXI4 compliance

## Protocol Compliance

The VIP implements the following AXI4 features:
- All burst types (FIXED/INCR/WRAP) with correct length restrictions
- Unaligned transfer support via WSTRB
- All optional signals (CACHE, PROT, LOCK, QOS, REGION, USER)
- Outstanding transaction handling
- Out-of-order read data support (by ID matching)

## Important Notes

1. **Bus Width Configuration**: Always modify `axi4_defines.svh` to change bus widths, not the interface parameters
2. **Reset Behavior**: Driver waits for `areset_n` to go high before driving any signals
3. **Signal Initialization**: All driven signals are initialized to 0 during reset
4. **Config DB**: Must set both `cfg` and `vif` in config_db at each level
