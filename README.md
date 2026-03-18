# AXI4 Master VIP

AXI4 Master VIP (Verification IP) for UVM-based verification environments.

## File Structure

| File | Description |
|------|-------------|
| `axi4_pkg.sv` | Package definition including burst types, response types, and configuration class (`axi4_cfg`) |
| `axi4_if.sv` | AXI4 interface with clocking blocks (m_cb/s_cb/mon_cb) and 12 SVA assertions |
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
  // Bus width parameters
  int m_data_width;      // Data bus width (default: 32, supports 32/64/128/256/512/1024)
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

### Configuration Examples

```systemverilog
// Default configuration
axi4_cfg cfg = axi4_cfg::type_id::create("cfg");

// 64-bit data bus with 16 outstanding transactions
cfg.m_data_width = 64;
cfg.m_max_outstanding = 16;

// Enable data-before-address mode
cfg.m_support_data_before_addr = 1;
cfg.m_data_before_addr_osd = 4;  // Allow 4 W beats before AW

// Adjust timeout thresholds
cfg.m_wtimeout = 500;
cfg.m_rtimeout = 500;
```

## Usage Example

### 1. Interface Instantiation

```systemverilog
module tb_top;
  logic aclk;
  logic areset_n;

  // Instantiate AXI4 interface
  axi4_if #(
    .DATA_WIDTH(64),
    .ADDR_WIDTH(32),
    .ID_WIDTH(4),
    .USER_WIDTH(1)
  ) axi_if (.aclk(aclk), .areset_n(areset_n));

  // Clock generation
  initial begin
    aclk = 0;
    forever #5 aclk = ~aclk;
  end

  // Reset generation
  initial begin
    areset_n = 0;
    #100 areset_n = 1;
  end

  // DUT instantiation (example)
  your_dut dut (
    .aclk(aclk),
    .areset_n(areset_n),
    // Connect to interface signals
    .awid(axi_if.awid),
    .awaddr(axi_if.awaddr),
    // ... other signals
  );
endmodule
```

### 2. UVM Testbench Setup

```systemverilog
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

    // Get virtual interface from config_db
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", m_vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found")

    // Create and configure VIP configuration
    m_cfg = axi4_cfg::type_id::create("m_cfg");
    m_cfg.m_data_width = 64;
    m_cfg.m_max_outstanding = 8;

    // Set configuration in config_db
    uvm_config_db#(axi4_cfg)::set(this, "*", "cfg", m_cfg);
    uvm_config_db#(virtual axi4_if)::set(this, "*", "vif", m_vif);

    // Create environment
    m_env = axi4_env::type_id::create("m_env", this);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_sequence seq = axi4_sequence::type_id::create("seq");

    phase.raise_objection(this);
    seq.set_sequencer(m_env.m_master_agent.m_sequencer);
    seq.randomize() with {
      m_num_transactions == 10;
      m_default_trans_type == WRITE;
      m_default_burst == INCR;
      m_min_len == 0;
      m_max_len == 15;
    };
    seq.start(null);
    phase.drop_objection(this);
  endtask
endclass
```

### 3. Running the Test

```systemverilog
module top_tb;
  // Interface and testbench setup as shown above

  initial begin
    // Set the test to run
    uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);

    // Start UVM phases
    run_test("axi4_base_test");
  end
endmodule
```

### 4. Compilation

```bash
# Using your favorite simulator (VCS/Xcelium/Questa)
vcs -sverilog -ntb_opts uvm-1.2 -f files.f +incdir+. -top top_tb
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

