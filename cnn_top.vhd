-- ═══════════════════════════════════════════════════════════════
-- cnn_top.vhd  (revision 6 - true BRAM inference)
-- Author  : Langovan Sreenithi
-- Device  : Xilinx Zynq 7z020clg484-1
-- Clock   : 100 MHz
--
-- BRAM fix vs revision 5:
--   fmap1 and fmap2 are now proper synchronous-read BRAMs.
--   ram_style="block" alone does not work when reads are
--   combinational (async).  The fix uses:
--     1. A single BRAM array per feature map (1 write + 1 read port)
--     2. Sequential 4-phase pixel reads for 2x2 pooling windows
--        (states RD0→RD1→RD2→FIRE instead of just FIRE)
--     3. State-based combinational address mux so the BRAM
--        read address is stable during each state and captured
--        at the rising edge - data valid the next cycle.
--   Expected BRAM savings:
--     fmap1: 26×26×8×8b = 43 264 b → ~1.5 RAMB36
--     fmap2: 11×11×16×8b = 15 488 b → ~0.5 RAMB36
--     Total: ~6 RAMB18 / 3 RAMB36 (vs 0 before)
--     LUT savings: ~35 000 distributed-RAM LUTs freed
-- ═══════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.cnn_pkg.all;
use work.weights_pkg.all;

entity cnn_top is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic;
        done       : out std_logic;
        pred_class : out integer range 0 to 9
    );
end entity cnn_top;

architecture rtl of cnn_top is

    -- ── Layer dimension constants ─────────────────────────────
    constant IMG_H      : integer := 28;
    constant IMG_W      : integer := 28;
    constant C1_OH      : integer := 26;
    constant C1_OW      : integer := 26;
    constant C1_NF      : integer := 8;
    constant C1_NC      : integer := 1;
    constant P1_OH      : integer := 13;
    constant P1_OW      : integer := 13;
    constant C2_OH      : integer := 11;
    constant C2_OW      : integer := 11;
    constant C2_NF      : integer := 16;
    constant C2_NC      : integer := 8;
    constant P2_OH      : integer := 5;
    constant P2_OW      : integer := 5;
    constant FC1_IN     : integer := 400;
    constant FC1_OUT    : integer := 64;
    constant FC2_IN     : integer := 64;
    constant FC2_OUT    : integer := 10;
    constant FC1_CHUNKS : integer := 45;
    constant FC2_CHUNKS : integer := 8;
    constant SHIFT      : integer := 8;

    -- ── Address helper functions ──────────────────────────────
    function f1_addr(r, c, fi : integer) return integer is
    begin return r*C1_OW*C1_NF + c*C1_NF + fi; end function;

    function p1_addr(r, c, fi : integer) return integer is
    begin return r*P1_OW*C1_NF + c*C1_NF + fi; end function;

    function f2_addr(r, c, fi : integer) return integer is
    begin return r*C2_OW*C2_NF + c*C2_NF + fi; end function;

    function p2_addr(r, c, fi : integer) return integer is
    begin return r*P2_OW*C2_NF + c*C2_NF + fi; end function;

    -- ── FSM state type ────────────────────────────────────────
    -- Pool1 and Pool2 each have 4 sequential read states:
    --   ADDRGEN → RD0 → RD1 → RD2 → FIRE → WAIT → NEXT
    -- ADDRGEN/RD0/RD1/RD2 each present one pixel address to the
    -- BRAM; data appears one cycle later in RD0/RD1/RD2/FIRE.
    type state_t is (
        S_IDLE,
        S_C1_LOAD,    S_C1_WAIT,
        S_C1_QUANT,   S_C1_QUANT_WAIT,  S_C1_NEXT,
        S_P1_ADDRGEN, S_P1_RD0, S_P1_RD1, S_P1_RD2,
        S_P1_FIRE,    S_P1_WAIT,         S_P1_NEXT,
        S_C2_ADDRGEN, S_C2_LOAD,         S_C2_WAIT,
        S_C2_QUANT,   S_C2_QUANT_WAIT,   S_C2_NEXT,
        S_P2_ADDRGEN, S_P2_RD0, S_P2_RD1, S_P2_RD2,
        S_P2_FIRE,    S_P2_WAIT,         S_P2_NEXT,
        S_FC1_ADDR,   S_FC1_CHUNK,       S_FC1_WAIT,
        S_FC2_ADDR,   S_FC2_CHUNK,       S_FC2_WAIT,
        S_ARGMAX_INIT, S_ARGMAX_STEP,    S_ARGMAX_WR,
        S_DONE
    );
    signal state : state_t := S_IDLE;

    -- ── Counters ──────────────────────────────────────────────
    signal oh     : integer range 0 to 31 := 0;
    signal ow     : integer range 0 to 31 := 0;
    signal ch     : integer range 0 to 15 := 0;
    signal f      : integer range 0 to 15 := 0;
    signal neuron : integer range 0 to 63 := 0;
    signal chunk  : integer range 0 to 44 := 0;
    signal done_r : std_logic             := '0';

    -- ══════════════════════════════════════════════════════════
    -- BRAM: fmap1  (26×26×8 = 5408 entries × 8 bit)
    --
    -- Vivado SDP BRAM inference pattern:
    --   Write port: synchronous write-enable
    --   Read port:  synchronous registered output
    --   Both in the same clocked process → Vivado infers BRAM
    --
    -- Write timing:
    --   S_C1_QUANT:      fmap1_wr_addr <= f1_addr(oh,ow,f)
    --   S_C1_QUANT_WAIT: fmap1_we driven '1' when q_valid_out='1'
    --
    -- Read timing (sequential, 1 pixel per cycle):
    --   Address mux changes each state; BRAM output valid
    --   one cycle after the address is presented:
    --     ADDRGEN presents p00 → RD0  has p00 data
    --     RD0     presents p01 → RD1  has p01 data
    --     RD1     presents p10 → RD2  has p10 data
    --     RD2     presents p11 → FIRE has p11 data
    -- ══════════════════════════════════════════════════════════
    type fmap1_t is array(0 to C1_OH*C1_OW*C1_NF-1)
        of signed(ACT_WIDTH-1 downto 0);
    signal fmap1_mem : fmap1_t := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of fmap1_mem : signal is "block";

    -- Write port signals
    signal fmap1_we      : std_logic := '0';
    signal fmap1_wr_addr : integer range 0 to C1_OH*C1_OW*C1_NF-1 := 0;

    -- Read port signals
    signal fmap1_rd_addr : integer range 0 to C1_OH*C1_OW*C1_NF-1 := 0;
    signal fmap1_rd_data : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    -- Pixel buffers for sequential pooling reads
    signal p1_p00_r, p1_p01_r, p1_p10_r
        : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    -- Pool1 write address (pre-registered in ADDRGEN)
    signal p1_wr_addr : integer range 0 to P1_OH*P1_OW*C1_NF-1 := 0;

    -- ══════════════════════════════════════════════════════════
    -- BRAM: fmap2  (11×11×16 = 1936 entries × 8 bit)
    -- Same inference pattern as fmap1.
    -- ══════════════════════════════════════════════════════════
    type fmap2_t is array(0 to C2_OH*C2_OW*C2_NF-1)
        of signed(ACT_WIDTH-1 downto 0);
    signal fmap2_mem : fmap2_t := (others => (others => '0'));

    attribute ram_style of fmap2_mem : signal is "block";

    signal fmap2_we      : std_logic := '0';
    signal fmap2_wr_addr : integer range 0 to C2_OH*C2_OW*C2_NF-1 := 0;

    signal fmap2_rd_addr : integer range 0 to C2_OH*C2_OW*C2_NF-1 := 0;
    signal fmap2_rd_data : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    signal p2_p00_r, p2_p01_r, p2_p10_r
        : signed(ACT_WIDTH-1 downto 0) := (others => '0');

    signal p2_wr_addr : integer range 0 to P2_OH*P2_OW*C2_NF-1 := 0;

    -- ── Distributed RAM: pool1, pool2, fc1out, fc2out ─────────
    -- pool1 MUST stay distributed (1-cycle combinational read
    -- required for timing - S_C2_LOAD reads pool1 after ADDRGEN)
    type pool1_t  is array(0 to P1_OH*P1_OW*C1_NF-1)
        of signed(ACT_WIDTH-1 downto 0);
    type pool2_t  is array(0 to P2_OH*P2_OW*C2_NF-1)
        of signed(ACT_WIDTH-1 downto 0);
    type fc1out_t is array(0 to FC1_OUT-1)
        of signed(ACT_WIDTH-1 downto 0);
    type fc2out_t is array(0 to FC2_OUT-1)
        of signed(ACT_WIDTH-1 downto 0);

    signal pool1  : pool1_t  := (others => (others => '0'));
    signal pool2  : pool2_t  := (others => (others => '0'));
    signal fc1out : fc1out_t := (others => (others => '0'));
    signal fc2out : fc2out_t := (others => (others => '0'));

    attribute ram_style of pool1  : signal is "distributed";
    attribute ram_style of pool2  : signal is "distributed";
    attribute ram_style of fc1out : signal is "distributed";
    attribute ram_style of fc2out : signal is "distributed";

    -- ── conv_engine signals ───────────────────────────────────
    signal ce_start        : std_logic := '0';
    signal ce_num_channels : integer range 1 to 8 := 1;
    signal ce_acts         : act_vec_t
        := (others => (others => '0'));
    signal ce_ws           : ws_array_t
        := (others => (others => (others => '0')));
    signal ce_done         : std_logic;
    signal ce_psums        : acc_array_t;

    -- ── quantize signals ──────────────────────────────────────
    signal q_valid_in  : std_logic := '0';
    signal q_acc_in    : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal q_bias_in   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal q_valid_out : std_logic;
    signal q_act_out   : signed(ACT_WIDTH-1 downto 0);

    -- ── maxpool signals ───────────────────────────────────────
    signal mp_valid_in  : std_logic := '0';
    signal mp_p00, mp_p01, mp_p10, mp_p11
        : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal mp_valid_out : std_logic;
    signal mp_max_out   : signed(ACT_WIDTH-1 downto 0);

    -- ── fc_engine signals ─────────────────────────────────────
    signal fc_chunk_valid : std_logic := '0';
    signal fc_last_chunk  : std_logic := '0';
    signal fc_acts_chunk  : act_vec_t := (others => (others => '0'));
    signal fc_ws_chunk    : weight_vec_t := (others => (others => '0'));
    signal fc_bias_in     : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal fc_done        : std_logic;
    signal fc_result      : signed(ACT_WIDTH-1 downto 0);

    -- ── Pre-registered addresses (timing fixes) ───────────────
    type addr9_t    is array(0 to 8) of integer range 0 to 1351;
    type fc_addr9_t is array(0 to 8) of integer range 0 to 25599;

    signal ce2_p1_addrs : addr9_t    := (others => 0);
    signal fc1_addrs    : fc_addr9_t := (others => 0);
    signal fc2_addrs    : fc_addr9_t := (others => 0);

    -- ── Argmax registers ──────────────────────────────────────
    signal max_val_r : signed(ACT_WIDTH-1 downto 0) := (others => '0');
    signal max_idx_r : integer range 0 to 9 := 0;
    signal argmax_n  : integer range 0 to 9 := 0;

begin

    -- ══════════════════════════════════════════════════════════
    -- BRAM write-enable concurrent assignments
    -- (combinational, derived from FSM state + quantize output)
    -- ══════════════════════════════════════════════════════════
    fmap1_we <= '1' when (state = S_C1_QUANT_WAIT and
                           q_valid_out = '1') else '0';
    fmap2_we <= '1' when (state = S_C2_QUANT_WAIT and
                           q_valid_out = '1') else '0';

    -- ══════════════════════════════════════════════════════════
    -- BRAM read address muxes (combinational)
    --
    -- Each pooling state presents a different pixel address.
    -- The BRAM registers this at the rising edge; data appears
    -- one cycle later (next state).
    --
    -- Timing verified:
    --   State S: fmap1_rd_addr = addr_S (combinational)
    --   Edge leaving S: BRAM clocks in addr_S
    --   State S+1: fmap1_rd_data = fmap1_mem[addr_S] ✓
    -- ══════════════════════════════════════════════════════════
    with state select fmap1_rd_addr <=
        f1_addr(2*oh,   2*ow,   f) when S_P1_ADDRGEN,
        f1_addr(2*oh,   2*ow+1, f) when S_P1_RD0,
        f1_addr(2*oh+1, 2*ow,   f) when S_P1_RD1,
        f1_addr(2*oh+1, 2*ow+1, f) when S_P1_RD2,
        0                          when others;

    with state select fmap2_rd_addr <=
        f2_addr(2*oh,   2*ow,   f) when S_P2_ADDRGEN,
        f2_addr(2*oh,   2*ow+1, f) when S_P2_RD0,
        f2_addr(2*oh+1, 2*ow,   f) when S_P2_RD1,
        f2_addr(2*oh+1, 2*ow+1, f) when S_P2_RD2,
        0                          when others;

    -- ══════════════════════════════════════════════════════════
    -- BRAM inference processes
    -- Pattern: synchronous write-enable + synchronous read
    -- in the same clocked process → Vivado infers RAMB36/18
    -- ══════════════════════════════════════════════════════════
    p_fmap1_bram : process(clk)
    begin
        if rising_edge(clk) then
            -- Write port (active in S_C1_QUANT_WAIT)
            if fmap1_we = '1' then
                fmap1_mem(fmap1_wr_addr) <= q_act_out;
            end if;
            -- Read port (synchronous - 1 cycle latency)
            fmap1_rd_data <= fmap1_mem(fmap1_rd_addr);
        end if;
    end process;

    p_fmap2_bram : process(clk)
    begin
        if rising_edge(clk) then
            if fmap2_we = '1' then
                fmap2_mem(fmap2_wr_addr) <= q_act_out;
            end if;
            fmap2_rd_data <= fmap2_mem(fmap2_rd_addr);
        end if;
    end process;

    -- ── Submodule instantiations ──────────────────────────────
    u_ce : entity work.conv_engine
        generic map(NUM_FILTERS => C2_NF, MAX_CHANNELS => C2_NC)
        port map(clk=>clk, rst=>rst, start=>ce_start,
                 num_channels=>ce_num_channels,
                 acts=>ce_acts, ws=>ce_ws,
                 done=>ce_done, psums=>ce_psums);

    u_quant : entity work.quantize
        generic map(SHIFT => SHIFT)
        port map(clk=>clk, rst=>rst,
                 valid_in=>q_valid_in,
                 acc_in=>q_acc_in, bias_in=>q_bias_in,
                 valid_out=>q_valid_out, act_out=>q_act_out);

    u_pool : entity work.maxpool2d
        port map(clk=>clk, rst=>rst,
                 valid_in=>mp_valid_in,
                 p00=>mp_p00, p01=>mp_p01,
                 p10=>mp_p10, p11=>mp_p11,
                 valid_out=>mp_valid_out, max_out=>mp_max_out);

    u_fc : entity work.fc_engine
        generic map(SHIFT => SHIFT)
        port map(clk=>clk, rst=>rst,
                 chunk_valid=>fc_chunk_valid,
                 last_chunk=>fc_last_chunk,
                 acts_chunk=>fc_acts_chunk,
                 ws_chunk=>fc_ws_chunk,
                 bias_in=>fc_bias_in,
                 done=>fc_done, result=>fc_result);

    -- ══════════════════════════════════════════════════════════
    -- Main FSM
    -- ══════════════════════════════════════════════════════════
    process(clk)
        variable base    : integer;
        variable inp_idx : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state          <= S_IDLE;
                done_r         <= '0';
                oh<=0; ow<=0; ch<=0; f<=0;
                neuron<=0; chunk<=0;
                ce_start       <= '0';
                q_valid_in     <= '0';
                mp_valid_in    <= '0';
                fc_chunk_valid <= '0';
                fc_last_chunk  <= '0';
                argmax_n       <= 0;
                max_val_r      <= (others => '0');
                max_idx_r      <= 0;
            else
                done_r         <= '0';
                ce_start       <= '0';
                q_valid_in     <= '0';
                mp_valid_in    <= '0';
                fc_chunk_valid <= '0';
                fc_last_chunk  <= '0';

                case state is

                -- ── IDLE ──────────────────────────────────────
                when S_IDLE =>
                    if start = '1' then
                        oh<=0; ow<=0; ch<=0; f<=0;
                        state <= S_C1_LOAD;
                    end if;

                -- ════════════════════════════════════════════
                -- CONV1  (shared engine, num_channels=1)
                -- Filters 0-7: real weights
                -- Filters 8-15: zeroed
                -- ════════════════════════════════════════════
                when S_C1_LOAD =>
                    for kr in 0 to 2 loop
                        for kc in 0 to 2 loop
                            ce_acts(kr*3+kc) <=
                                TEST_IMAGE((oh+kr)*IMG_W+(ow+kc));
                        end loop;
                    end loop;
                    for fi in 0 to C1_NF-1 loop
                        for k in 0 to 8 loop
                            ce_ws(fi)(k) <= CONV1_W(fi*9+k);
                        end loop;
                    end loop;
                    for fi in C1_NF to C2_NF-1 loop
                        ce_ws(fi) <= (others => (others => '0'));
                    end loop;
                    ce_num_channels <= C1_NC;
                    ce_start        <= '1';
                    state           <= S_C1_WAIT;

                when S_C1_WAIT =>
                    if ce_done = '1' then
                        f <= 0; state <= S_C1_QUANT;
                    end if;

                when S_C1_QUANT =>
                    q_acc_in      <= ce_psums(f);
                    q_bias_in     <= CONV1_B(f);
                    q_valid_in    <= '1';
                    -- Pre-register BRAM write address (timing fix)
                    fmap1_wr_addr <= f1_addr(oh, ow, f);
                    state         <= S_C1_QUANT_WAIT;

                when S_C1_QUANT_WAIT =>
                    -- fmap1 write is handled by the concurrent
                    -- fmap1_we signal + p_fmap1_bram process.
                    if q_valid_out = '1' then
                        if f = C1_NF-1 then
                            state <= S_C1_NEXT;
                        else
                            f     <= f + 1;
                            state <= S_C1_QUANT;
                        end if;
                    end if;

                when S_C1_NEXT =>
                    if ow = C1_OW-1 then
                        ow <= 0;
                        if oh = C1_OH-1 then
                            oh<=0; ow<=0; f<=0;
                            state <= S_P1_ADDRGEN;
                        else
                            oh    <= oh + 1;
                            state <= S_C1_LOAD;
                        end if;
                    else
                        ow    <= ow + 1;
                        state <= S_C1_LOAD;
                    end if;

                -- ════════════════════════════════════════════
                -- POOL1  (sequential BRAM reads, 4 cycles)
                --
                -- ADDRGEN: mux outputs p00 addr → BRAM captures
                -- RD0:     BRAM outputs p00; mux → p01 addr
                -- RD1:     BRAM outputs p01; mux → p10 addr
                -- RD2:     BRAM outputs p10; mux → p11 addr
                -- FIRE:    BRAM outputs p11; fire maxpool
                -- WAIT:    wait for mp_valid_out; write pool1
                -- ════════════════════════════════════════════
                when S_P1_ADDRGEN =>
                    -- fmap1_rd_addr = f1_addr(2*oh,2*ow,f) via mux
                    -- Pre-register pool1 write address (timing fix)
                    p1_wr_addr <= p1_addr(oh, ow, f);
                    state      <= S_P1_RD0;

                when S_P1_RD0 =>
                    -- fmap1_rd_data = fmap1[p00] (captured from ADDRGEN)
                    p1_p00_r <= fmap1_rd_data;
                    -- fmap1_rd_addr = f1_addr(2*oh,2*ow+1,f) via mux
                    state <= S_P1_RD1;

                when S_P1_RD1 =>
                    -- fmap1_rd_data = fmap1[p01]
                    p1_p01_r <= fmap1_rd_data;
                    -- fmap1_rd_addr = f1_addr(2*oh+1,2*ow,f) via mux
                    state <= S_P1_RD2;

                when S_P1_RD2 =>
                    -- fmap1_rd_data = fmap1[p10]
                    p1_p10_r <= fmap1_rd_data;
                    -- fmap1_rd_addr = f1_addr(2*oh+1,2*ow+1,f) via mux
                    state <= S_P1_FIRE;

                when S_P1_FIRE =>
                    -- fmap1_rd_data = fmap1[p11]
                    mp_p00      <= p1_p00_r;
                    mp_p01      <= p1_p01_r;
                    mp_p10      <= p1_p10_r;
                    mp_p11      <= fmap1_rd_data;
                    mp_valid_in <= '1';
                    state       <= S_P1_WAIT;

                when S_P1_WAIT =>
                    if mp_valid_out = '1' then
                        pool1(p1_wr_addr) <= mp_max_out;
                        state             <= S_P1_NEXT;
                    end if;

                when S_P1_NEXT =>
                    if f = C1_NF-1 then
                        f <= 0;
                        if ow = P1_OW-1 then
                            ow <= 0;
                            if oh = P1_OH-1 then
                                oh<=0; ow<=0; ch<=0; f<=0;
                                state <= S_C2_ADDRGEN;
                            else
                                oh    <= oh + 1;
                                state <= S_P1_ADDRGEN;
                            end if;
                        else
                            ow    <= ow + 1;
                            state <= S_P1_ADDRGEN;
                        end if;
                    else
                        f     <= f + 1;
                        state <= S_P1_ADDRGEN;
                    end if;

                -- ════════════════════════════════════════════
                -- CONV2  (shared engine, num_channels=8)
                -- All 16 filters active
                -- ════════════════════════════════════════════
                when S_C2_ADDRGEN =>
                    for kr in 0 to 2 loop
                        for kc in 0 to 2 loop
                            ce2_p1_addrs(kr*3+kc) <=
                                p1_addr(oh+kr, ow+kc, ch);
                        end loop;
                    end loop;
                    for fi in 0 to C2_NF-1 loop
                        for k in 0 to 8 loop
                            ce_ws(fi)(k) <=
                                CONV2_W(fi*C2_NC*9 + ch*9 + k);
                        end loop;
                    end loop;
                    ce_num_channels <= C2_NC;
                    state           <= S_C2_LOAD;

                when S_C2_LOAD =>
                    for k in 0 to 8 loop
                        ce_acts(k) <= pool1(ce2_p1_addrs(k));
                    end loop;
                    ce_start <= '1';
                    if ch = C2_NC-1 then
                        ch <= 0; state <= S_C2_WAIT;
                    else
                        ch <= ch + 1; state <= S_C2_ADDRGEN;
                    end if;

                when S_C2_WAIT =>
                    if ce_done = '1' then
                        f <= 0; state <= S_C2_QUANT;
                    end if;

                when S_C2_QUANT =>
                    q_acc_in      <= ce_psums(f);
                    q_bias_in     <= CONV2_B(f);
                    q_valid_in    <= '1';
                    fmap2_wr_addr <= f2_addr(oh, ow, f);
                    state         <= S_C2_QUANT_WAIT;

                when S_C2_QUANT_WAIT =>
                    -- fmap2 write handled by fmap2_we + p_fmap2_bram
                    if q_valid_out = '1' then
                        if f = C2_NF-1 then
                            state <= S_C2_NEXT;
                        else
                            f     <= f + 1;
                            state <= S_C2_QUANT;
                        end if;
                    end if;

                when S_C2_NEXT =>
                    if ow = C2_OW-1 then
                        ow <= 0;
                        if oh = C2_OH-1 then
                            oh<=0; ow<=0; f<=0;
                            state <= S_P2_ADDRGEN;
                        else
                            oh    <= oh + 1;
                            state <= S_C2_ADDRGEN;
                        end if;
                    else
                        ow    <= ow + 1;
                        state <= S_C2_ADDRGEN;
                    end if;

                -- ════════════════════════════════════════════
                -- POOL2  (sequential BRAM reads, same as Pool1)
                -- ════════════════════════════════════════════
                when S_P2_ADDRGEN =>
                    p2_wr_addr <= p2_addr(oh, ow, f);
                    state      <= S_P2_RD0;

                when S_P2_RD0 =>
                    p2_p00_r <= fmap2_rd_data;
                    state    <= S_P2_RD1;

                when S_P2_RD1 =>
                    p2_p01_r <= fmap2_rd_data;
                    state    <= S_P2_RD2;

                when S_P2_RD2 =>
                    p2_p10_r <= fmap2_rd_data;
                    state    <= S_P2_FIRE;

                when S_P2_FIRE =>
                    mp_p00      <= p2_p00_r;
                    mp_p01      <= p2_p01_r;
                    mp_p10      <= p2_p10_r;
                    mp_p11      <= fmap2_rd_data;
                    mp_valid_in <= '1';
                    state       <= S_P2_WAIT;

                when S_P2_WAIT =>
                    if mp_valid_out = '1' then
                        pool2(p2_wr_addr) <= mp_max_out;
                        state             <= S_P2_NEXT;
                    end if;

                when S_P2_NEXT =>
                    if f = C2_NF-1 then
                        f <= 0;
                        if ow = P2_OW-1 then
                            ow <= 0;
                            if oh = P2_OH-1 then
                                neuron<=0; chunk<=0;
                                state <= S_FC1_ADDR;
                            else
                                oh    <= oh + 1;
                                state <= S_P2_ADDRGEN;
                            end if;
                        else
                            ow    <= ow + 1;
                            state <= S_P2_ADDRGEN;
                        end if;
                    else
                        f     <= f + 1;
                        state <= S_P2_ADDRGEN;
                    end if;

                -- ════════════════════════════════════════════
                -- FC1: 64 neurons × 45 chunks (dot9_lut, 0 DSPs)
                -- ════════════════════════════════════════════
                when S_FC1_ADDR =>
                    base := chunk * 9;
                    for k in 0 to 8 loop
                        inp_idx := base + k;
                        if inp_idx < FC1_IN then
                            fc_acts_chunk(k) <= pool2(inp_idx);
                            fc1_addrs(k)     <=
                                neuron * FC1_IN + inp_idx;
                        else
                            fc_acts_chunk(k) <= (others => '0');
                            fc1_addrs(k)     <= 0;
                        end if;
                    end loop;
                    fc_bias_in <= FC1_B(neuron);
                    state      <= S_FC1_CHUNK;

                when S_FC1_CHUNK =>
                    for k in 0 to 8 loop
                        fc_ws_chunk(k) <= FC1_W(fc1_addrs(k));
                    end loop;
                    fc_chunk_valid <= '1';
                    if chunk = FC1_CHUNKS-1 then
                        fc_last_chunk <= '1';
                        state         <= S_FC1_WAIT;
                    else
                        chunk <= chunk + 1;
                        state <= S_FC1_ADDR;
                    end if;

                when S_FC1_WAIT =>
                    if fc_done = '1' then
                        fc1out(neuron) <= fc_result;
                        if neuron = FC1_OUT-1 then
                            neuron<=0; chunk<=0;
                            state <= S_FC2_ADDR;
                        else
                            neuron <= neuron + 1;
                            chunk  <= 0;
                            state  <= S_FC1_ADDR;
                        end if;
                    end if;

                -- ════════════════════════════════════════════
                -- FC2: 10 neurons × 8 chunks (dot9_lut, 0 DSPs)
                -- ════════════════════════════════════════════
                when S_FC2_ADDR =>
                    base := chunk * 9;
                    for k in 0 to 8 loop
                        inp_idx := base + k;
                        if inp_idx < FC2_IN then
                            fc_acts_chunk(k) <= fc1out(inp_idx);
                            fc2_addrs(k)     <=
                                neuron * FC2_IN + inp_idx;
                        else
                            fc_acts_chunk(k) <= (others => '0');
                            fc2_addrs(k)     <= 0;
                        end if;
                    end loop;
                    fc_bias_in <= FC2_B(neuron);
                    state      <= S_FC2_CHUNK;

                when S_FC2_CHUNK =>
                    for k in 0 to 8 loop
                        fc_ws_chunk(k) <= FC2_W(fc2_addrs(k));
                    end loop;
                    fc_chunk_valid <= '1';
                    if chunk = FC2_CHUNKS-1 then
                        fc_last_chunk <= '1';
                        state         <= S_FC2_WAIT;
                    else
                        chunk <= chunk + 1;
                        state <= S_FC2_ADDR;
                    end if;

                when S_FC2_WAIT =>
                    if fc_done = '1' then
                        fc2out(neuron) <= fc_result;
                        if neuron = FC2_OUT-1 then
                            state <= S_ARGMAX_INIT;
                        else
                            neuron <= neuron + 1;
                            chunk  <= 0;
                            state  <= S_FC2_ADDR;
                        end if;
                    end if;

                -- ════════════════════════════════════════════
                -- ARGMAX: sequential 10-cycle comparison
                -- ════════════════════════════════════════════
                when S_ARGMAX_INIT =>
                    max_val_r <= fc2out(0);
                    max_idx_r <= 0;
                    argmax_n  <= 1;
                    state     <= S_ARGMAX_STEP;

                when S_ARGMAX_STEP =>
                    if fc2out(argmax_n) > max_val_r then
                        max_val_r <= fc2out(argmax_n);
                        max_idx_r <= argmax_n;
                    end if;
                    if argmax_n = FC2_OUT-1 then
                        state <= S_ARGMAX_WR;
                    else
                        argmax_n <= argmax_n + 1;
                    end if;

                when S_ARGMAX_WR =>
                    pred_class <= max_idx_r;
                    state      <= S_DONE;

                when S_DONE =>
                    done_r <= '1';
                    state  <= S_IDLE;

                end case;
            end if;
        end if;
    end process;

    done <= done_r;

end architecture rtl;