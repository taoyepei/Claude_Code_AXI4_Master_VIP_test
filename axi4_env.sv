`ifndef AXI4_ENV_SV
`define AXI4_ENV_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here
// axi4_if is defined outside the package

class axi4_env extends uvm_env;
  `uvm_component_utils(axi4_env)

  axi4_master_agent m_master_agent;
  axi4_cfg          m_cfg;

  // Virtual interface handle for setting to children
  virtual axi4_if   m_vif;

  function new(string name = "axi4_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building environment: %s", get_name()), UVM_HIGH)

    // Get configuration from test
    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_info(get_type_name(), "Using default configuration", UVM_MEDIUM)
      m_cfg = axi4_cfg::type_id::create("m_cfg");
    end

    // Get virtual interface from test
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "m_vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db. Ensure uvm_config_db#(virtual axi4_if)::set() is called in test.")
    end

    // Pass configuration and interface to agent
    uvm_config_db#(axi4_cfg)::set(this, "m_master_agent", "cfg", m_cfg);
    uvm_config_db#(virtual axi4_if)::set(this, "m_master_agent", "m_vif", m_vif);

    // Create agent
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
