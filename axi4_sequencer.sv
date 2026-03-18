`ifndef AXI4_SEQUENCER_SV
`define AXI4_SEQUENCER_SV

`include "axi4_transaction.sv"

class axi4_sequencer extends uvm_sequencer #(axi4_transaction);
  `uvm_component_utils(axi4_sequencer)

  function new(string name = "axi4_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building sequencer: %s", get_name()), UVM_HIGH)
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Connecting sequencer: %s", get_name()), UVM_HIGH)
  endfunction

endclass : axi4_sequencer

`endif // AXI4_SEQUENCER_SV
