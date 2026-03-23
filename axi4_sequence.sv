`ifndef AXI4_SEQUENCE_SV
`define AXI4_SEQUENCE_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here

class axi4_sequence extends uvm_sequence #(axi4_transaction);
  `uvm_object_utils(axi4_sequence)
  `uvm_declare_p_sequencer(uvm_sequencer #(axi4_transaction))

  rand int m_num_transactions;
  rand axi4_trans_type_t m_default_trans_type;
  rand axi4_burst_t      m_default_burst;
  rand int               m_min_len;
  rand int               m_max_len;
  rand bit [2:0]         m_default_size;      // Default transfer size (0-7, auto-checked)
  rand bit               m_use_default_size;  // Use m_default_size instead of random
  rand bit [63:0]        m_start_addr;        // Starting address for first transaction
  rand bit               m_use_start_addr;    // Enable address increment mode
  rand bit [63:0]        m_addr_increment;    // Address increment between transactions

  constraint c_num_trans {
    m_num_transactions inside {[1:100]};
  }

  constraint c_len_range {
    m_min_len >= 0;
    m_max_len <= 255;
    m_min_len <= m_max_len;
  }

  constraint c_addr_increment {
    m_addr_increment inside {0, 64, 128, 256, 512, 1024, 2048, 4096};
  }

  // Size must be within valid range for the data bus width
  constraint c_default_size_range {
    m_default_size inside {[0:7]};
    // Ensure (1 << m_default_size) <= (AXI4_DATA_WIDTH / 8)
    (m_use_default_size == 1) -> ((1 << m_default_size) <= (`AXI4_DATA_WIDTH / 8));
  }

  function new(string name = "axi4_sequence");
    super.new(name);
    m_num_transactions = 10;
    m_default_trans_type = WRITE;
    m_default_burst = INCR;
    m_min_len = 0;
    m_max_len = 15;
    m_default_size = 3;           // Default 8 bytes (64-bit)
    m_use_default_size = 0;       // Default: random size
    m_start_addr = 64'h0;
    m_use_start_addr = 0;
    m_addr_increment = 64'h1000;  // Default 4KB increment
  endfunction

  // Check if the configured size is valid for the data bus width
  // Call this in pre_start() after randomization to catch errors early
  function bit check_size_valid();
    int max_size;
    int max_bytes;

    max_bytes = `AXI4_DATA_WIDTH / 8;

    // Calculate max size: log2(max_bytes)
    case (max_bytes)
      1: max_size = 0;   // 8-bit data bus
      2: max_size = 1;   // 16-bit
      4: max_size = 2;   // 32-bit
      8: max_size = 3;   // 64-bit
      16: max_size = 4;  // 128-bit
      32: max_size = 5;  // 256-bit
      64: max_size = 6;  // 512-bit
      128: max_size = 7; // 1024-bit
      default: max_size = 3; // Assume 64-bit
    endcase

    if (m_use_default_size) begin
      if (m_default_size > max_size) begin
        `uvm_error(get_type_name(),
          $sformatf("Invalid m_default_size=%0d for AXI4_DATA_WIDTH=%0d (max allowed size=%0d)",
                    m_default_size, `AXI4_DATA_WIDTH, max_size))
        return 0;
      end
      // Additional check: address alignment with size
      if (m_use_start_addr && ((m_start_addr % (1 << m_default_size)) != 0)) begin
        `uvm_error(get_type_name(),
          $sformatf("Address alignment error: m_start_addr=0x%0h is not aligned to m_default_size=%0d (requires %0d-byte alignment)",
                    m_start_addr, m_default_size, (1 << m_default_size)))
        return 0;
      end
    end
    return 1;
  endfunction

  task pre_start();
    super.pre_start();
    `uvm_info(get_type_name(), $sformatf("Starting sequence: %s", get_name()), UVM_LOW)

    // Validate size configuration before starting
    if (!check_size_valid()) begin
      `uvm_fatal(get_type_name(), "Size configuration check failed - aborting sequence")
    end
  endtask

  task pre_body();
    super.pre_body();
    if (starting_phase != null) begin
      starting_phase.raise_objection(this, get_type_name());
      starting_phase.get_objection().set_propagate_mode(0);
    end
  endtask

  task body();
    axi4_transaction trans;
    int i;
    bit [63:0] current_addr;

    current_addr = m_start_addr;

    for (i = 0; i < m_num_transactions; i++) begin
      trans = axi4_transaction::type_id::create($sformatf("trans_%0d", i));

      if (m_use_start_addr) begin
        // Use specified starting address with increment
        if (m_use_default_size) begin
          // Use specified size
          if (!trans.randomize() with {
            m_trans_type == m_default_trans_type;
            m_burst == m_default_burst;
            m_len inside {[m_min_len:m_max_len]};
            m_addr == current_addr;
            m_size == m_default_size;
          }) begin
            `uvm_error(get_type_name(), "Randomization failed")
            return;
          end
        end else begin
          // Random size
          if (!trans.randomize() with {
            m_trans_type == m_default_trans_type;
            m_burst == m_default_burst;
            m_len inside {[m_min_len:m_max_len]};
            m_addr == current_addr;
          }) begin
            `uvm_error(get_type_name(), "Randomization failed")
            return;
          end
        end
        // Increment address for next transaction
        current_addr = current_addr + m_addr_increment;
      end else begin
        // Use fully random address (original behavior)
        if (m_use_default_size) begin
          // Use specified size
          if (!trans.randomize() with {
            m_trans_type == m_default_trans_type;
            m_burst == m_default_burst;
            m_len inside {[m_min_len:m_max_len]};
            m_size == m_default_size;
          }) begin
            `uvm_error(get_type_name(), "Randomization failed")
            return;
          end
        end else begin
          // Random size
          if (!trans.randomize() with {
            m_trans_type == m_default_trans_type;
            m_burst == m_default_burst;
            m_len inside {[m_min_len:m_max_len]};
          }) begin
            `uvm_error(get_type_name(), "Randomization failed")
            return;
          end
        end
      end

      `uvm_info(get_type_name(), $sformatf("Sending transaction %0d/%0d: %s",
                                           i+1, m_num_transactions, trans.convert2string()), UVM_MEDIUM)

      start_item(trans);
      finish_item(trans);
    end
  endtask

  task post_body();
    super.post_body();
    if (starting_phase != null) begin
      starting_phase.drop_objection(this, get_type_name());
    end
  endtask

  task post_start();
    super.post_start();
    `uvm_info(get_type_name(), $sformatf("Sequence %s completed", get_name()), UVM_LOW)
  endtask

endclass : axi4_sequence

`endif // AXI4_SEQUENCE_SV
