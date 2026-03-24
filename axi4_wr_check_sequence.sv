`ifndef AXI4_WR_CHECK_SEQUENCE_SV
`define AXI4_WR_CHECK_SEQUENCE_SV

// Note: This file is included inside axi4_pkg package
// Do not add package/import statements here

// Write-Read-Check Sequence
// 1. Send N write transactions (N = m_num_writes)
// 2. Repeat step 1 for M iterations (M = m_num_iterations)
// 3. Read back all written addresses and compare data
// 4. Report uvm_error if any mismatch

class axi4_wr_check_sequence extends uvm_sequence #(axi4_transaction);
  `uvm_object_utils(axi4_wr_check_sequence)
  `uvm_declare_p_sequencer(uvm_sequencer #(axi4_transaction))

  // Configuration: number of writes per iteration
  rand int m_num_writes;
  // Configuration: number of iterations
  rand int m_num_iterations;
  // Configuration: transfer size for all transactions
  rand bit [2:0] m_transfer_size;
  // Configuration: enable size check
  bit m_check_size_valid;

  // Burst type (default INCR for sequential writes)
  rand axi4_burst_t m_burst_type;

  // Length range
  rand int m_min_len;
  rand int m_max_len;

  // Address control - use 64-bit internally but mask to AXI4_ADDR_WIDTH when used
  rand bit [63:0] m_start_addr;
  rand bit        m_use_start_addr;
  rand bit [63:0] m_addr_increment;

  // Storage for write transactions (for later readback verification)
  // Use queues indexed by iteration
  axi4_transaction m_write_trans_queue[$][$];  // [iteration][transaction]
  bit [`AXI4_ADDR_WIDTH-1:0] m_write_addr_queue[$][$];   // [iteration][address per beat]
  logic [`AXI4_DATA_WIDTH-1:0] m_write_data_queue[$][$];   // [iteration][data per beat]
  int              m_write_len_queue[$][$];     // [iteration][length per trans]
  bit [2:0]        m_write_size_queue[$][$];    // [iteration][size per trans]

  constraint c_num_writes {
    m_num_writes inside {[1:100]};
  }

  constraint c_num_iterations {
    m_num_iterations inside {[1:10]};
  }

  constraint c_len_range {
    m_min_len >= 0;
    m_max_len <= 255;
    m_min_len <= m_max_len;
  }

  constraint c_transfer_size {
    m_transfer_size inside {[0:7]};
    // Must not exceed data bus width
    (1 << m_transfer_size) <= (`AXI4_DATA_WIDTH / 8);
  }

  constraint c_burst_type {
    m_burst_type inside {FIXED, INCR, WRAP};
  }

  constraint c_addr_increment {
    m_addr_increment inside {0, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384};
  }

  function new(string name = "axi4_wr_check_sequence");
    super.new(name);
    m_num_writes = 10;
    m_num_iterations = 1;
    m_transfer_size = 3;      // Default 8 bytes (64-bit)
    m_check_size_valid = 1;   // Enable size check by default
    m_burst_type = INCR;
    m_min_len = 0;
    m_max_len = 15;
    m_start_addr = 64'h0;
    m_use_start_addr = 0;
    m_addr_increment = 64'h1000;
  endfunction

  // Check if the configured size is valid
  function bit check_size_valid();
    int max_size;
    int max_bytes;

    max_bytes = `AXI4_DATA_WIDTH / 8;

    // Calculate max size: log2(max_bytes)
    case (max_bytes)
      1: max_size = 0;
      2: max_size = 1;
      4: max_size = 2;
      8: max_size = 3;
      16: max_size = 4;
      32: max_size = 5;
      64: max_size = 6;
      128: max_size = 7;
      default: max_size = 3;
    endcase

    if (m_transfer_size > max_size) begin
      `uvm_error(get_type_name(),
        $sformatf("Invalid m_transfer_size=%0d for AXI4_DATA_WIDTH=%0d (max allowed size=%0d)",
                  m_transfer_size, `AXI4_DATA_WIDTH, max_size))
      return 0;
    end

    if (m_use_start_addr && ((m_start_addr % (1 << m_transfer_size)) != 0)) begin
      `uvm_error(get_type_name(),
        $sformatf("Address alignment error: m_start_addr=0x%0h is not aligned to m_transfer_size=%0d",
                  m_start_addr, m_transfer_size))
      return 0;
    end

    return 1;
  endfunction

  task pre_start();
    super.pre_start();
    `uvm_info(get_type_name(), $sformatf("Starting WR-check sequence: %s", get_name()), UVM_LOW)

    if (m_check_size_valid && !check_size_valid()) begin
      `uvm_fatal(get_type_name(), "Size configuration check failed - aborting sequence")
    end
  endtask

  task pre_body();
    super.pre_body();
    if (starting_phase != null) begin
      starting_phase.raise_objection(this, get_type_name());
      starting_phase.get_objection().set_propagate_mode(0);
    end
  endtask

  // Execute write phase: send N writes for M iterations
  task execute_write_phase();
    axi4_transaction trans;
    int iter, w_idx;
    bit [`AXI4_ADDR_WIDTH-1:0] current_addr;
    int bytes_per_beat;
    // Variables for beat processing (moved to task level for SV compliance)
    int beat;
    bit [`AXI4_ADDR_WIDTH-1:0] beat_addr;
    bit [63:0] full_beat_addr;  // Temporary for function return
    int max_size;

    // Calculate max allowed size based on data width
    case (`AXI4_DATA_WIDTH)
      8:    max_size = 0;
      16:   max_size = 1;
      32:   max_size = 2;
      64:   max_size = 3;
      128:  max_size = 4;
      256:  max_size = 5;
      512:  max_size = 6;
      1024: max_size = 7;
      default: max_size = 3;
    endcase

    if (m_transfer_size > max_size) begin
      `uvm_fatal(get_type_name(), $sformatf("m_transfer_size=%0d exceeds max allowed size=%0d for AXI4_DATA_WIDTH=%0d",
                m_transfer_size, max_size, `AXI4_DATA_WIDTH))
      return;
    end

    bytes_per_beat = 1 << m_transfer_size;

    for (iter = 0; iter < m_num_iterations; iter++) begin
      // Initialize storage for this iteration
      m_write_trans_queue[iter] = {};
      m_write_addr_queue[iter] = {};
      m_write_data_queue[iter] = {};
      m_write_len_queue[iter] = {};
      m_write_size_queue[iter] = {};

      if (m_use_start_addr) begin
        // Mask start_addr to valid address width
        current_addr = m_start_addr[`AXI4_ADDR_WIDTH-1:0];
        current_addr = current_addr + (iter * m_num_writes * m_addr_increment[`AXI4_ADDR_WIDTH-1:0]);
      end

      `uvm_info(get_type_name(), $sformatf("Iteration %0d/%0d: Sending %0d write transactions",
                iter+1, m_num_iterations, m_num_writes), UVM_MEDIUM)

      `uvm_info(get_type_name(), $sformatf("DEBUG: m_use_start_addr=%0b, m_start_addr=0x%0h, current_addr=0x%0h",
                m_use_start_addr, m_start_addr, current_addr), UVM_LOW)

      for (w_idx = 0; w_idx < m_num_writes; w_idx++) begin
        trans = axi4_transaction::type_id::create($sformatf("write_iter%0d_trans%0d", iter, w_idx));

        if (m_use_start_addr) begin
          `uvm_info(get_type_name(), $sformatf("DEBUG: randomizing with m_addr == 0x%0h (current_addr)", current_addr), UVM_LOW)
          if (!trans.randomize() with {
            m_trans_type == WRITE;
            m_burst == m_burst_type;
            m_len == m_min_len;
            m_size == m_transfer_size;
            m_addr == current_addr;
          }) begin
            `uvm_fatal(get_type_name(), "Write transaction randomization failed")
            return;
          end
          `uvm_info(get_type_name(), $sformatf("DEBUG: after randomize, trans.m_addr=0x%0h", trans.m_addr), UVM_LOW)
        end else begin
          if (!trans.randomize() with {
            m_trans_type == WRITE;
            m_burst == m_burst_type;
            m_len == m_min_len;
            m_size == m_transfer_size;
          }) begin
            `uvm_fatal(get_type_name(), "Write transaction randomization failed")
            return;
          end
        end

        // Store transaction info for later verification
        m_write_trans_queue[iter].push_back(trans);
        m_write_len_queue[iter].push_back(trans.m_len);
        m_write_size_queue[iter].push_back(trans.m_size);

        // Calculate and store addresses for each beat
        for (beat = 0; beat <= trans.m_len; beat++) begin
          full_beat_addr = trans.get_beat_addr(beat);
          beat_addr = full_beat_addr[`AXI4_ADDR_WIDTH-1:0];
          m_write_addr_queue[iter].push_back(beat_addr);
          m_write_data_queue[iter].push_back(trans.m_data[beat]);
        end

        `uvm_info(get_type_name(), $sformatf("Sending write [%0d][%0d]: addr=0x%0h, len=%0d, size=%0d",
                  iter, w_idx, current_addr, trans.m_len, trans.m_size), UVM_MEDIUM)

        start_item(trans);
        finish_item(trans);

        if (m_use_start_addr) begin
          current_addr = current_addr + ((trans.m_len + 1) * bytes_per_beat);
          // Add gap if needed to avoid overlap
          if (w_idx < m_num_writes - 1) begin
            bit [`AXI4_ADDR_WIDTH-1:0] addr_inc;
            addr_inc = m_addr_increment[`AXI4_ADDR_WIDTH-1:0];
            current_addr = current_addr + addr_inc;
          end
        end
      end
    end

    `uvm_info(get_type_name(), "All write transactions completed", UVM_MEDIUM)
  endtask

  // Execute read phase: read back and verify all written data
  task execute_read_phase();
    axi4_transaction trans;
    int iter, r_idx;
    int total_trans;
    int error_count;
    // Variables for data verification (moved to task level for SV compliance)
    int beat;
    logic [`AXI4_DATA_WIDTH-1:0] expected_data;
    logic [`AXI4_DATA_WIDTH-1:0] actual_data;
    logic [`AXI4_DATA_WIDTH-1:0] data_mask;
    bit [`AXI4_ADDR_WIDTH-1:0] beat_addr;
    int data_idx;
    int bytes_per_beat;
    // Variables for read transaction processing
    bit [`AXI4_ADDR_WIDTH-1:0] expected_addr;
    bit [63:0] full_expected_addr;  // Temporary for 64-bit address
    int expected_len;
    bit [2:0] expected_size;
    int data_idx_start;

    total_trans = m_num_iterations * m_num_writes;
    error_count = 0;

    `uvm_info(get_type_name(), $sformatf("Starting readback verification of %0d transactions",
              total_trans), UVM_MEDIUM)

    for (iter = 0; iter < m_num_iterations; iter++) begin
      for (r_idx = 0; r_idx < m_num_writes; r_idx++) begin
        // Get expected values from stored write transaction
        full_expected_addr = m_write_trans_queue[iter][r_idx].m_addr;
        expected_addr = full_expected_addr[`AXI4_ADDR_WIDTH-1:0];
        expected_len = m_write_len_queue[iter][r_idx];
        expected_size = m_write_size_queue[iter][r_idx];

        // Calculate starting index in address/data queues
        data_idx_start = 0;
        for (int i = 0; i < r_idx; i++) begin
          data_idx_start += m_write_len_queue[iter][i] + 1;
        end

        // Create read transaction
        trans = axi4_transaction::type_id::create($sformatf("read_iter%0d_trans%0d", iter, r_idx));

        if (!trans.randomize() with {
          m_trans_type == READ;
          m_burst == m_burst_type;
          m_addr == expected_addr;  // Compare full 64-bit value
          m_len == expected_len;
          m_size == expected_size;
        }) begin
          `uvm_fatal(get_type_name(), "Read transaction randomization failed")
          return;
        end

        `uvm_info(get_type_name(), $sformatf("Sending read [%0d][%0d]: addr=0x%0h, len=%0d, size=%0d",
                  iter, r_idx, expected_addr, trans.m_len, trans.m_size), UVM_MEDIUM)

        start_item(trans);
        finish_item(trans);

        // Wait for read response with data
        get_response(trans);
        `uvm_info(get_type_name(), $sformatf("Read response received with %0d beats", trans.m_data.size()), UVM_HIGH)

        // Verify read data against stored write data
        for (beat = 0; beat <= expected_len; beat++) begin
          data_idx = data_idx_start + beat;
          expected_data = m_write_data_queue[iter][data_idx];
          actual_data = trans.m_data[beat];
          beat_addr = m_write_addr_queue[iter][data_idx];

          // Mask data based on transfer size
          bytes_per_beat = 1 << expected_size;
          if (bytes_per_beat * 8 >= `AXI4_DATA_WIDTH) begin
            data_mask = '1;
          end else begin
            data_mask = (1 << (bytes_per_beat * 8)) - 1;
          end

          if ((expected_data & data_mask) !== (actual_data & data_mask)) begin
            `uvm_error(get_type_name(),
              $sformatf("DATA MISMATCH! iter=%0d, trans=%0d, beat=%0d, addr=0x%0h\n  Expected: 0x%0h\n  Actual:   0x%0h",
                        iter, r_idx, beat, beat_addr, expected_data & data_mask, actual_data & data_mask))
            error_count++;
          end else begin
            `uvm_info(get_type_name(),
              $sformatf("Data match: iter=%0d, trans=%0d, beat=%0d, addr=0x%0h, data=0x%0h",
                        iter, r_idx, beat, beat_addr, actual_data & data_mask), UVM_HIGH)
          end
        end
      end
    end

    // Report final result
    if (error_count == 0) begin
      `uvm_info(get_type_name(),
        $sformatf("READBACK VERIFICATION PASSED: All %0d transactions verified successfully",
                  total_trans), UVM_LOW)
    end else begin
      `uvm_error(get_type_name(),
        $sformatf("READBACK VERIFICATION FAILED: %0d mismatches found out of %0d transactions",
                  error_count, total_trans))
    end
  endtask

  task body();
    // Debug: print all configuration values at start
    `uvm_info(get_type_name(), $sformatf("DEBUG body start: m_use_start_addr=%0b, m_start_addr=0x%0h, m_num_writes=%0d, m_num_iterations=%0d",
              m_use_start_addr, m_start_addr, m_num_writes, m_num_iterations), UVM_LOW)
    // Phase 1: Write all data
    execute_write_phase();

    // Wait for all write responses to complete before starting read
    `uvm_info(get_type_name(), $sformatf("Waiting for %0d write responses...", m_num_writes * m_num_iterations), UVM_MEDIUM)
    for (int i = 0; i < m_num_writes * m_num_iterations; i++) begin
      axi4_transaction rsp;
      get_response(rsp);
      `uvm_info(get_type_name(), $sformatf("Write response %0d/%0d received", i+1, m_num_writes * m_num_iterations), UVM_HIGH)
    end
    `uvm_info(get_type_name(), "All write responses received, starting read phase", UVM_MEDIUM)

    // Phase 2: Read back and verify
    execute_read_phase();
  endtask

  task post_body();
    super.post_body();
    if (starting_phase != null) begin
      starting_phase.drop_objection(this, get_type_name());
    end
  endtask

  task post_start();
    super.post_start();
    `uvm_info(get_type_name(), $sformatf("WR-check sequence %s completed", get_name()), UVM_LOW)
  endtask

endclass : axi4_wr_check_sequence

`endif // AXI4_WR_CHECK_SEQUENCE_SV
