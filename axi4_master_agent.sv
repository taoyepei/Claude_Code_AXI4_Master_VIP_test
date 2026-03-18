`ifndef AXI4_MASTER_AGENT_SV
`define AXI4_MASTER_AGENT_SV

`include "axi4_pkg.sv"
`include "axi4_transaction.sv"
`include "axi4_sequencer.sv"
`include "axi4_master_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_if.sv"

class axi4_master_agent extends uvm_agent;
  `uvm_component_utils(axi4_master_agent)

  axi4_sequencer      m_sequencer;
  axi4_master_driver  m_driver;
  axi4_monitor        m_monitor;

  axi4_cfg            m_cfg;
  bit                 m_is_active;

  function new(string name = "axi4_master_agent", uvm_component parent);
    super.new(name, parent);
    m_is_active = 1;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building agent: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db")
    end

    uvm_config_db#(axi4_cfg)::set(this, "m_monitor", "cfg", m_cfg);

    m_monitor = axi4_monitor::type_id::create("m_monitor", this);

    if (m_is_active) begin
      uvm_config_db#(axi4_cfg)::set(this, "m_sequencer", "cfg", m_cfg);
      uvm_config_db#(axi4_cfg)::set(this, "m_driver", "cfg", m_cfg);

      m_sequencer = axi4_sequencer::type_id::create("m_sequencer", this);
      m_driver = axi4_master_driver::type_id::create("m_driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Connecting agent: %s", get_name()), UVM_HIGH)

    if (m_is_active) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass : axi4_master_agent

`endif // AXI4_MASTER_AGENT_SV
