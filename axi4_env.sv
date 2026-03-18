`ifndef AXI4_ENV_SV
`define AXI4_ENV_SV

`include "axi4_pkg.sv"
`include "axi4_master_agent.sv"
`include "axi4_if.sv"

class axi4_env extends uvm_env;
  `uvm_component_utils(axi4_env)

  axi4_master_agent m_master_agent;
  axi4_cfg          m_cfg;

  function new(string name = "axi4_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building environment: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_info(get_type_name(), "Using default configuration", UVM_MEDIUM)
      m_cfg = axi4_cfg::type_id::create("m_cfg");
    end

    uvm_config_db#(axi4_cfg)::set(this, "m_master_agent", "cfg", m_cfg);
    m_master_agent = axi4_master_agent::type_id::create("m_master_agent", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Connecting environment: %s", get_name()), UVM_HIGH)
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Environment hierarchy:\n%s", this.sprint()), UVM_HIGH)
  endfunction

endclass : axi4_env

`endif // AXI4_ENV_SV
