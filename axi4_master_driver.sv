`ifndef AXI4_MASTER_DRIVER_SV
`define AXI4_MASTER_DRIVER_SV

`include "axi4_pkg.sv"
`include "axi4_transaction.sv"
`include "axi4_if.sv"

class axi4_master_driver extends uvm_driver #(axi4_transaction);
  `uvm_component_utils(axi4_master_driver)

  virtual axi4_if m_vif;
  axi4_cfg        m_cfg;

  // Transaction queues for outstanding support
  axi4_transaction m_aw_queue[$];
  axi4_transaction m_ar_queue[$];
  axi4_transaction m_w_queue[$];

  // Split transaction tracking
  int m_split_counter;

  // Timing control
  int m_trans_interval;

  function new(string name = "axi4_master_driver", uvm_component parent);
    super.new(name, parent);
    m_split_counter = 0;
    m_trans_interval = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building driver: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
    end

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db")
    end

    m_trans_interval = m_cfg.m_trans_interval;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      drive_aw_channel();
      drive_w_channel();
      drive_b_channel();
      drive_ar_channel();
      drive_r_channel();
    join
  endtask

  // Split transaction if needed
  function void split_transaction(axi4_transaction trans, ref axi4_transaction split_trans[$]);
    int remaining_len;
    int current_len;
    int current_addr;
    int bytes_per_beat;
    int boundary_4kb;
    axi4_transaction new_trans;

    split_trans.delete();

    if (trans.m_burst != INCR || trans.m_len <= 16) begin
      split_trans.push_back(trans);
      return;
    end

    bytes_per_beat = 1 << trans.m_size;
    remaining_len = trans.m_len;
    current_addr = trans.m_addr;
    boundary_4kb = ((current_addr / 4096) + 1) * 4096;

    while (remaining_len > 0) begin
      int max_len_this_burst;
      int len_this_burst;

      // Calculate max length before hitting 4KB boundary
      int bytes_to_boundary = boundary_4kb - current_addr;
      int max_beats_to_boundary = (bytes_to_boundary + bytes_per_beat - 1) / bytes_per_beat;

      max_len_this_burst = (remaining_len < 32) ? remaining_len : 32;

      if (max_beats_to_boundary < max_len_this_burst && max_beats_to_boundary > 0) begin
        len_this_burst = max_beats_to_boundary - 1;
      end else begin
        len_this_burst = max_len_this_burst - 1;
      end

      if (len_this_burst < 0) begin
        len_this_burst = 0;
      end

      new_trans = axi4_transaction::type_id::create($sformatf("split_trans_%0d", m_split_counter++));
      new_trans.copy(trans);
      new_trans.m_addr = current_addr;
      new_trans.m_len = len_this_burst;
      new_trans.m_split_id = m_split_counter;

      // Adjust data and wstrb for split
      new_trans.m_data.delete();
      new_trans.m_wstrb.delete();
      for (int i = 0; i <= len_this_burst; i++) begin
        int idx = trans.m_len - remaining_len + i;
        new_trans.m_data.push_back(trans.m_data[idx]);
        if (trans.m_trans_type == WRITE) begin
          new_trans.m_wstrb.push_back(trans.m_wstrb[idx]);
        end
      end

      split_trans.push_back(new_trans);

      remaining_len = remaining_len - len_this_burst - 1;
      current_addr = current_addr + (len_this_burst + 1) * bytes_per_beat;

      if (remaining_len > 0) begin
        boundary_4kb = ((current_addr / 4096) + 1) * 4096;
      end
    end
  endfunction

  // Drive write address channel
  task drive_aw_channel();
    axi4_transaction trans;
    axi4_transaction split_trans[$];

    forever begin
      seq_item_port.try_next_item(trans);
      if (trans == null) begin
        @(m_vif.m_cb);
        continue;
      end

      if (trans.m_trans_type == WRITE) begin
        split_transaction(trans, split_trans);

        for (int i = 0; i < split_trans.size(); i++) begin
          axi4_transaction split = split_trans[i];

          m_vif.m_cb.awid <= split.m_id;
          m_vif.m_cb.awaddr <= split.m_addr;
          m_vif.m_cb.awlen <= split.m_len;
          m_vif.m_cb.awsize <= split.m_size;
          m_vif.m_cb.awburst <= split.m_burst;
          m_vif.m_cb.awlock <= split.m_lock;
          m_vif.m_cb.awcache <= split.m_cache;
          m_vif.m_cb.awprot <= split.m_prot;
          m_vif.m_cb.awqos <= split.m_qos;
          m_vif.m_cb.awregion <= split.m_region;
          m_vif.m_cb.awuser <= split.m_user;
          m_vif.m_cb.awvalid <= 1'b1;

          @(m_vif.m_cb);
          while (!m_vif.m_cb.awready) begin
            @(m_vif.m_cb);
          end

          split.m_addr_accept_time = $time;
          m_vif.m_cb.awvalid <= 1'b0;
          m_aw_queue.push_back(split);

          for (int j = 0; j < m_trans_interval; j++) begin
            @(m_vif.m_cb);
          end
        end
      end

      seq_item_port.item_done();
    end
  endtask

  // Drive write data channel
  task drive_w_channel();
    axi4_transaction trans;
    int w_queue_idx;

    forever begin
      @(m_vif.m_cb);

      if (m_aw_queue.size() > 0 && m_w_queue.size() < m_cfg.m_data_before_addr_osd) begin
        trans = m_aw_queue.pop_front();
        m_w_queue.push_back(trans);
      end

      if (m_w_queue.size() > 0) begin
        trans = m_w_queue[0];
        w_queue_idx = 0;

        for (int beat = 0; beat <= trans.m_len; beat++) begin
          m_vif.m_cb.wdata <= trans.m_data[beat];
          m_vif.m_cb.wstrb <= trans.m_wstrb[beat];
          m_vif.m_cb.wlast <= (beat == trans.m_len);
          m_vif.m_cb.wvalid <= 1'b1;

          @(m_vif.m_cb);
          while (!m_vif.m_cb.wready) begin
            @(m_vif.m_cb);
          end
        end

        trans.m_data_complete_time = $time;
        m_vif.m_cb.wvalid <= 1'b0;
        m_w_queue.delete(w_queue_idx);
      end
    end
  endtask

  // Drive write response channel
  task drive_b_channel();
    forever begin
      @(m_vif.m_cb);

      m_vif.m_cb.bready <= 1'b1;

      if (m_vif.m_cb.bvalid) begin
        // Just accept the response, no dependency on bresp per spec
      end
    end
  endtask

  // Drive read address channel
  task drive_ar_channel();
    axi4_transaction trans;
    axi4_transaction split_trans[$];

    forever begin
      seq_item_port.try_next_item(trans);
      if (trans == null) begin
        @(m_vif.m_cb);
        continue;
      end

      if (trans.m_trans_type == READ) begin
        split_transaction(trans, split_trans);

        for (int i = 0; i < split_trans.size(); i++) begin
          axi4_transaction split = split_trans[i];

          m_vif.m_cb.arid <= split.m_id;
          m_vif.m_cb.araddr <= split.m_addr;
          m_vif.m_cb.arlen <= split.m_len;
          m_vif.m_cb.arsize <= split.m_size;
          m_vif.m_cb.arburst <= split.m_burst;
          m_vif.m_cb.arlock <= split.m_lock;
          m_vif.m_cb.arcache <= split.m_cache;
          m_vif.m_cb.arprot <= split.m_prot;
          m_vif.m_cb.arqos <= split.m_qos;
          m_vif.m_cb.arregion <= split.m_region;
          m_vif.m_cb.aruser <= split.m_user;
          m_vif.m_cb.arvalid <= 1'b1;

          @(m_vif.m_cb);
          while (!m_vif.m_cb.arready) begin
            @(m_vif.m_cb);
          end

          split.m_addr_accept_time = $time;
          m_vif.m_cb.arvalid <= 1'b0;
          m_ar_queue.push_back(split);

          for (int j = 0; j < m_trans_interval; j++) begin
            @(m_vif.m_cb);
          end
        end
      end

      seq_item_port.item_done();
    end
  endtask

  // Drive read data channel
  task drive_r_channel();
    int rid;
    axi4_transaction trans;

    forever begin
      @(m_vif.m_cb);

      m_vif.m_cb.rready <= 1'b1;

      if (m_vif.m_cb.rvalid) begin
        rid = m_vif.m_cb.rid;

        // Find matching transaction by ID
        foreach (m_ar_queue[i]) begin
          if (m_ar_queue[i].m_id == rid) begin
            trans = m_ar_queue[i];

            // Collect read data
            trans.m_data.push_back(m_vif.m_cb.rdata);
            trans.m_resp.push_back(axi4_resp_t'(m_vif.m_cb.rresp));
            trans.m_ruser.push_back(m_vif.m_cb.ruser);

            if (m_vif.m_cb.rlast) begin
              trans.m_resp_accept_time = $time;
              m_ar_queue.delete(i);
            end
            break;
          end
        end
      end
    end
  endtask

endclass : axi4_master_driver

`endif // AXI4_MASTER_DRIVER_SV
