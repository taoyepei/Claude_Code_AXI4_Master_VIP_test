`ifndef AXI4_SEQUENCE_SV
`define AXI4_SEQUENCE_SV

`include "axi4_transaction.sv"

class axi4_sequence extends uvm_sequence #(axi4_transaction);
  `uvm_object_utils(axi4_sequence)
  `uvm_declare_p_sequencer(uvm_sequencer #(axi4_transaction))

  rand int m_num_transactions;
  rand axi4_trans_type_t m_default_trans_type;
  rand axi4_burst_t      m_default_burst;
  rand int               m_min_len;
  rand int               m_max_len;

  constraint c_num_trans {
    m_num_transactions inside {[1:100]};
  }

  constraint c_len_range {
    m_min_len >= 0;
    m_max_len <= 255;
    m_min_len <= m_max_len;
  }

  function new(string name = "axi4_sequence");
    super.new(name);
    m_num_transactions = 10;
    m_default_trans_type = WRITE;
    m_default_burst = INCR;
    m_min_len = 0;
    m_max_len = 15;
  endfunction

  function void pre_start();
    super.pre_start();
    `uvm_info(get_type_name(), $sformatf("Starting sequence: %s", get_name()), UVM_LOW)
  endfunction

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

    for (i = 0; i < m_num_transactions; i++) begin
      trans = axi4_transaction::type_id::create($sformatf("trans_%0d", i));

      if (!trans.randomize() with {
        m_trans_type == m_default_trans_type;
        m_burst == m_default_burst;
        m_len inside {[m_min_len:m_max_len]};
      }) begin
        `uvm_error(get_type_name(), "Randomization failed")
        return;
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

  function void post_start();
    super.post_start();
    `uvm_info(get_type_name(), $sformatf("Sequence %s completed", get_name()), UVM_LOW)
  endfunction

endclass : axi4_sequence

`endif // AXI4_SEQUENCE_SV
