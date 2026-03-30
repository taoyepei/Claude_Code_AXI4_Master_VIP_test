`ifndef AXI4_DATA_BEFORE_ADDR_SEQUENCE_SV
`define AXI4_DATA_BEFORE_ADDR_SEQUENCE_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here

// Test sequence for Data-Before-Address feature
// This sequence sends multiple write transactions concurrently to create
// conditions where W data is sent before AW address
class axi4_data_before_addr_sequence extends axi4_sequence;
  `uvm_object_utils(axi4_data_before_addr_sequence)

  // Number of concurrent transactions to create overlapping
  int m_num_concurrent;

  // Delay between starting each transaction (in clock cycles)
  int m_inter_trans_delay;

  // Use response handler instead of blocking finish_item
  axi4_transaction m_pending_responses[$];
  int m_expected_responses;
  int m_received_responses;

  function new(string name = "axi4_data_before_addr_sequence");
    super.new(name);
    m_num_concurrent = 4;      // Default: 4 concurrent transactions
    m_inter_trans_delay = 0;   // Default: no delay between starts
    m_expected_responses = 0;
    m_received_responses = 0;
  endfunction

  // Override do_print for better debug
  function string convert2string();
    string s;
    s = $sformatf("%s, num_concurrent=%0d, inter_trans_delay=%0d",
                  super.convert2string(), m_num_concurrent, m_inter_trans_delay);
    return s;
  endfunction

  // Response handler callback
  virtual function void response_handler(uvm_sequence_item response);
    axi4_transaction rsp;
    if ($cast(rsp, response)) begin
      m_received_responses++;
      `uvm_info(get_type_name(),
        $sformatf("Received response %0d/%0d: id=%0d, num_beats=%0d",
                  m_received_responses, m_expected_responses, rsp.m_id, rsp.m_data.size()),
        UVM_MEDIUM)
    end
  endfunction

  // Execute multiple concurrent write transactions
  // Use fork-join_none to not wait for completion
  task execute_concurrent_writes();
    axi4_transaction trans_list[$];
    int trans_id_base;

    trans_id_base = m_next_trans_id;
    m_expected_responses = m_num_concurrent;
    m_received_responses = 0;

    `uvm_info(get_type_name(),
      $sformatf("Starting %0d concurrent write transactions with delay=%0d cycles",
                m_num_concurrent, m_inter_trans_delay), UVM_LOW)

    // Pre-create all transactions
    for (int i = 0; i < m_num_concurrent; i++) begin
      axi4_transaction trans;
      trans = axi4_transaction::type_id::create($sformatf("write_trans_%0d", i));

      // Assign unique ID
      m_next_trans_id = (m_next_trans_id + 1) % (1 << `AXI4_ID_WIDTH);

      // Randomize transaction
      if (!trans.randomize() with {
        m_trans_type == WRITE;
        m_burst == m_burst_type;
        m_len inside {[m_min_len:m_max_len]};
        m_size == m_transfer_size;
        m_id == m_next_trans_id;
      }) begin
        `uvm_fatal(get_type_name(), "Transaction randomization failed")
        return;
      end

      trans_list.push_back(trans);
      `uvm_info(get_type_name(),
        $sformatf("Created write trans[%0d]: addr=0x%0h, len=%0d, size=%0d, id=%0d",
                  i, trans.m_addr, trans.m_len, trans.m_size, trans.m_id),
        UVM_MEDIUM)
    end

    // Start all transactions concurrently using fork-join_none
    foreach (trans_list[i]) begin
      automatic int idx = i;
      fork
        begin
          // Optional delay before starting this transaction
          if (m_inter_trans_delay > 0 && idx > 0) begin
            repeat(m_inter_trans_delay) @(posedge p_sequencer.m_vif.aclk);
          end

          `uvm_info(get_type_name(),
            $sformatf("Starting write trans[%0d]: addr=0x%0h, id=%0d",
                      idx, trans_list[idx].m_addr, trans_list[idx].m_id),
            UVM_MEDIUM)

          // Use non-blocking send to allow overlap
          // set_auto_item_recording(0) prevents automatic response handling
          trans_list[idx].set_sequence_id(this.get_sequence_id());
          start_item(trans_list[idx]);
          finish_item(trans_list[idx]);

          `uvm_info(get_type_name(),
            $sformatf("Write trans[%0d] completed", idx),
            UVM_MEDIUM)
        end
      join_none
    end

    // Wait for all transactions to complete
    // Use wait fork or track responses
    wait fork;

    `uvm_info(get_type_name(),
      $sformatf("All %0d concurrent write transactions completed",
                m_num_concurrent), UVM_LOW)
  endtask

  // Alternative: Send writes then immediately send reads
  // This creates maximum pressure on the driver queues
  task execute_stress_test();
    axi4_transaction write_trans[$];
    int trans_id_base;

    trans_id_base = m_next_trans_id;

    `uvm_info(get_type_name(),
      $sformatf("Starting stress test with %0d transactions", m_num_concurrent), UVM_LOW)

    // Phase 1: Rapid-fire all write transactions
    `uvm_info(get_type_name(), "Phase 1: Rapid write transactions", UVM_MEDIUM)

    for (int i = 0; i < m_num_concurrent; i++) begin
      axi4_transaction trans;
      trans = axi4_transaction::type_id::create($sformatf("stress_write_%0d", i));

      m_next_trans_id = (m_next_trans_id + 1) % (1 << `AXI4_ID_WIDTH);

      if (!trans.randomize() with {
        m_trans_type == WRITE;
        m_burst == m_burst_type;
        m_len inside {[m_min_len:m_max_len]};
        m_size == m_transfer_size;
        m_id == m_next_trans_id;
      }) begin
        `uvm_fatal(get_type_name(), "Transaction randomization failed")
        return;
      end

      // Store for later read verification
      write_trans.push_back(trans);

      `uvm_info(get_type_name(),
        $sformatf("Sending write[%0d]: addr=0x%0h, len=%0d, id=%0d",
                  i, trans.m_addr, trans.m_len, trans.m_id),
        UVM_MEDIUM)

      // Use grab/ungrab to send rapidly without waiting
      grab();
      start_item(trans);
      finish_item(trans);
      ungrab();

      // Minimal delay between transactions
      #0;
    end

    // Small delay to let writes propagate
    repeat(10) @(posedge p_sequencer.m_vif.aclk);

    // Phase 2: Send read transactions to verify
    `uvm_info(get_type_name(), "Phase 2: Read verification", UVM_MEDIUM)

    foreach (write_trans[i]) begin
      axi4_transaction rd_trans;
      rd_trans = axi4_transaction::type_id::create($sformatf("stress_read_%0d", i));

      if (!rd_trans.randomize() with {
        m_trans_type == READ;
        m_burst == m_burst_type;
        m_addr == write_trans[i].m_addr;
        m_len == write_trans[i].m_len;
        m_size == write_trans[i].m_size;
        m_id == write_trans[i].m_id;
      }) begin
        `uvm_fatal(get_type_name(), "Read transaction randomization failed")
        return;
      end

      `uvm_info(get_type_name(),
        $sformatf("Sending read[%0d]: addr=0x%0h, id=%0d",
                  i, rd_trans.m_addr, rd_trans.m_id),
        UVM_MEDIUM)

      start_item(rd_trans);
      finish_item(rd_trans);

      // Get response and verify
      get_response(rd_trans);
      // Data verification would go here
    end

    `uvm_info(get_type_name(), "Stress test completed", UVM_LOW)
  endtask

  // Main body - select test mode
  task body();
    // Validate configuration first
    if (!check_size_valid()) begin
      `uvm_fatal(get_type_name(), "Size configuration check failed - aborting sequence")
      return;
    end

    // Check if data_before_addr is enabled
    if (p_sequencer.m_cfg.m_support_data_before_addr) begin
      `uvm_info(get_type_name(),
        $sformatf("Data-Before-Address enabled: osd_limit=%0d",
                  p_sequencer.m_cfg.m_data_before_addr_osd),
        UVM_LOW)
    end else begin
      `uvm_warning(get_type_name(),
        "Data-Before-Address NOT enabled in configuration. Set m_support_data_before_addr=1 to test this feature.")
    end

    // Run concurrent write test
    execute_concurrent_writes();

    // Optional: Run stress test
    // execute_stress_test();
  endtask

endclass : axi4_data_before_addr_sequence

`endif // AXI4_DATA_BEFORE_ADDR_SEQUENCE_SV
