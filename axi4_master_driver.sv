`ifndef AXI4_MASTER_DRIVER_SV
`define AXI4_MASTER_DRIVER_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here
// axi4_if is defined outside the package

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

  // Drive all signals to 0 immediately using non-blocking assignment
  task drive_idle_values();
    @(posedge m_vif.aclk);
    m_vif.awid    <= '0;
    m_vif.awaddr  <= '0;
    m_vif.awlen   <= '0;
    m_vif.awsize  <= '0;
    m_vif.awburst <= '0;
    m_vif.awlock  <= '0;
    m_vif.awcache <= '0;
    m_vif.awprot  <= '0;
    m_vif.awqos   <= '0;
    m_vif.awregion <= '0;
    m_vif.awuser  <= '0;
    m_vif.awvalid <= 1'b0;
    m_vif.wdata   <= '0;
    m_vif.wstrb   <= '0;
    m_vif.wlast   <= 1'b0;
    m_vif.wuser   <= '0;
    m_vif.wvalid  <= 1'b0;
    m_vif.bready  <= 1'b0;
    m_vif.arid    <= '0;
    m_vif.araddr  <= '0;
    m_vif.arlen   <= '0;
    m_vif.arsize  <= '0;
    m_vif.arburst <= '0;
    m_vif.arlock  <= '0;
    m_vif.arcache <= '0;
    m_vif.arprot  <= '0;
    m_vif.arqos   <= '0;
    m_vif.arregion <= '0;
    m_vif.aruser  <= '0;
    m_vif.arvalid <= 1'b0;
    m_vif.rready  <= 1'b0;
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

  // Drive all signals to reset values
  task drive_reset_values();
    @(posedge m_vif.aclk);
    m_vif.awid    <= '0;
    m_vif.awaddr  <= '0;
    m_vif.awlen   <= '0;
    m_vif.awsize  <= '0;
    m_vif.awburst <= '0;
    m_vif.awlock  <= '0;
    m_vif.awcache <= '0;
    m_vif.awprot  <= '0;
    m_vif.awqos   <= '0;
    m_vif.awregion <= '0;
    m_vif.awuser  <= '0;
    m_vif.awvalid <= 1'b0;
    m_vif.wdata   <= '0;
    m_vif.wstrb   <= '0;
    m_vif.wlast   <= 1'b0;
    m_vif.wuser   <= '0;
    m_vif.wvalid  <= 1'b0;
    m_vif.bready  <= 1'b0;
    m_vif.arid    <= '0;
    m_vif.araddr  <= '0;
    m_vif.arlen   <= '0;
    m_vif.arsize  <= '0;
    m_vif.arburst <= '0;
    m_vif.arlock  <= '0;
    m_vif.arcache <= '0;
    m_vif.arprot  <= '0;
    m_vif.arqos   <= '0;
    m_vif.arregion <= '0;
    m_vif.aruser  <= '0;
    m_vif.arvalid <= 1'b0;
    m_vif.rready  <= 1'b0;
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
            @(posedge m_vif.aclk);
            if (!m_reset_done) break;
          end
          if (!m_reset_done) break;
          m_aw_pending.push_back(split_trans[i]);
        end else begin
          // Read transaction
          while (m_ar_pending.size() >= m_cfg.m_max_outstanding) begin
            @(posedge m_vif.aclk);
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
  // Handles: 2KB boundary, 4KB boundary, and max burst length (32 beats)
  function void split_transaction(axi4_transaction trans, ref axi4_transaction split_trans[$]);
    int remaining_len;
    int current_addr;
    int bytes_per_beat;
    int boundary_2kb;
    int boundary_4kb;
    int end_addr;
    axi4_transaction new_trans;
    logic [31:0] base_id;

    split_trans.delete();
    base_id = trans.m_id;

    bytes_per_beat = 1 << trans.m_size;
    remaining_len = trans.m_len;
    current_addr = trans.m_addr;

    // Check if split needed for INCR bursts
    // Split if: len > 16, OR crosses 2KB boundary, OR crosses 4KB boundary
    if (trans.m_burst != INCR) begin
      // FIXED and WRAP bursts are not split
      trans.m_split_id = 0;
      split_trans.push_back(trans);
      return;
    end

    // Calculate end address to check 4KB boundary crossing
    end_addr = current_addr + (trans.m_len + 1) * bytes_per_beat;

    // Check if split is needed:
    // 1. Burst length > 16 (existing requirement)
    // 2. Crosses 2KB boundary (existing requirement)
    // 3. Crosses 4KB boundary (new requirement per VIP spec)
    if (trans.m_len <= 16 &&
        (current_addr / 2048) == (end_addr - 1) / 2048 &&
        (current_addr / 4096) == (end_addr - 1) / 4096) begin
      // No split needed
      trans.m_split_id = 0;
      split_trans.push_back(trans);
      return;
    end

    boundary_2kb = ((current_addr / 2048) + 1) * 2048;
    boundary_4kb = ((current_addr / 4096) + 1) * 4096;

    while (remaining_len > 0) begin
      int max_len_this_burst;
      int len_this_burst;
      int bytes_to_2kb;
      int bytes_to_4kb;
      int max_beats_to_2kb;
      int max_beats_to_4kb;
      int max_beats_allowed;

      bytes_per_beat = 1 << trans.m_size;

      // Calculate max length before hitting 2KB boundary
      bytes_to_2kb = boundary_2kb - current_addr;
      max_beats_to_2kb = (bytes_to_2kb + bytes_per_beat - 1) / bytes_per_beat;

      // Calculate max length before hitting 4KB boundary
      bytes_to_4kb = boundary_4kb - current_addr;
      max_beats_to_4kb = (bytes_to_4kb + bytes_per_beat - 1) / bytes_per_beat;

      // Max burst length is 32 beats (per spec and VIP requirement)
      max_len_this_burst = (remaining_len < 32) ? remaining_len : 32;

      // Find the limiting factor (2KB boundary, 4KB boundary, or max length)
      max_beats_allowed = max_len_this_burst;

      if (max_beats_to_2kb > 0 && max_beats_to_2kb < max_beats_allowed) begin
        max_beats_allowed = max_beats_to_2kb;
      end

      if (max_beats_to_4kb > 0 && max_beats_to_4kb < max_beats_allowed) begin
        max_beats_allowed = max_beats_to_4kb;
      end

      len_this_burst = max_beats_allowed - 1;

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
        boundary_4kb = ((current_addr / 4096) + 1) * 4096;
      end
    end
  endfunction

  // Drive write address channel - direct signal access, no clocking block
  task drive_aw_channel();
    axi4_transaction trans;

    forever begin
      // Wait for clock edge first
      @(posedge m_vif.aclk);

      if (!m_reset_done) continue;

      // Skip if no pending transaction
      if (m_aw_pending.size() == 0) continue;

      trans = m_aw_pending.pop_front();

      // Drive all AW signals together using non-blocking assignment
      m_vif.awid    <= trans.m_id;
      m_vif.awaddr  <= trans.m_addr;
      m_vif.awlen   <= trans.m_len;
      m_vif.awsize  <= trans.m_size;
      m_vif.awburst <= trans.m_burst;
      m_vif.awlock  <= trans.m_lock;
      m_vif.awcache <= trans.m_cache;
      m_vif.awprot  <= trans.m_prot;
      m_vif.awqos   <= trans.m_qos;
      m_vif.awregion <= trans.m_region;
      m_vif.awuser  <= trans.m_user;
      m_vif.awvalid <= 1'b1;

      `uvm_info(get_type_name(), $sformatf("AW channel: Driving awaddr=0x%0h, awid=0x%0h, awvalid=1 at time %0t", trans.m_addr, trans.m_id, $time), UVM_LOW)

      // Wait for address to be accepted (awready asserted)
      // Keep awvalid high until awready is seen
      while (1) begin
        @(posedge m_vif.aclk);
        if (!m_reset_done) break;
        if (m_vif.awready) break;
      end

      if (!m_reset_done) begin
        m_vif.awvalid <= 1'b0;
        continue;
      end

      trans.m_addr_accept_time = $time;
      m_vif.awvalid <= 1'b0;

      `uvm_info(get_type_name(), $sformatf("AW channel: Address 0x%0h accepted at time %0t", trans.m_addr, $time), UVM_LOW)

      // Track for write completion
      m_b_pending[trans.m_id] = trans;

      // Queue for W channel
      m_w_queue.push_back(trans);

      // Transaction interval - wait specified cycles before next transaction
      repeat (m_trans_interval) begin
        @(posedge m_vif.aclk);
        if (!m_reset_done) break;
      end
    end
  endtask

  // Drive write data channel - direct signal access
  task drive_w_channel();
    axi4_transaction trans;
    int w_count;

    forever begin
      @(posedge m_vif.aclk);

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
              m_vif.wdata <= trans.m_data[beat];
              m_vif.wstrb <= trans.m_wstrb[beat];
              m_vif.wlast <= (beat == trans.m_len);
              m_vif.wuser <= trans.m_wuser[beat];
              m_vif.wvalid <= 1'b1;

              @(posedge m_vif.aclk);
              while (!m_vif.wready && m_reset_done) begin
                @(posedge m_vif.aclk);
              end
              if (!m_reset_done) break;
            end

            if (m_reset_done) begin
              trans.m_data_complete_time = $time;
            end
            m_vif.wvalid <= 1'b0;
            m_vif.wlast <= 1'b0;
            m_vif.wuser <= '0;
          end
        end else begin
          // Data before addr mode: check osd limit
          if (w_count <= m_cfg.m_data_before_addr_osd) begin
            trans = m_w_queue.pop_front();

            for (int beat = 0; beat <= trans.m_len && m_reset_done; beat++) begin
              m_vif.wdata <= trans.m_data[beat];
              m_vif.wstrb <= trans.m_wstrb[beat];
              m_vif.wlast <= (beat == trans.m_len);
              m_vif.wuser <= trans.m_wuser[beat];
              m_vif.wvalid <= 1'b1;

              @(posedge m_vif.aclk);
              while (!m_vif.wready && m_reset_done) begin
                @(posedge m_vif.aclk);
              end
              if (!m_reset_done) break;
            end

            if (m_reset_done) begin
              trans.m_data_complete_time = $time;
            end
            m_vif.wvalid <= 1'b0;
            m_vif.wlast <= 1'b0;
            m_vif.wuser <= '0;
          end
        end
      end
    end
  endtask

  // Drive write response channel - direct signal access
  task drive_b_channel();
    forever begin
      @(posedge m_vif.aclk);

      // Skip if reset not done
      if (!m_reset_done) begin
        m_vif.bready <= 1'b0;
        continue;
      end

      m_vif.bready <= 1'b1;

      if (m_vif.bvalid) begin
        if (m_b_pending.exists(m_vif.bid)) begin
          m_b_pending.delete(m_vif.bid);
        end
      end
    end
  endtask

  // Drive read address channel - direct signal access, no clocking block
  task drive_ar_channel();
    axi4_transaction trans;

    forever begin
      // Wait for clock edge first
      @(posedge m_vif.aclk);

      if (!m_reset_done) continue;

      // Skip if no pending transaction
      if (m_ar_pending.size() == 0) continue;

      trans = m_ar_pending.pop_front();

      // Drive all AR signals together using non-blocking assignment
      m_vif.arid    <= trans.m_id;
      m_vif.araddr  <= trans.m_addr;
      m_vif.arlen   <= trans.m_len;
      m_vif.arsize  <= trans.m_size;
      m_vif.arburst <= trans.m_burst;
      m_vif.arlock  <= trans.m_lock;
      m_vif.arcache <= trans.m_cache;
      m_vif.arprot  <= trans.m_prot;
      m_vif.arqos   <= trans.m_qos;
      m_vif.arregion <= trans.m_region;
      m_vif.aruser  <= trans.m_user;
      m_vif.arvalid <= 1'b1;

      `uvm_info(get_type_name(), $sformatf("AR channel: Driving araddr=0x%0h, arid=0x%0h, arvalid=1 at time %0t", trans.m_addr, trans.m_id, $time), UVM_LOW)

      // Wait for address to be accepted (arready asserted)
      // Keep arvalid high until arready is seen
      while (1) begin
        @(posedge m_vif.aclk);
        if (!m_reset_done) break;
        if (m_vif.arready) break;
      end

      if (!m_reset_done) begin
        m_vif.arvalid <= 1'b0;
        continue;
      end

      trans.m_addr_accept_time = $time;
      m_vif.arvalid <= 1'b0;

      `uvm_info(get_type_name(), $sformatf("AR channel: Address 0x%0h accepted at time %0t", trans.m_addr, $time), UVM_LOW)

      // Transaction interval - wait specified cycles before next transaction
      repeat (m_trans_interval) begin
        @(posedge m_vif.aclk);
        if (!m_reset_done) break;
      end
    end
  endtask

  // Drive read data channel (receive) - direct signal access
  task drive_r_channel();
    logic [31:0] rid;

    forever begin
      @(posedge m_vif.aclk);

      // Skip if reset not done
      if (!m_reset_done) begin
        m_vif.rready <= 1'b0;
        continue;
      end

      m_vif.rready <= 1'b1;

      if (m_vif.rvalid && m_vif.rlast) begin
        // Read transaction completed
        rid = m_vif.rid;
      end
    end
  endtask

endclass : axi4_master_driver

`endif // AXI4_MASTER_DRIVER_SV
