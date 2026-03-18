`ifndef AXI4_TRANSACTION_SV
`define AXI4_TRANSACTION_SV

`include "axi4_pkg.sv"

class axi4_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi4_transaction)

  // Transaction identification
  rand axi4_trans_type_t m_trans_type;
  rand logic [31:0]      m_id;
  rand int               m_split_id;

  // Address channel
  rand logic [63:0]      m_addr;
  rand logic [7:0]       m_len;
  rand logic [2:0]       m_size;
  rand axi4_burst_t      m_burst;
  rand logic             m_lock;
  rand logic [3:0]       m_cache;
  rand logic [2:0]       m_prot;
  rand logic [3:0]       m_qos;
  rand logic [3:0]       m_region;
  rand logic [15:0]      m_user;

  // Data channel
  rand logic [1023:0]    m_data[$];
  rand logic [127:0]     m_wstrb[$];
  rand logic [15:0]      m_wuser[$];

  // Response channel
  rand axi4_resp_t       m_resp[$];
  rand logic [15:0]      m_buser;
  rand logic [15:0]      m_ruser[$];

  // Timing information (for statistics)
  time                   m_addr_accept_time;
  time                   m_data_complete_time;
  time                   m_resp_accept_time;

  // Constraints
  constraint c_len_range {
    m_len <= 255;
  }

  constraint c_size_range {
    m_size <= 7;
  }

  constraint c_burst_type {
    m_burst inside {FIXED, INCR, WRAP};
  }

  constraint c_fixed_len {
    (m_burst == FIXED) -> (m_len <= 15);
  }

  constraint c_wrap_len {
    (m_burst == WRAP) -> (m_len inside {1, 3, 7, 15});
  }

  constraint c_addr_align {
    (m_burst != WRAP) -> (m_addr % (1 << m_size) == 0);
  }

  constraint c_data_size {
    m_data.size() == (m_len + 1);
    m_wstrb.size() == (m_trans_type == WRITE) ? (m_len + 1) : 0;
    m_wuser.size() == (m_trans_type == WRITE) ? (m_len + 1) : 0;
    m_ruser.size() == (m_trans_type == READ) ? (m_len + 1) : 0;
  }

  function new(string name = "axi4_transaction");
    super.new(name);
    m_id = 0;
    m_split_id = 0;
    m_addr = 0;
    m_len = 0;
    m_size = 0;
    m_burst = INCR;
    m_lock = 0;
    m_cache = 0;
    m_prot = 0;
    m_qos = 0;
    m_region = 0;
    m_user = 0;
    m_addr_accept_time = 0;
    m_data_complete_time = 0;
    m_resp_accept_time = 0;
  endfunction

  function void do_copy(uvm_object rhs);
    axi4_transaction rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal(get_type_name(), "Cast failed")
    end
    super.do_copy(rhs);
    m_trans_type = rhs_.m_trans_type;
    m_id = rhs_.m_id;
    m_split_id = rhs_.m_split_id;
    m_addr = rhs_.m_addr;
    m_len = rhs_.m_len;
    m_size = rhs_.m_size;
    m_burst = rhs_.m_burst;
    m_lock = rhs_.m_lock;
    m_cache = rhs_.m_cache;
    m_prot = rhs_.m_prot;
    m_qos = rhs_.m_qos;
    m_region = rhs_.m_region;
    m_user = rhs_.m_user;
    m_data = rhs_.m_data;
    m_wstrb = rhs_.m_wstrb;
    m_wuser = rhs_.m_wuser;
    m_resp = rhs_.m_resp;
    m_buser = rhs_.m_buser;
    m_ruser = rhs_.m_ruser;
    m_addr_accept_time = rhs_.m_addr_accept_time;
    m_data_complete_time = rhs_.m_data_complete_time;
    m_resp_accept_time = rhs_.m_resp_accept_time;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi4_transaction rhs_;
    do_compare = 1;
    if (!$cast(rhs_, rhs)) begin
      return 0;
    end
    do_compare &= super.do_compare(rhs_, comparer);
    do_compare &= (m_trans_type == rhs_.m_trans_type);
    do_compare &= (m_id == rhs_.m_id);
    do_compare &= (m_split_id == rhs_.m_split_id);
    do_compare &= (m_addr == rhs_.m_addr);
    do_compare &= (m_len == rhs_.m_len);
    do_compare &= (m_size == rhs_.m_size);
    do_compare &= (m_burst == rhs_.m_burst);
    do_compare &= (m_lock == rhs_.m_lock);
    do_compare &= (m_cache == rhs_.m_cache);
    do_compare &= (m_prot == rhs_.m_prot);
    do_compare &= (m_qos == rhs_.m_qos);
    do_compare &= (m_region == rhs_.m_region);
    do_compare &= (m_user == rhs_.m_user);
    do_compare &= (m_data == rhs_.m_data);
    do_compare &= (m_wstrb == rhs_.m_wstrb);
    do_compare &= (m_wuser == rhs_.m_wuser);
    do_compare &= (m_resp == rhs_.m_resp);
    do_compare &= (m_buser == rhs_.m_buser);
    do_compare &= (m_ruser == rhs_.m_ruser);
  endfunction

  function string convert2string();
    string s;
    string trans_type_str;
    string burst_str;

    case (m_trans_type)
      WRITE: trans_type_str = "WRITE";
      READ:  trans_type_str = "READ";
      default: trans_type_str = "UNKNOWN";
    endcase

    case (m_burst)
      FIXED: burst_str = "FIXED";
      INCR:  burst_str = "INCR";
      WRAP:  burst_str = "WRAP";
      default: burst_str = "UNKNOWN";
    endcase

    s = $sformatf("AXI4_TRANS: type=%s, id=%0d, split_id=%0d, addr=0x%0h, len=%0d, size=%0d, burst=%s",
                  trans_type_str, m_id, m_split_id, m_addr, m_len, m_size, burst_str);
    return s;
  endfunction

  function void do_print(uvm_printer printer);
    string trans_type_str;
    string burst_str;

    case (m_trans_type)
      WRITE: trans_type_str = "WRITE";
      READ:  trans_type_str = "READ";
    endcase

    case (m_burst)
      FIXED: burst_str = "FIXED";
      INCR:  burst_str = "INCR";
      WRAP:  burst_str = "WRAP";
    endcase

    printer.print_string("m_trans_type", trans_type_str);
    printer.print_int("m_id", m_id, $bits(m_id));
    printer.print_int("m_split_id", m_split_id, $bits(m_split_id));
    printer.print_int("m_addr", m_addr, $bits(m_addr));
    printer.print_int("m_len", m_len, $bits(m_len));
    printer.print_int("m_size", m_size, $bits(m_size));
    printer.print_string("m_burst", burst_str);
    printer.print_int("m_lock", m_lock, $bits(m_lock));
    printer.print_int("m_cache", m_cache, $bits(m_cache));
    printer.print_int("m_prot", m_prot, $bits(m_prot));
    printer.print_int("m_qos", m_qos, $bits(m_qos));
    printer.print_int("m_region", m_region, $bits(m_region));
    printer.print_int("m_user", m_user, $bits(m_user));
    printer.print_array_header("m_data", m_data.size());
    printer.print_array_footer();
    printer.print_int("m_addr_accept_time", m_addr_accept_time, 64);
    printer.print_int("m_data_complete_time", m_data_complete_time, 64);
    printer.print_int("m_resp_accept_time", m_resp_accept_time, 64);
  endfunction

  function void do_record(uvm_recorder recorder);
    super.do_record(recorder);
    `uvm_record_int("m_trans_type", m_trans_type)
    `uvm_record_int("m_id", m_id)
    `uvm_record_int("m_split_id", m_split_id)
    `uvm_record_int("m_addr", m_addr)
    `uvm_record_int("m_len", m_len)
    `uvm_record_int("m_size", m_size)
    `uvm_record_int("m_burst", m_burst)
    `uvm_record_int("m_lock", m_lock)
    `uvm_record_int("m_cache", m_cache)
    `uvm_record_int("m_prot", m_prot)
    `uvm_record_int("m_qos", m_qos)
    `uvm_record_int("m_region", m_region)
    `uvm_record_int("m_user", m_user)
    `uvm_record_time("m_addr_accept_time", m_addr_accept_time)
    `uvm_record_time("m_data_complete_time", m_data_complete_time)
    `uvm_record_time("m_resp_accept_time", m_resp_accept_time)
  endfunction

  // Calculate address for a specific beat in burst
  function logic [63:0] get_beat_addr(int beat);
    logic [63:0] beat_addr;
    int          bytes_per_beat;

    bytes_per_beat = 1 << m_size;

    case (m_burst)
      FIXED: begin
        beat_addr = m_addr;
      end
      INCR: begin
        beat_addr = m_addr + (beat * bytes_per_beat);
      end
      WRAP: begin
        int wrap_boundary;
        int wrap_len_bytes;
        wrap_len_bytes = (m_len + 1) * bytes_per_beat;
        wrap_boundary = (m_addr / wrap_len_bytes) * wrap_len_bytes;
        beat_addr = wrap_boundary + ((m_addr - wrap_boundary + beat * bytes_per_beat) % wrap_len_bytes);
      end
      default: beat_addr = m_addr;
    endcase

    return beat_addr;
  endfunction

  // Check if address crosses 4KB boundary
  function bit crosses_4kb_boundary();
    logic [63:0] end_addr;
    end_addr = get_beat_addr(m_len) + ((1 << m_size) - 1);
    return (m_addr[63:12] != end_addr[63:12]);
  endfunction

endclass : axi4_transaction

`endif // AXI4_TRANSACTION_SV
