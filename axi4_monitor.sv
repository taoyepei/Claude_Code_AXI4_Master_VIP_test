`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV

`include "axi4_pkg.sv"
`include "axi4_transaction.sv"
`include "axi4_if.sv"

class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)

  virtual axi4_if m_vif;
  axi4_cfg        m_cfg;

  // Analysis port
  uvm_analysis_port #(axi4_transaction) m_analysis_port;

  // Transaction tracking
  axi4_transaction m_aw_trans[logic [31:0]];
  axi4_transaction m_ar_trans[logic [31:0]];

  // WLAST tracking for write latency
  time               m_wlast_time[logic [31:0]];

  // Statistics
  int                m_total_trans_count;
  int                m_write_trans_count;
  int                m_read_trans_count;
  longint            m_total_data_bytes;
  time               m_first_trans_time;
  time               m_last_trans_time;

  // Latency tracking
  time               m_max_write_latency;
  time               m_max_read_latency;
  logic [31:0]       m_max_write_latency_id;
  logic [31:0]       m_max_read_latency_id;
  longint            m_total_write_latency;
  longint            m_total_read_latency;

  // Timeout tracking
  time               m_aw_accept_time[logic [31:0]];
  time               m_ar_accept_time[logic [31:0]];
  event              m_timeout_event;

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
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building monitor: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
    end

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db")
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
        m_aw_accept_time[trans.m_id] = $time;
      end
    end
  endtask

  // Monitor write data channel
  task monitor_w_channel();
    logic [31:0] current_wid;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.wvalid && m_vif.mon_cb.wready && m_vif.mon_cb.wlast) begin
        // Find matching AW transaction by tracking W channel
        // Note: In real AXI, W channel doesn't have ID, need to match by order
        // For simplicity, we use the most recent AW as the W owner
        if (m_aw_trans.size() > 0) begin
          // Get first pending AW (simplified matching)
          current_wid = m_aw_trans.first();
          m_wlast_time[current_wid] = $time;
        end
      end
    end
  endtask

  // Monitor write response channel
  task monitor_b_channel();
    axi4_transaction trans;
    time             latency;
    time             wlast_time;

    forever begin
      @(m_vif.mon_cb);

      if (m_vif.mon_cb.bvalid && m_vif.mon_cb.bready) begin
        if (m_aw_trans.exists(m_vif.mon_cb.bid)) begin
          trans = m_aw_trans[m_vif.mon_cb.bid];
          trans.m_resp.push_back(axi4_resp_t'(m_vif.mon_cb.bresp));
          trans.m_buser = m_vif.mon_cb.buser;

          // Calculate write latency (AW handshake to WLAST)
          if (m_wlast_time.exists(m_vif.mon_cb.bid)) begin
            wlast_time = m_wlast_time[m_vif.mon_cb.bid];
            latency = wlast_time - trans.m_addr_accept_time;
            m_wlast_time.delete(m_vif.mon_cb.bid);
          end else begin
            latency = 0;
          end

          if (latency > m_max_write_latency) begin
            m_max_write_latency = latency;
            m_max_write_latency_id = trans.m_id;
          end
          m_total_write_latency += latency;

          // Send to analysis port
          m_analysis_port.write(trans);

          // Update statistics
          m_write_trans_count++;
          m_total_data_bytes += (trans.m_len + 1) * (1 << trans.m_size);

          m_aw_trans.delete(m_vif.mon_cb.bid);
          m_aw_accept_time.delete(m_vif.mon_cb.bid);
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
        m_ar_accept_time[trans.m_id] = $time;

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
    time             latency;

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

            // Calculate read latency (AR handshake to RLAST)
            latency = trans.m_resp_accept_time - trans.m_addr_accept_time;

            if (latency > m_max_read_latency) begin
              m_max_read_latency = latency;
              m_max_read_latency_id = trans.m_id;
            end
            m_total_read_latency += latency;

            // Send to analysis port
            m_analysis_port.write(trans);

            // Update statistics
            m_read_trans_count++;
            m_total_data_bytes += (trans.m_len + 1) * (1 << trans.m_size);
            m_last_trans_time = $time;

            m_ar_trans.delete(m_vif.mon_cb.rid);
            m_ar_accept_time.delete(m_vif.mon_cb.rid);
          end
        end
      end
    end
  endtask

  // Timeout checker
  task timeout_checker();
    time current_time;

    forever begin
      @(m_vif.mon_cb);
      current_time = $time;

      // Check write timeout (AW to BVALID)
      foreach (m_aw_accept_time[id]) begin
        if ((current_time - m_aw_accept_time[id]) > m_cfg.m_wtimeout) begin
          `uvm_warning(get_type_name(),
            $sformatf("Write transaction timeout! Time=%0t, AWID=%0d", current_time, id))
          -> m_timeout_event;
        end
      end

      // Check read timeout (AR to RLAST)
      foreach (m_ar_accept_time[id]) begin
        if ((current_time - m_ar_accept_time[id]) > m_cfg.m_rtimeout) begin
          `uvm_warning(get_type_name(),
            $sformatf("Read transaction timeout! Time=%0t, ARID=%0d", current_time, id))
          -> m_timeout_event;
        end
      end
    end
  endtask

  // Report phase - print bandwidth and latency statistics
  function void report_phase(uvm_phase phase);
    real bandwidth_efficiency;
    real total_time_ns;
    real theoretical_bandwidth;
    real actual_bandwidth;
    real avg_write_latency;
    real avg_read_latency;

    m_total_trans_count = m_write_trans_count + m_read_trans_count;

    if (m_total_trans_count == 0) begin
      `uvm_info(get_type_name(), "No transactions monitored", UVM_LOW)
      return;
    end

    total_time_ns = m_last_trans_time - m_first_trans_time;
    if (total_time_ns == 0) begin
      total_time_ns = 1;
    end

    // Bandwidth calculation (bytes per ns)
    theoretical_bandwidth = (m_cfg.m_data_width / 8);
    actual_bandwidth = m_total_data_bytes / total_time_ns;
    bandwidth_efficiency = (actual_bandwidth / theoretical_bandwidth) * 100.0;

    // Average latencies
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
      "Total Transactions: %0d (Write: %0d, Read: %0d)\n" +
      "Total Data Transferred: %0d bytes\n" +
      "Total Time: %0f ns\n" +
      "Bandwidth Efficiency: %0f%%\n" +
      "----------------------------------------\n" +
      "Write Latency:\n" +
      "  Max: %0t (AWID=%0d)\n" +
      "  Avg: %0f\n" +
      "Read Latency:\n" +
      "  Max: %0t (ARID=%0d)\n" +
      "  Avg: %0f\n" +
      "========================================",
      m_total_trans_count, m_write_trans_count, m_read_trans_count,
      m_total_data_bytes,
      total_time_ns,
      bandwidth_efficiency,
      m_max_write_latency, m_max_write_latency_id,
      avg_write_latency,
      m_max_read_latency, m_max_read_latency_id,
      avg_read_latency), UVM_LOW)
  endfunction

endclass : axi4_monitor

`endif // AXI4_MONITOR_SV
