`ifndef AXI4_SEQUENCER_SV
`define AXI4_SEQUENCER_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here

class axi4_sequencer extends uvm_sequencer #(axi4_transaction);
  `uvm_component_utils(axi4_sequencer)

  // Configuration and interface references
  axi4_cfg        m_cfg;
  virtual axi4_if m_vif;

  function new(string name = "axi4_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building sequencer: %s", get_name()), UVM_HIGH)

    // Get configuration from parent (agent)
    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db")
    end

    // Get virtual interface from parent (agent)
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "m_vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Connecting sequencer: %s", get_name()), UVM_HIGH)
  endfunction

endclass : axi4_sequencer

`endif // AXI4_SEQUENCER_SV
