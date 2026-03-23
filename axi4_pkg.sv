`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // AXI4 burst types
  typedef enum logic [1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10
  } axi4_burst_t;

  // AXI4 response types
  typedef enum logic [1:0] {
    OKAY   = 2'b00,
    EXOKAY = 2'b01,
    SLVERR = 2'b10,
    DECERR = 2'b11
  } axi4_resp_t;

  // Transaction type
  typedef enum logic {
    WRITE = 1'b0,
    READ  = 1'b1
  } axi4_trans_type_t;

  // Configuration class
  class axi4_cfg extends uvm_object;
    `uvm_object_utils(axi4_cfg)

    // Bus width parameters
    int m_data_width;
    int m_addr_width;
    int m_id_width;

    // Protocol parameters
    int m_max_outstanding;
    int m_trans_interval;
    int m_data_before_addr_osd;

    // Timeout parameters (in clock cycles)
    int m_wtimeout;
    int m_rtimeout;

    // Feature enables
    bit m_support_data_before_addr;

    // Default constructor
    function new(string name = "axi4_cfg");
      super.new(name);
      // Default values
      m_data_width              = 32;
      m_addr_width              = 32;
      m_id_width                = 4;
      m_max_outstanding         = 8;
      m_trans_interval          = 0;
      m_data_before_addr_osd    = 0;
      m_wtimeout                = 1000;
      m_rtimeout                = 1000;
      m_support_data_before_addr = 0;
    endfunction

    function void do_copy(uvm_object rhs);
      axi4_cfg rhs_;
      if (!$cast(rhs_, rhs)) begin
        `uvm_fatal(get_type_name(), "Cast failed")
      end
      super.do_copy(rhs);
      m_data_width              = rhs_.m_data_width;
      m_addr_width              = rhs_.m_addr_width;
      m_id_width                = rhs_.m_id_width;
      m_max_outstanding         = rhs_.m_max_outstanding;
      m_trans_interval          = rhs_.m_trans_interval;
      m_data_before_addr_osd    = rhs_.m_data_before_addr_osd;
      m_wtimeout                = rhs_.m_wtimeout;
      m_rtimeout                = rhs_.m_rtimeout;
      m_support_data_before_addr = rhs_.m_support_data_before_addr;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      axi4_cfg rhs_;
      do_compare = 1;
      if (!$cast(rhs_, rhs)) begin
        return 0;
      end
      do_compare &= super.do_compare(rhs_, comparer);
      do_compare &= (m_data_width              == rhs_.m_data_width);
      do_compare &= (m_addr_width              == rhs_.m_addr_width);
      do_compare &= (m_id_width                == rhs_.m_id_width);
      do_compare &= (m_max_outstanding         == rhs_.m_max_outstanding);
      do_compare &= (m_trans_interval          == rhs_.m_trans_interval);
      do_compare &= (m_data_before_addr_osd    == rhs_.m_data_before_addr_osd);
      do_compare &= (m_wtimeout                == rhs_.m_wtimeout);
      do_compare &= (m_rtimeout                == rhs_.m_rtimeout);
      do_compare &= (m_support_data_before_addr == rhs_.m_support_data_before_addr);
    endfunction

    function string convert2string();
      string s;
      s = $sformatf("AXI4_CFG: data_width=%0d, addr_width=%0d, id_width=%0d, max_outstanding=%0d, trans_interval=%0d, data_before_addr_osd=%0d, wtimeout=%0d, rtimeout=%0d, support_data_before_addr=%0b",
                    m_data_width, m_addr_width, m_id_width, m_max_outstanding, m_trans_interval, m_data_before_addr_osd, m_wtimeout, m_rtimeout, m_support_data_before_addr);
      return s;
    endfunction

    function void do_print(uvm_printer printer);
      printer.print_int("m_data_width", m_data_width, $bits(m_data_width));
      printer.print_int("m_addr_width", m_addr_width, $bits(m_addr_width));
      printer.print_int("m_id_width", m_id_width, $bits(m_id_width));
      printer.print_int("m_max_outstanding", m_max_outstanding, $bits(m_max_outstanding));
      printer.print_int("m_trans_interval", m_trans_interval, $bits(m_trans_interval));
      printer.print_int("m_data_before_addr_osd", m_data_before_addr_osd, $bits(m_data_before_addr_osd));
      printer.print_int("m_wtimeout", m_wtimeout, $bits(m_wtimeout));
      printer.print_int("m_rtimeout", m_rtimeout, $bits(m_rtimeout));
      printer.print_int("m_support_data_before_addr", m_support_data_before_addr, $bits(m_support_data_before_addr));
    endfunction

    function void do_record(uvm_recorder recorder);
      super.do_record(recorder);
      `uvm_record_int("m_data_width", m_data_width, $bits(m_data_width))
      `uvm_record_int("m_addr_width", m_addr_width, $bits(m_addr_width))
      `uvm_record_int("m_id_width", m_id_width, $bits(m_id_width))
      `uvm_record_int("m_max_outstanding", m_max_outstanding, $bits(m_max_outstanding))
      `uvm_record_int("m_trans_interval", m_trans_interval, $bits(m_trans_interval))
      `uvm_record_int("m_data_before_addr_osd", m_data_before_addr_osd, $bits(m_data_before_addr_osd))
      `uvm_record_int("m_wtimeout", m_wtimeout, $bits(m_wtimeout))
      `uvm_record_int("m_rtimeout", m_rtimeout, $bits(m_rtimeout))
      `uvm_record_int("m_support_data_before_addr", m_support_data_before_addr, $bits(m_support_data_before_addr))
    endfunction
  endclass

  // Forward declarations - classes defined in separate include files
  typedef class axi4_transaction;
  typedef class axi4_sequence;
  typedef class axi4_sequencer;
  typedef class axi4_master_driver;
  typedef class axi4_monitor;
  typedef class axi4_master_agent;
  typedef class axi4_env;

endpackage : axi4_pkg

// Include VIP component files (must be outside package declaration)
`include "axi4_transaction.sv"
`include "axi4_sequence.sv"
`include "axi4_sequencer.sv"
`include "axi4_master_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_master_agent.sv"
`include "axi4_env.sv"

`endif // AXI4_PKG_SV
