`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here
// axi4_if is defined outside the package

class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)

  virtual axi4_if m_vif;
  axi4_cfg        m_cfg;

  // Analysis port
  uvm_analysis_port #(axi4_transaction) m_analysis_port;

  // Transaction tracking
  axi4_transaction m_aw_trans[logic [`AXI4_ID_WIDTH-1:0]];
  axi4_transaction m_ar_trans[logic [`AXI4_ID_WIDTH-1:0]];

  // WLAST tracking for write latency
  time             m_wlast_time[logic [`AXI4_ID_WIDTH-1:0]];

  // Statistics
  int              m_total_trans_count;
  int              m_write_trans_count;
  int              m_read_trans_count;
  longint          m_total_data_bytes;
  time             m_first_trans_time;
  time             m_last_trans_time;

  // Latency tracking (in clock cycles per SPEC definition)
  longint          m_max_write_latency;
  longint          m_max_read_latency;
  logic [`AXI4_ID_WIDTH-1:0] m_max_write_latency_id;
  logic [`AXI4_ID_WIDTH-1:0] m_max_read_latency_id;
  longint          m_total_write_latency;
  longint          m_total_read_latency;

  // Timeout tracking (store cycle count instead of time)
  longint          m_aw_accept_cycle[logic [`AXI4_ID_WIDTH-1:0]];
  longint          m_ar_accept_cycle[logic [`AXI4_ID_WIDTH-1:0]];
  longint          m_cycle_counter;
  event            m_timeout_event;

  function new(string name = "axi4_monitor", uvm_component parent);
    super.new(name, parent);
    m_analysis_port = new("m_analysis_port", this);
    m_total_trans_count = 0;
    m_write_trans_count = 0;
    m_read_trans_count = 0;
    m_total_data_bytes = 0;
    m_first_trans_time = 0;
    m_last_trans_time = 0;
    m_max_write_latency = 0;
    m_max_read_latency = 0;
    m_max_write_latency_id = 0;
    m_max_read_latency_id = 0;
    m_total_write_latency = 0;
    m_total_read_latency = 0;
    m_cycle_counter = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building monitor: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "m_vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db. Ensure uvm_config_db#(virtual axi4_if)::set() is called in agent/env/test.")
    end

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db. Ensure uvm_config_db#(axi4_cfg)::set() is called in agent/env/test.")
    end
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_aw_channel();
      monitor_w_channel();
      monitor_b_channel();
      monitor_ar_channel();
      monitor_r_channel();
      timeout_checker();
    join
  endtask

  // Monitor write address channel
  task monitor_aw_channel();
    axi4_transaction trans;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.awvalid && m_vif.mon_cb.awready) begin
        trans = axi4_transaction::type_id::create("aw_trans");
        trans.m_trans_type = WRITE;
        trans.m_id = m_vif.mon_cb.awid;
        trans.m_addr = m_vif.mon_cb.awaddr;
        trans.m_len = m_vif.mon_cb.awlen;
        trans.m_size = m_vif.mon_cb.awsize;
        trans.m_burst = axi4_burst_t'(m_vif.mon_cb.awburst);
        trans.m_lock = m_vif.mon_cb.awlock;
        trans.m_cache = m_vif.mon_cb.awcache;
        trans.m_prot = m_vif.mon_cb.awprot;
        trans.m_qos = m_vif.mon_cb.awqos;
        trans.m_region = m_vif.mon_cb.awregion;
        trans.m_user = m_vif.mon_cb.awuser;
        trans.m_addr_accept_time = $time;

        m_aw_trans[trans.m_id] = trans;
        m_aw_accept_cycle[trans.m_id] = m_cycle_counter;
      end
    end
  endtask

  // Monitor write data channel
  task monitor_w_channel();
    logic [`AXI4_ID_WIDTH-1:0] current_wid;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.wvalid && m_vif.mon_cb.wready && m_vif.mon_cb.wlast) begin
        // Find matching AW transaction by tracking W channel
        // Note: In real AXI, W channel doesn't have ID, need to match by order
        // For simplicity, we use the most recent AW as the W owner
        if (m_aw_trans.size() > 0) begin
          // Get first pending AW (simplified matching)
          void'(m_aw_trans.first(current_wid));
          m_wlast_time[current_wid] = $time;
        end
      end
    end
  endtask

  // Monitor write response channel
  task monitor_b_channel();
    axi4_transaction trans;
    longint          latency_cycles;
    time             wlast_time;
    time             latency_time;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.bvalid && m_vif.mon_cb.bready) begin
        if (m_aw_trans.exists(m_vif.mon_cb.bid)) begin
          trans = m_aw_trans[m_vif.mon_cb.bid];
          trans.m_resp.push_back(axi4_resp_t'(m_vif.mon_cb.bresp));
          trans.m_buser = m_vif.mon_cb.buser;

          // Calculate write latency in clock cycles (AW handshake to WLAST per SPEC)
          if (m_wlast_time.exists(m_vif.mon_cb.bid)) begin
            wlast_time = m_wlast_time[m_vif.mon_cb.bid];
            latency_time = wlast_time - trans.m_addr_accept_time;
            // Convert time difference to clock cycles: cycles = time_ns * freq_MHz / 1000
            latency_cycles = (latency_time * m_cfg.m_clock_freq) / 1000;
            m_wlast_time.delete(m_vif.mon_cb.bid);
          end else begin
            latency_cycles = 0;
          end

          if (latency_cycles > m_max_write_latency) begin
            m_max_write_latency = latency_cycles;
            m_max_write_latency_id = trans.m_id;
          end
          m_total_write_latency += latency_cycles;

          // Send to analysis port
          m_analysis_port.write(trans);

          // Update statistics
          m_write_trans_count++;
          m_total_data_bytes += (trans.m_len + 1) * (1 << trans.m_size);

          m_aw_trans.delete(m_vif.mon_cb.bid);
          m_aw_accept_cycle.delete(m_vif.mon_cb.bid);
        end
      end
    end
  endtask

  // Monitor read address channel
  task monitor_ar_channel();
    axi4_transaction trans;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.arvalid && m_vif.mon_cb.arready) begin
        trans = axi4_transaction::type_id::create("ar_trans");
        trans.m_trans_type = READ;
        trans.m_id = m_vif.mon_cb.arid;
        trans.m_addr = m_vif.mon_cb.araddr;
        trans.m_len = m_vif.mon_cb.arlen;
        trans.m_size = m_vif.mon_cb.arsize;
        trans.m_burst = axi4_burst_t'(m_vif.mon_cb.arburst);
        trans.m_lock = m_vif.mon_cb.arlock;
        trans.m_cache = m_vif.mon_cb.arcache;
        trans.m_prot = m_vif.mon_cb.arprot;
        trans.m_qos = m_vif.mon_cb.arqos;
        trans.m_region = m_vif.mon_cb.arregion;
        trans.m_user = m_vif.mon_cb.aruser;
        trans.m_addr_accept_time = $time;

        m_ar_trans[trans.m_id] = trans;
        m_ar_accept_cycle[trans.m_id] = m_cycle_counter;

        // Track first transaction time
        if (m_first_trans_time == 0) begin
          m_first_trans_time = $time;
        end
      end
    end
  endtask

  // Monitor read data channel
  task monitor_r_channel();
    axi4_transaction trans;
    longint          latency_cycles;
    time             latency_time;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.rvalid && m_vif.mon_cb.rready) begin
        if (m_ar_trans.exists(m_vif.mon_cb.rid)) begin
          trans = m_ar_trans[m_vif.mon_cb.rid];
          trans.m_data.push_back(m_vif.mon_cb.rdata);
          trans.m_resp.push_back(axi4_resp_t'(m_vif.mon_cb.rresp));
          trans.m_ruser.push_back(m_vif.mon_cb.ruser);

          if (m_vif.mon_cb.rlast) begin
            trans.m_resp_accept_time = $time;

            // Calculate read latency in clock cycles (AR handshake to RLAST per SPEC)
            latency_time = trans.m_resp_accept_time - trans.m_addr_accept_time;
            // Convert time difference to clock cycles: cycles = time_ns * freq_MHz / 1000
            latency_cycles = (latency_time * m_cfg.m_clock_freq) / 1000;

            if (latency_cycles > m_max_read_latency) begin
              m_max_read_latency = latency_cycles;
              m_max_read_latency_id = trans.m_id;
            end
            m_total_read_latency += latency_cycles;

            // Send to analysis port
            m_analysis_port.write(trans);

            // Update statistics
            m_read_trans_count++;
            m_total_data_bytes += (trans.m_len + 1) * (1 << trans.m_size);
            m_last_trans_time = $time;

            m_ar_trans.delete(m_vif.mon_cb.rid);
            m_ar_accept_cycle.delete(m_vif.mon_cb.rid);
          end
        end
      end
    end
  endtask

  // Timeout checker - uses cycle count for accurate cycle-based timeout
  task timeout_checker();
    forever begin
      @(m_vif.mon_cb);
      m_cycle_counter++;  // Increment cycle counter each clock cycle

      // Check write timeout (AW to BVALID in clock cycles)
      foreach (m_aw_accept_cycle[id]) begin
        if ((m_cycle_counter - m_aw_accept_cycle[id]) > m_cfg.m_wtimeout) begin
          `uvm_warning(get_type_name(),
            $sformatf("Write transaction timeout! Cycles=%0d, AWID=%0d, timeout=%0d cycles",
                      m_cycle_counter - m_aw_accept_cycle[id], id, m_cfg.m_wtimeout))
          -> m_timeout_event;
        end
      end

      // Check read timeout (AR to RLAST in clock cycles)
      foreach (m_ar_accept_cycle[id]) begin
        if ((m_cycle_counter - m_ar_accept_cycle[id]) > m_cfg.m_rtimeout) begin
          `uvm_warning(get_type_name(),
            $sformatf("Read transaction timeout! Cycles=%0d, ARID=%0d, timeout=%0d cycles",
                      m_cycle_counter - m_ar_accept_cycle[id], id, m_cfg.m_rtimeout))
          -> m_timeout_event;
        end
      end
    end
  endtask

  // Report phase - print bandwidth and latency statistics per SPEC
  function void report_phase(uvm_phase phase);
    real bandwidth_efficiency;
    real total_time_ns;
    real total_time_s;
    real theoretical_bandwidth;  // bytes per second
    real actual_bandwidth;       // bytes per second
    real avg_write_latency;
    real avg_read_latency;
    real clock_period_ns;

    m_total_trans_count = m_write_trans_count + m_read_trans_count;

    if (m_total_trans_count == 0) begin
      `uvm_info(get_type_name(), "No transactions monitored", UVM_LOW)
      return;
    end

    total_time_ns = m_last_trans_time - m_first_trans_time;
    if (total_time_ns == 0) begin
      total_time_ns = 1;
    end
    total_time_s = total_time_ns * 1.0e-9;  // Convert ns to seconds

    // Clock period in ns: period = 1000 / freq_MHz
    clock_period_ns = 1000.0 / m_cfg.m_clock_freq;

    // Bandwidth calculation per SPEC:
    // Theoretical bandwidth = (data_width / 8) * clock_freq (bytes/second)
    // clock_freq in Hz = m_clock_freq * 1,000,000
    theoretical_bandwidth = (m_cfg.m_data_width / 8.0) * m_cfg.m_clock_freq * 1.0e6;

    // Actual bandwidth = total_data_bytes / total_time (bytes/second)
    actual_bandwidth = m_total_data_bytes / total_time_s;

    // Bandwidth efficiency = (actual / theoretical) * 100%
    bandwidth_efficiency = (actual_bandwidth / theoretical_bandwidth) * 100.0;

    // Average latencies (in clock cycles per SPEC)
    if (m_write_trans_count > 0) begin
      avg_write_latency = m_total_write_latency / m_write_trans_count;
    end else begin
      avg_write_latency = 0;
    end

    if (m_read_trans_count > 0) begin
      avg_read_latency = m_total_read_latency / m_read_trans_count;
    end else begin
      avg_read_latency = 0;
    end

    `uvm_info(get_type_name(), $sformatf("\n" +
      "========================================\n" +
      "AXI4 Monitor Statistics Report\n" +
      "========================================\n" +
      "Clock Frequency: %0d MHz (Period: %0f ns)\n" +
      "Total Transactions: %0d (Write: %0d, Read: %0d)\n" +
      "Total Data Transferred: %0d bytes\n" +
      "Total Time: %0f ns (%0f us)\n" +
      "----------------------------------------\n" +
      "Bandwidth Statistics:\n" +
      "  Theoretical Bandwidth: %0f MB/s\n" +
      "  Actual Bandwidth: %0f MB/s\n" +
      "  Bandwidth Efficiency: %0f%%\n" +
      "----------------------------------------\n" +
      "Write Latency (AW to WLAST in clock cycles):\n" +
      "  Max: %0d cycles (AWID=%0d)\n" +
      "  Avg: %0f cycles\n" +
      "Read Latency (AR to RLAST in clock cycles):\n" +
      "  Max: %0d cycles (ARID=%0d)\n" +
      "  Avg: %0f cycles\n" +
      "========================================",
      m_cfg.m_clock_freq, clock_period_ns,
      m_total_trans_count, m_write_trans_count, m_read_trans_count,
      m_total_data_bytes,
      total_time_ns, total_time_ns/1000.0,
      theoretical_bandwidth/1.0e6, actual_bandwidth/1.0e6,
      bandwidth_efficiency,
      m_max_write_latency, m_max_write_latency_id,
      avg_write_latency,
      m_max_read_latency, m_max_read_latency_id,
      avg_read_latency), UVM_LOW)
  endfunction

endclass : axi4_monitor

`endif // AXI4_MONITOR_SV
