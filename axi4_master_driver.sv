`ifndef AXI4_MASTER_DRIVER_SV
`define AXI4_MASTER_DRIVER_SV

`include "axi4_pkg.sv"
`include "axi4_transaction.sv"
`include "axi4_if.sv"

import uvm_pkg::*;

class axi4_master_driver extends uvm_driver #(axi4_transaction);
  `uvm_component_utils(axi4_master_driver)

  virtual axi4_if m_vif;
  axi4_cfg        m_cfg;

  // Outstanding transaction tracking
  axi4_transaction m_aw_pending[$];
  axi4_transaction m_ar_pending[$];
  axi4_transaction m_w_queue[$];

  // Write response tracking (ID -> transaction)
  axi4_transaction m_b_pending[logic [31:0]];

  // Split transaction ID allocation
  int m_next_split_id;

  // Timing control
  int m_trans_interval;

  // Reset done flag
  bit m_reset_done;

  function new(string name = "axi4_master_driver", uvm_component parent);
    super.new(name, parent);
    m_next_split_id = 0;
    m_trans_interval = 0;
    m_reset_done = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Building driver: %s", get_name()), UVM_HIGH)

    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "m_vif", m_vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db. Ensure uvm_config_db#(virtual axi4_if)::set() is called in agent/env/test.")
    end

    if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", m_cfg)) begin
      `uvm_fatal(get_type_name(), "Configuration not found in config_db. Ensure uvm_config_db#(axi4_cfg)::set() is called in agent/env/test.")
    end

    m_trans_interval = m_cfg.m_trans_interval;
  endfunction

  task run_phase(uvm_phase phase);
    // Drive all signals to 0 immediately (before any clock edge) to avoid X state
    drive_idle_values();

    // Wait for reset to be released first
    wait_for_reset();

    fork
      get_and_drive();
      drive_aw_channel();
      drive_w_channel();
      drive_b_channel();
      drive_ar_channel();
      drive_r_channel();
      reset_monitor();
    join
  endtask

  // Drive all signals to 0 immediately using non-blocking assignment via clocking block
  task drive_idle_values();
    @(m_vif.m_cb);
    m_vif.m_cb.awid    <= '0;
    m_vif.m_cb.awaddr  <= '0;
    m_vif.m_cb.awlen   <= '0;
    m_vif.m_cb.awsize  <= '0;
    m_vif.m_cb.awburst <= '0;
    m_vif.m_cb.awlock  <= '0;
    m_vif.m_cb.awcache <= '0;
    m_vif.m_cb.awprot  <= '0;
    m_vif.m_cb.awqos   <= '0;
    m_vif.m_cb.awregion <= '0;
    m_vif.m_cb.awuser  <= '0;
    m_vif.m_cb.awvalid <= 1'b0;
    m_vif.m_cb.wdata   <= '0;
    m_vif.m_cb.wstrb   <= '0;
    m_vif.m_cb.wlast   <= 1'b0;
    m_vif.m_cb.wuser   <= '0;
    m_vif.m_cb.wvalid  <= 1'b0;
    m_vif.m_cb.bready  <= 1'b0;
    m_vif.m_cb.arid    <= '0;
    m_vif.m_cb.araddr  <= '0;
    m_vif.m_cb.arlen   <= '0;
    m_vif.m_cb.arsize  <= '0;
    m_vif.m_cb.arburst <= '0;
    m_vif.m_cb.arlock  <= '0;
    m_vif.m_cb.arcache <= '0;
    m_vif.m_cb.arprot  <= '0;
    m_vif.m_cb.arqos   <= '0;
    m_vif.m_cb.arregion <= '0;
    m_vif.m_cb.aruser  <= '0;
    m_vif.m_cb.arvalid <= 1'b0;
    m_vif.m_cb.rready  <= 1'b0;
    `uvm_info(get_type_name(), "Drive idle values completed", UVM_LOW)
  endtask

  // Wait for reset to be released before driving signals
  task wait_for_reset();
    `uvm_info(get_type_name(), "Waiting for reset release...", UVM_LOW)
    @(posedge m_vif.aclk);
    while (!m_vif.areset_n) begin
      @(posedge m_vif.aclk);
    end
    m_reset_done = 1;
    `uvm_info(get_type_name(), "Reset released, starting driver operation", UVM_LOW)
  endtask

  // Monitor reset and drive initial values
  task reset_monitor();
    forever begin
      @(negedge m_vif.areset_n);
      m_reset_done = 0;
      `uvm_info(get_type_name(), "Reset detected, driving signals to reset values", UVM_LOW)
      drive_reset_values();

      // Wait for reset release
      @(posedge m_vif.areset_n);
      @(posedge m_vif.aclk);
      m_reset_done = 1;
      `uvm_info(get_type_name(), "Reset released, resuming driver operation", UVM_LOW)
    end
  endtask

  // Drive all signals to reset values via clocking block
  task drive_reset_values();
    @(m_vif.m_cb);
    m_vif.m_cb.awid    <= '0;
    m_vif.m_cb.awaddr  <= '0;
    m_vif.m_cb.awlen   <= '0;
    m_vif.m_cb.awsize  <= '0;
    m_vif.m_cb.awburst <= '0;
    m_vif.m_cb.awlock  <= '0;
    m_vif.m_cb.awcache <= '0;
    m_vif.m_cb.awprot  <= '0;
    m_vif.m_cb.awqos   <= '0;
    m_vif.m_cb.awregion <= '0;
    m_vif.m_cb.awuser  <= '0;
    m_vif.m_cb.awvalid <= 1'b0;
    m_vif.m_cb.wdata   <= '0;
    m_vif.m_cb.wstrb   <= '0;
    m_vif.m_cb.wlast   <= 1'b0;
    m_vif.m_cb.wuser   <= '0;
    m_vif.m_cb.wvalid  <= 1'b0;
    m_vif.m_cb.bready  <= 1'b0;
    m_vif.m_cb.arid    <= '0;
    m_vif.m_cb.araddr  <= '0;
    m_vif.m_cb.arlen   <= '0;
    m_vif.m_cb.arsize  <= '0;
    m_vif.m_cb.arburst <= '0;
    m_vif.m_cb.arlock  <= '0;
    m_vif.m_cb.arcache <= '0;
    m_vif.m_cb.arprot  <= '0;
    m_vif.m_cb.arqos   <= '0;
    m_vif.m_cb.arregion <= '0;
    m_vif.m_cb.aruser  <= '0;
    m_vif.m_cb.arvalid <= 1'b0;
    m_vif.m_cb.rready  <= 1'b0;
    `uvm_info(get_type_name(), "Drive reset values completed", UVM_LOW)
  endtask

  // Get transactions from sequencer and split if needed
  task get_and_drive();
    axi4_transaction trans;
    axi4_transaction split_trans[$];

    forever begin
      // Wait for reset to be done
      wait(m_reset_done);

      seq_item_port.get_next_item(trans);

      split_transaction(trans, split_trans);

      // Queue split transactions for address channel
      foreach (split_trans[i]) begin
        if (split_trans[i].m_trans_type == WRITE) begin
          // Wait if max outstanding reached
          while (m_aw_pending.size() >= m_cfg.m_max_outstanding) begin
            @(m_vif.m_cb);
            if (!m_reset_done) break;
          end
          if (!m_reset_done) break;
          m_aw_pending.push_back(split_trans[i]);
        end else begin
          // Read transaction
          while (m_ar_pending.size() >= m_cfg.m_max_outstanding) begin
            @(m_vif.m_cb);
            if (!m_reset_done) break;
          end
          if (!m_reset_done) break;
          m_ar_pending.push_back(split_trans[i]);
        end
      end

      seq_item_port.item_done();
    end
  endtask

  // Split transaction if needed
  function void split_transaction(axi4_transaction trans, ref axi4_transaction split_trans[$]);
    int remaining_len;
    int current_addr;
    int bytes_per_beat;
    int boundary_2kb;
    axi4_transaction new_trans;
    logic [31:0] base_id;

    split_trans.delete();
    base_id = trans.m_id;

    // Check if split needed
    if (trans.m_burst != INCR || trans.m_len <= 16) begin
      trans.m_split_id = 0;
      split_trans.push_back(trans);
      return;
    end

    bytes_per_beat = 1 << trans.m_size;
    remaining_len = trans.m_len;
    current_addr = trans.m_addr;
    boundary_2kb = ((current_addr / 2048) + 1) * 2048;

    while (remaining_len > 0) begin
      int max_len_this_burst;
      int len_this_burst;
      int bytes_to_boundary;
      int max_beats_to_boundary;

      // Calculate max length before hitting 2KB boundary
      bytes_to_boundary = boundary_2kb - current_addr;
      max_beats_to_boundary = (bytes_to_boundary + bytes_per_beat - 1) / bytes_per_beat;

      max_len_this_burst = (remaining_len < 32) ? remaining_len : 32;

      if (max_beats_to_boundary < max_len_this_burst && max_beats_to_boundary > 0) begin
        len_this_burst = max_beats_to_boundary - 1;
      end else begin
        len_this_burst = max_len_this_burst - 1;
      end

      if (len_this_burst < 0) begin
        len_this_burst = 0;
      end

      new_trans = axi4_transaction::type_id::create($sformatf("split_trans_%0d", m_next_split_id));
      new_trans.copy(trans);
      new_trans.m_addr = current_addr;
      new_trans.m_len = len_this_burst;
      new_trans.m_split_id = m_next_split_id;
      // Each split burst uses different ID
      new_trans.m_id = base_id + m_next_split_id;

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
      m_next_split_id++;

      remaining_len = remaining_len - len_this_burst - 1;
      current_addr = current_addr + (len_this_burst + 1) * bytes_per_beat;

      if (remaining_len > 0) begin
        boundary_2kb = ((current_addr / 2048) + 1) * 2048;
      end
    end
  endfunction

  // Drive write address channel
  task drive_aw_channel();
    axi4_transaction trans;

    forever begin
      // Wait for clock edge first, then check for transaction
      @(m_vif.m_cb);

      if (!m_reset_done) continue;

      // Skip if no pending transaction
      if (m_aw_pending.size() == 0) continue;

      trans = m_aw_pending.pop_front();

      // Drive all AW signals together using non-blocking assignment
      m_vif.m_cb.awid    <= trans.m_id;
      m_vif.m_cb.awaddr  <= trans.m_addr;
      m_vif.m_cb.awlen   <= trans.m_len;
      m_vif.m_cb.awsize  <= trans.m_size;
      m_vif.m_cb.awburst <= trans.m_burst;
      m_vif.m_cb.awlock  <= trans.m_lock;
      m_vif.m_cb.awcache <= trans.m_cache;
      m_vif.m_cb.awprot  <= trans.m_prot;
      m_vif.m_cb.awqos   <= trans.m_qos;
      m_vif.m_cb.awregion <= trans.m_region;
      m_vif.m_cb.awuser  <= trans.m_user;
      m_vif.m_cb.awvalid <= 1'b1;

      `uvm_info(get_type_name(), $sformatf("AW channel: Driving awaddr=0x%0h, awid=0x%0h, awvalid=1 at time %0t", trans.m_addr, trans.m_id, $time), UVM_LOW)

      // Wait for address to be accepted (awready asserted)
      // Keep awvalid high until awready is seen
      while (1) begin
        @(m_vif.m_cb);
        if (!m_reset_done) break;
        if (m_vif.m_cb.awready) break;
      end

      if (!m_reset_done) begin
        m_vif.m_cb.awvalid <= 1'b0;
        continue;
      end

      trans.m_addr_accept_time = $time;
      m_vif.m_cb.awvalid <= 1'b0;

      `uvm_info(get_type_name(), $sformatf("AW channel: Address 0x%0h accepted at time %0t", trans.m_addr, $time), UVM_LOW)

      // Track for write completion
      m_b_pending[trans.m_id] = trans;

      // Queue for W channel
      m_w_queue.push_back(trans);

      // Transaction interval - wait specified cycles before next transaction
      repeat (m_trans_interval) begin
        @(m_vif.m_cb);
        if (!m_reset_done) break;
      end
    end
  endtask

  // Drive write data channel
  task drive_w_channel();
    axi4_transaction trans;
    int w_count;

    forever begin
      @(m_vif.m_cb);

      // Skip if reset not done
      if (!m_reset_done) continue;

      if (m_w_queue.size() > 0) begin
        // Check data_before_addr_osd limit
        w_count = m_b_pending.size();

        if (!m_cfg.m_support_data_before_addr) begin
          // Normal mode: need address first (aw has been sent, in m_b_pending)
          if (w_count > 0) begin
            trans = m_w_queue.pop_front();

            for (int beat = 0; beat <= trans.m_len && m_reset_done; beat++) begin
              m_vif.m_cb.wdata <= trans.m_data[beat];
              m_vif.m_cb.wstrb <= trans.m_wstrb[beat];
              m_vif.m_cb.wlast <= (beat == trans.m_len);
              m_vif.m_cb.wuser <= trans.m_wuser[beat];
              m_vif.m_cb.wvalid <= 1'b1;

              @(m_vif.m_cb);
              while (!m_vif.m_cb.wready && m_reset_done) begin
                @(m_vif.m_cb);
              end
              if (!m_reset_done) break;
            end

            if (m_reset_done) begin
              trans.m_data_complete_time = $time;
            end
            m_vif.m_cb.wvalid <= 1'b0;
            m_vif.m_cb.wlast <= 1'b0;
            m_vif.m_cb.wuser <= '0;
          end
        end else begin
          // Data before addr mode: check osd limit
          if (w_count <= m_cfg.m_data_before_addr_osd) begin
            trans = m_w_queue.pop_front();

            for (int beat = 0; beat <= trans.m_len && m_reset_done; beat++) begin
              m_vif.m_cb.wdata <= trans.m_data[beat];
              m_vif.m_cb.wstrb <= trans.m_wstrb[beat];
              m_vif.m_cb.wlast <= (beat == trans.m_len);
              m_vif.m_cb.wuser <= trans.m_wuser[beat];
              m_vif.m_cb.wvalid <= 1'b1;

              @(m_vif.m_cb);
              while (!m_vif.m_cb.wready && m_reset_done) begin
                @(m_vif.m_cb);
              end
              if (!m_reset_done) break;
            end

            if (m_reset_done) begin
              trans.m_data_complete_time = $time;
            end
            m_vif.m_cb.wvalid <= 1'b0;
            m_vif.m_cb.wlast <= 1'b0;
            m_vif.m_cb.wuser <= '0;
          end
        end
      end
    end
  endtask

  // Drive write response channel
  task drive_b_channel();
    forever begin
      @(m_vif.m_cb);

      // Skip if reset not done
      if (!m_reset_done) begin
        m_vif.m_cb.bready <= 1'b0;
        continue;
      end

      m_vif.m_cb.bready <= 1'b1;

      if (m_vif.m_cb.bvalid) begin
        if (m_b_pending.exists(m_vif.m_cb.bid)) begin
          m_b_pending.delete(m_vif.m_cb.bid);
        end
      end
    end
  endtask

  // Drive read address channel
  task drive_ar_channel();
    axi4_transaction trans;

    forever begin
      // Wait for clock edge first, then check for transaction
      @(m_vif.m_cb);

      if (!m_reset_done) continue;

      // Skip if no pending transaction
      if (m_ar_pending.size() == 0) continue;

      trans = m_ar_pending.pop_front();

      // Drive all AR signals together using non-blocking assignment
      // All assignments happen in the same delta cycle due to NBA
      m_vif.m_cb.arid    <= trans.m_id;
      m_vif.m_cb.araddr  <= trans.m_addr;
      m_vif.m_cb.arlen   <= trans.m_len;
      m_vif.m_cb.arsize  <= trans.m_size;
      m_vif.m_cb.arburst <= trans.m_burst;
      m_vif.m_cb.arlock  <= trans.m_lock;
      m_vif.m_cb.arcache <= trans.m_cache;
      m_vif.m_cb.arprot  <= trans.m_prot;
      m_vif.m_cb.arqos   <= trans.m_qos;
      m_vif.m_cb.arregion <= trans.m_region;
      m_vif.m_cb.aruser  <= trans.m_user;
      m_vif.m_cb.arvalid <= 1'b1;

      `uvm_info(get_type_name(), $sformatf("AR channel: Driving araddr=0x%0h, arid=0x%0h, arvalid=1 at time %0t", trans.m_addr, trans.m_id, $time), UVM_LOW)

      // Wait for address to be accepted (arready asserted)
      // Keep arvalid high until arready is seen
      while (1) begin
        @(m_vif.m_cb);
        if (!m_reset_done) break;
        if (m_vif.m_cb.arready) break;
      end

      if (!m_reset_done) begin
        m_vif.m_cb.arvalid <= 1'b0;
        continue;
      end

      trans.m_addr_accept_time = $time;
      m_vif.m_cb.arvalid <= 1'b0;

      `uvm_info(get_type_name(), $sformatf("AR channel: Address 0x%0h accepted at time %0t", trans.m_addr, $time), UVM_LOW)

      // Transaction interval - wait specified cycles before next transaction
      repeat (m_trans_interval) begin
        @(m_vif.m_cb);
        if (!m_reset_done) break;
      end
    end
  endtask

  // Drive read data channel (receive)
  task drive_r_channel();
    logic [31:0] rid;

    forever begin
      @(m_vif.m_cb);

      // Skip if reset not done
      if (!m_reset_done) begin
        m_vif.m_cb.rready <= 1'b0;
        continue;
      end

      m_vif.m_cb.rready <= 1'b1;

      if (m_vif.m_cb.rvalid && m_vif.m_cb.rlast) begin
        // Read transaction completed
        rid = m_vif.m_cb.rid;
      end
    end
  endtask

endclass : axi4_master_driver

`endif // AXI4_MASTER_DRIVER_SV
