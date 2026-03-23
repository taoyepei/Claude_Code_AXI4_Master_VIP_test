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

  function new(string name = "axi4_sequence");
    super.new(name);
    m_num_transactions = 10;
    m_default_trans_type = WRITE;
    m_default_burst = INCR;
    m_min_len = 0;
    m_max_len = 15;
    m_start_addr = 64'h0;
    m_use_start_addr = 0;
    m_addr_increment = 64'h1000;  // Default 4KB increment
  endfunction

  task pre_start();
    super.pre_start();
    `uvm_info(get_type_name(), $sformatf("Starting sequence: %s", get_name()), UVM_LOW)
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
        if (!trans.randomize() with {
          m_trans_type == m_default_trans_type;
          m_burst == m_default_burst;
          m_len inside {[m_min_len:m_max_len]};
          m_addr == current_addr;
        }) begin
          `uvm_error(get_type_name(), "Randomization failed")
          return;
        end
        // Increment address for next transaction
        current_addr = current_addr + m_addr_increment;
      end else begin
        // Use fully random address (original behavior)
        if (!trans.randomize() with {
          m_trans_type == m_default_trans_type;
          m_burst == m_default_burst;
          m_len inside {[m_min_len:m_max_len]};
        }) begin
          `uvm_error(get_type_name(), "Randomization failed")
          return;
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
