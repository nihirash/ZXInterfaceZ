library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
library work;
use work.zxinterfacepkg.all;
use work.ahbpkg.all;

entity zxinterface is
  port (
    clk_i         : in std_logic;
    clk48_i       : in std_logic;
    capclk_i      : in std_logic; -- for captures
    videoclk_i    : in std_logic_vector(2 downto 0); -- 46.5Mhz/28.24Mhz/40Mhz input

    arst_i        : in std_logic;

    D_BUS_DIR_o   : out std_logic;
    D_BUS_OE_o    : out std_logic;
    CTRL_OE_o     : out std_logic;
    A_BUS_OE_o    : out std_logic;

    FORCE_ROMCS_o : out std_logic;
    FORCE_RESET_o : out std_logic;
    FORCE_INT_o   : out std_logic;
    FORCE_NMI_o   : out std_logic;
    FORCE_IORQULA_o   : out std_logic;

    -- ZX Spectrum address bus
    XA_i          : in std_logic_vector(15 downto 0);

    -- ZX Spectrum data bus
    XD_io         : inout std_logic_vector(7 downto 0);

    -- ZX Spectrum control signal sampling
    XCK_i         : in std_logic;
    XINT_i        : in std_logic;
    XMREQ_i       : in std_logic;
    XIORQ_i       : in std_logic;
    XRD_i         : in std_logic;
    XWR_i         : in std_logic;
    XM1_i         : in std_logic;
    XRFSH_i       : in std_logic;

    -- SPI
    SPI_SCK_i     : in std_logic;
    SPI_NCS_i     : in std_logic;
    --SPI_D_io      : inout std_logic_vector(3 downto 0);
    SPI_MISO_o    : out std_logic;
    SPI_MOSI_i    : in std_logic;
    -- Debug
    TP5           : out std_logic;
    --TP6           : out std_logic;
    --

    -- USB PHY
    USB_VP_i      : in std_logic;
    USB_VM_i      : in std_logic;
    USB_RCV_i     : in std_logic;
    USB_OE_o      : out std_logic;
    USB_SOFTCON_o : out std_logic;
    USB_SPEED_o   : out std_logic;
    USB_VMO_o     : out std_logic;
    USB_VPO_o     : out std_logic;
    -- USB power control
    USB_FLT_i     : in std_logic;
    USB_PWREN_o   : out std_logic;
    USB_INTN_o    : out std_logic;

    spec_int_o    : out std_logic;
    spec_nreq_o   : out std_logic; -- Spectrum data request

    -- RAM interface
    RAMD_i        : in std_logic_vector(7 downto 0);
    RAMD_o        : out std_logic_vector(7 downto 0);
    RAMD_oe_o     : out std_logic_vector(7 downto 0);
    RAMCLK_o      : out std_logic;
    RAMNCS_o      : out std_logic;

    -- video out
    hsync_o       : out std_logic;
    vsync_o       : out std_logic;
    bright_o      : out std_logic;
    grb_o         : out std_logic_vector(2 downto 0)

  );

end entity zxinterface;

architecture beh of zxinterface is

	component signaltap1 is
		port (
			acq_data_in    : in std_logic_vector(27 downto 0) := (others => 'X'); -- acq_data_in
			acq_trigger_in : in std_logic_vector(0 downto 0)  := (others => 'X'); -- acq_trigger_in
			acq_clk        : in std_logic                     := 'X'              -- clk
		);
	end component signaltap1;

	component clockmux is
		port (
			inclk1x   : in  std_logic                    := 'X';             -- inclk1x
			inclk0x   : in  std_logic                    := 'X';             -- inclk0x
			clkselect : in  std_logic                    := 'X';
			outclk    : out std_logic                                        -- outclk
		);
	end component clockmux;
--  signal data_o_s           : std_logic_vector(7 downto 0); -- Data out signal.

  signal romdata_o_s        : std_logic_vector(7 downto 0); -- ROM Data out signal.
  signal ramdata_o_s        : std_logic_vector(7 downto 0); -- RAM Data out signal.



  signal rom_enable_s       : std_logic;
  signal ram_enable_s       : std_logic;

  signal fifo_rd_s          : std_logic;
  signal fifo_2_rd_s        : std_logic;
  signal fifo_wr_s          : std_logic;
  signal fifo_full_s        : std_logic;
  signal fifo_2_full_s      : std_logic;
  signal fifo_2_empty_s     : std_logic;
  signal fifo_empty_s       : std_logic;
  signal fifo_write_s       : std_logic_vector(24 downto 0);
  signal fifo_read_s        : std_logic_vector(31 downto 0);
  signal fifo_2_read_s       : std_logic_vector(31 downto 0);
  signal fifo_size_s        : unsigned(7 downto 0);
  signal fifo_reset_s       : std_logic;

  signal m1_s               : std_logic;
  signal intr_p_s           : std_logic;
  signal bus_idle_s         : std_logic;

  signal a_s                : std_logic_vector(15 downto 0); -- Latched address
  signal d_s                : std_logic_vector(7 downto 0); -- Latched data (read). Read accesses from CPU
  signal d_unlatched_s      : std_logic_vector(7 downto 0); -- Un-latched data (read). Read accesses from CPU

  signal data_o_s           : std_logic_vector(7 downto 0); -- Data to Spectrum, multiplexed
  signal data_o_valid_s     : std_logic;
  --_vector(7 downto 0); -- Data to Spectrum, multiplexed

  signal io_rd_p_s          : std_logic; -- IO read pulse
  signal io_wr_p_s          : std_logic; -- IO write pulse
  signal mem_rd_p_s         : std_logic; -- Mem read pulse
  signal mem_wr_p_s         : std_logic; -- Mem write pulse
  signal opcode_rd_p_s      : std_logic; -- Opcode read
  signal mem_active_s       : std_logic; -- Memory access active

  signal mosi_s             : std_logic;
  signal miso_s             : std_logic;

  signal vidmem_en_s        : std_logic;
  signal vidmem_adr_s       : std_logic_vector(12 downto 0);
  signal vidmem_data_s      : std_logic_vector(7 downto 0);

  --signal fiforeset_s        : std_logic;
  signal spect_reset_s      : std_logic;
  signal spect_inten_spisck_s: std_logic;
  signal spect_capsyncen_spisck_s: std_logic;
  signal frameend_spisck_s: std_logic;
  signal spect_inten_s      : std_logic;
  --signal spect_forceromcs_spisck_s: std_logic;
  signal spect_forceromcs_s : std_logic;
  signal spect_forceromcs_bussync_s : std_logic;
  signal forceromonretn_trig_spisck_s: std_logic;
  signal forceromonretn_trig_s: std_logic;
  signal forceromcs_spisck_on_s: std_logic;
  signal forceromcs_on_s: std_logic;
  signal forceromcs_spisck_off_s: std_logic;
  signal forceromcs_off_s: std_logic;
  signal forceromonretn_r: std_logic;
  signal forcenmi_spisck_on_s: std_logic;
  signal forcenmi_spisck_off_s: std_logic;
  signal forcenmi_on_s: std_logic;
  signal forcenmi_off_s: std_logic;

  signal retn_det_s   : std_logic;
  signal spect_capsyncen_s: std_logic;
  signal framecmplt_s: std_logic;
  signal capture_clr_spisck_s:   std_logic;
  signal capture_cmp_spisck_s:   std_logic;
  signal capture_run_spisck_s:   std_logic;
  --signal capture_len_spisck_s:   std_logic_vector(CAPTURE_MEMWIDTH_BITS-1 downto 0);
  signal capture_trig_mask_spisck_s : std_logic_vector(31 downto 0);
  signal capture_trig_val_spisck_s  : std_logic_vector(31 downto 0);
  signal capmem_en_s:     std_logic;
  signal capmem_data_s:   std_logic_vector(35 downto 0);
  signal capmem_adr_s:    std_logic_vector(CAPTURE_MEMWIDTH_BITS-1 downto 0);
  signal capdin_s: std_logic_vector(27 downto 0);

  signal rom_active_s:    std_logic;

  signal rom_wc_en_s      :   std_logic;
  signal rom_wc_we_s:   std_logic;
  signal rom_wc_di_s:   std_logic_vector(7 downto 0);
  signal rom_wc_addr_s:   std_logic_vector(13 downto 0);


  signal capture_clr_s:   std_logic;
  signal capture_cmp_s:   std_logic;
  signal capture_run_s:   std_logic;
  signal capture_len_s:   std_logic_vector(CAPTURE_MEMWIDTH_BITS-1 downto 0);
  signal capture_trig_mask_s    : std_logic_vector(35-COMPRESS_BITS downto 0);
  signal capture_trig_val_s     : std_logic_vector(35-COMPRESS_BITS downto 0);
  signal capture_triggered_s: std_logic;

  signal io_enable_s:   std_logic;
  signal io_active_s:   std_logic;
  signal iodata_s   :   std_logic_vector(7 downto 0);

  signal resfifo_wr_s           : std_logic;
  signal resfifo_rd_s           : std_logic;
  signal resfifo_write_s        : std_logic_vector(7 downto 0);
  signal resfifo_reset_s        : std_logic; -- SPI clock
  signal resfifo_read_s         : std_logic_vector(7 downto 0);
  signal resfifo_full_s         : std_logic_vector(3 downto 0); -- main clock
  signal resfifo_empty_s        : std_logic;                    -- SPI clock

  signal tapfifo_reset_s        : std_logic;
  signal tapfifo_reset_spisck_s : std_logic;
  signal tapfifo_wr_s           : std_logic;
  signal tapfifo_write_s        : std_logic_vector(7 downto 0);
  signal tapfifo_full_s         : std_logic;
  signal tapfifo_used_s         : std_logic_vector(9 downto 0);
  signal tap_enable_spisck_s    : std_logic;
  signal tap_enable_s           : std_logic;
  signal tap_audio_s            : std_logic;


  signal cmdfifo_wr_s           : std_logic;
  signal cmdfifo_rd_spiclk_s    : std_logic;
  signal cmdfifo_write_s        : std_logic_vector(7 downto 0);
  --signal cmdfifo_reset_s        : std_logic;
  signal cmdfifo_read_spiclk_s  : std_logic_vector(7 downto 0);
  signal cmdfifo_full_s         : std_logic;
  signal cmdfifo_empty_spiclk_s : std_logic;
  signal cmdfifo_empty_s        : std_logic;
  signal cmdfifo_reset_spiclk_s : std_logic;
  signal cmdfifo_intack_spisck_s: std_logic;
  signal cmdfifo_intack_s       : std_logic; -- intack in CLK domain

  --signal d_io_read_p_s          : std_logic;
  --signal d_io_write_p_s         : std_logic;
  signal port_fe_s              : std_logic_vector(5 downto 0);

  signal border_seq_s           : std_logic_vector(2 downto 0);
  signal border_off_s           : natural;

  signal start_delay_s          : std_logic_vector(7 downto 0);

  signal spec_nreq_r            : std_logic;
  constant SPEC_NREC_DELAY_MAX  : natural := 31;

  signal spec_nreq_delay_r      : natural range 0 to SPEC_NREC_DELAY_MAX := SPEC_NREC_DELAY_MAX;

  signal pixclk_s               : std_logic;
  signal vidmode_s              : std_logic_vector(1 downto 0);
  signal pixrst_s               : std_logic := '1';

  signal pc_s                   : std_logic_vector(15 downto 0);
  signal pc_valid_s             : std_logic;

  signal pc_r                   : std_logic_vector(15 downto 0);
  signal pc_spisck_r            : std_logic_vector(15 downto 0);

  signal vidmode_resync_s       : std_logic_vector(1 downto 0);
  signal nmi_access_s           : std_logic;
  signal mem_rd_p_dly_s         : std_logic;
  signal io_rd_p_dly_s          : std_logic;

  signal nmi_r                  : std_logic;
  signal in_nmi_rom_r           : std_logic;
  signal ulahack_s              : std_logic;
  signal ulahack_spisck_s       : std_logic;

  signal psram_ahb_m2s          : AHB_M2S;
  signal psram_ahb_s2m          : AHB_S2M;

  signal ram_addr_s             : std_logic_vector(23 downto 0);
  signal ram_dat_wr_s           : std_logic_vector(7 downto 0);
  signal ram_dat_rd_s           : std_logic_vector(7 downto 0);
  signal ram_wr_s               : std_logic;
  signal ram_rd_s               : std_logic;
  signal ram_ack_s              : std_logic;

  signal ahb_spi_m2s            : AHB_M2S;
  signal ahb_spi_s2m            : AHB_S2M;

  signal ahb_spect_m2s          : AHB_M2S;
  signal ahb_spect_s2m          : AHB_S2M;

  signal ahb_null_m2s           : AHB_M2S;
  signal ahb_null_s2m           : AHB_S2M;

  signal extram_addr_s          : std_logic_vector(31 downto 0);
  signal extram_dat_s           : std_logic_vector(31 downto 0);
  signal extram_dat_write_s     : std_logic_vector(31 downto 0);
  signal extram_req_s           : std_logic;
  signal extram_we_s            : std_logic;
  signal extram_valid_s         : std_logic;

  signal rst48_s                : std_logic;

  signal usb_rd_s               : std_logic;
  signal usb_wr_s               : std_logic;
  signal usb_int_s              : std_logic;
  signal usb_int_async_s        : std_logic;
  signal usb_addr_s             : std_logic_vector(10 downto 0);
  signal usb_wdat_s             : std_logic_vector(7 downto 0);
  signal usb_rdat_s             : std_logic_vector(7 downto 0);

  signal keyb_trigger_s         : std_logic;

begin

  rst48_inst: entity work.rstgen
    port map (
      arst_i  => arst_i,
      clk_i   => clk48_i,
      rst_o   => rst48_s
    );



  clockmux_inst : component clockmux
		port map (
			--inclk3x   => '0',--videoclk_i(2),
			--inclk2x   => '0',--videoclk_i(0),
			inclk1x   => videoclk_i(0),
			inclk0x   => videoclk_i(1),
			clkselect => vidmode_resync_s(0),
			outclk    => pixclk_s
    );

  process(pixclk_s, arst_i)
  begin
    if arst_i='1' then
      pixrst_s <= '1';
    elsif rising_edge(pixclk_s) then
      pixrst_s <= '0';
    end if;
  end process;

  vmsync_inst: entity work.syncv
    generic map (
      WIDTH => 2,
      RESET => '0'
    ) port map (
      clk_i   => pixclk_s,
      arst_i  => arst_i,
      din_i   => vidmode_s,
      dout_o  => vidmode_resync_s
    );

  -- VGA END

  businterface_inst: entity work.businterface
    port map (
      clk_i         => clk_i,
      arst_i        => arst_i,
      XA_i          => XA_i,
      XD_io         => XD_io,
      XCK_i         => XCK_i,
      XINT_i        => XINT_i,
      XMREQ_i       => XMREQ_i,
      XIORQ_i       => XIORQ_i,
      XRD_i         => XRD_i,
      XWR_i         => XWR_i,
      XM1_i         => XM1_i,
      XRFSH_i       => XRFSH_i,

      D_BUS_DIR_o   => D_BUS_DIR_o,
      D_BUS_OE_o    => D_BUS_OE_o,
      CTRL_OE_o     => CTRL_OE_o,
      A_BUS_OE_o    => A_BUS_OE_o,
  
      d_i           => data_o_s,
      oe_i          => data_o_valid_s,
  
      d_o           => d_s,
      d_unlatched_o => d_unlatched_s,
      a_o           => a_s,
  
      io_rd_p_o     => io_rd_p_s,
      io_rd_p_dly_o => io_rd_p_dly_s,
      io_wr_p_o     => io_wr_p_s,
      io_active_o   => io_active_s,
      mem_rd_p_o    => mem_rd_p_s,
      mem_rd_p_dly_o=> mem_rd_p_dly_s, -- Used for opcode capture
      mem_wr_p_o    => mem_wr_p_s,
      mem_active_o  => mem_active_s,
      opcode_rd_p_o => opcode_rd_p_s,
      intr_p_o      => intr_p_s,
      bus_idle_o    => bus_idle_s,
      m1_o          => m1_s
  );


  r: if ROM_ENABLED generate
  rom: entity work.generic_dp_ram
    generic map (
      ADDRESS_BITS => 14, -- 16Kb
      DATA_BITS => 8
    )
    port map (
      clka    => clk_i,
      ena     => rom_active_s,
      wea     => '0',
      dia     => "00000000",
      doa     => romdata_o_s,
      addra   => a_s(13 downto 0),

      clkb    => SPI_SCK_i,
      enb     => rom_wc_en_s,
      web     => rom_wc_we_s,
      dib     => rom_wc_di_s,
      dob     => open,
      addrb   => rom_wc_addr_s
    );
  end generate;

  nr: if not ROM_ENABLED generate
    romdata_o_s <= (others => '0');
  end generate;

  data_o_s <= romdata_o_s when rom_enable_s='1' else
      iodata_s when io_enable_s='1' else (others => '0');

  rom_enable_s  <= mem_active_s and not (a_s(15) or a_s(14));

  io_inst: entity work.interfacez_io
    port map (
      clk_i           => clk_i,
      rst_i           => arst_i,

      wrp_i           => io_wr_p_s,
      rdp_i           => io_rd_p_s,
      rdp_dly_i       => io_rd_p_dly_s,
      active_i        => io_active_s,
      adr_i           => a_s,
      dat_i           => d_unlatched_s,
      dat_o           => iodata_s,
      enable_o        => io_enable_s,
      forceiorqula_o  => FORCE_IORQULA_o,
      keyb_trigger_o  => keyb_trigger_s,
      audio_i         => tap_audio_s,

      port_fe_o       => port_fe_s,
      ulahack_i       => ulahack_s,

      resfifo_rd_o    => resfifo_rd_s,
      resfifo_read_i  => resfifo_read_s,
      resfifo_empty_i => resfifo_empty_s,

      cmdfifo_wr_o    => cmdfifo_wr_s,
      cmdfifo_write_o => cmdfifo_write_s,
      cmdfifo_full_i  => cmdfifo_full_s ,

      ram_addr_o      => ram_addr_s,
      ram_dat_o       => ram_dat_wr_s,
      ram_dat_i       => ram_dat_rd_s,
      ram_wr_o        => ram_wr_s,
      ram_rd_o        => ram_rd_s,
      ram_ack_i       => ram_ack_s
  );


  start_delay_s <= x"02";

  border_capture_inst: entity work.border_capture
    port map (
      clk_i         => clk_i,
      arst_i        => arst_i,

      border_ear_i  => port_fe_s(3 downto 0),
      start_delay_i => start_delay_s,
      seq_o         => border_seq_s,
      off_o         => border_off_s,
      intr_i        => '0'--intr_p_s
    );

  -- RAM write access captures

  ramfifo_inst: entity work.gh_fifo_async_sr_wf
  generic map (
    add_width   => 8, -- 256 entries
    data_width   => 25
  )
  port map (
    clk_WR      => clk_i,
    clk_RD      => clk_i,--SPI_SCK_i, -- TBD
    rst         => arst_i,
    srst        => arst_i,
    wr          => fifo_wr_s,
    rd          => fifo_rd_s,
    D           => fifo_write_s,
    Q           => fifo_read_s(24 downto 0),
    full        => fifo_full_s,
    empty       => fifo_empty_s
  );

  ramfifo2_inst: entity work.gh_fifo_async_sr_wf
  generic map (
    add_width   => 8, -- 256 entries
    data_width   => 25
  )
  port map (
    clk_WR      => clk_i,
    clk_RD      => SPI_SCK_i, 
    rst         => arst_i,
    srst        => fifo_reset_s,
    wr          => fifo_wr_s,
    rd          => fifo_2_rd_s,
    D           => fifo_write_s,
    Q           => fifo_2_read_s(24 downto 0),
    full        => fifo_2_full_s,
    empty       => fifo_2_empty_s
  );

  fifo_read_s(31 downto 25) <= (others => '0');
  fifo_2_read_s(31 downto 25) <= (others => '0');

  fifo_wr_s     <= mem_wr_p_s OR io_wr_p_s;
  fifo_write_s  <= io_wr_p_s & d_s & a_s;

  -- ROM is active on access if FORCE romcs is '1'

  -- TODO: we should have more then one ROM here.

  rom_active_s    <= rom_enable_s and spect_forceromcs_bussync_s;
  --io_active_s     <= io_enable_s;-- and NOT XRD_sync_s;

  data_o_valid_s  <= rom_active_s or io_enable_s;--io_active_s;

  --
  -- Resource FIFO. This FIFO is between ESP and spectrum. ESP writes, Spectrum reads.
  --
  resourcefifo_inst: entity work.resource_fifo
  port map (
    wclk_i      => SPI_SCK_i,
    rclk_i      => clk_i,
    aclr_i      => resfifo_reset_s,
    wen_i       => resfifo_wr_s,
    ren_i       => resfifo_rd_s,
    wdata_i     => resfifo_write_s,
    rdata_o     => resfifo_read_s,
    wfull_o     => resfifo_full_s(0),
    wqfull_o    => resfifo_full_s(1),
    whfull_o    => resfifo_full_s(2),
    wqqqfull_o  => resfifo_full_s(3),
    rempty_o    => resfifo_empty_s
  );

  --
  -- Command FIFO. This FIFO is between Spectrum and ESP. Spectrum writes, ESP32 reads.
  --
  cmdfifo_inst: entity work.command_fifo
  port map (
    wclk_i     => clk_i,
    rclk_i      => SPI_SCK_i,
    arst_i      => arst_i,
    wr_i        => cmdfifo_wr_s,
    rd_i        => cmdfifo_rd_spiclk_s,
    rreset_i    => cmdfifo_reset_spiclk_s,
    wD_i        => cmdfifo_write_s,
    rQ_o        => cmdfifo_read_spiclk_s,
    wfull_o     => cmdfifo_full_s,
    wempty_o    => cmdfifo_empty_s,
    rempty_o    => cmdfifo_empty_spiclk_s
  );




  qspi_inst: entity work.spi_interface
  port map (
    SCK_i         => SPI_SCK_i,
    CSN_i         => SPI_NCS_i,
    arst_i        => arst_i,
    --D_io          => spi_data_s,
    MOSI_i        => mosi_s,
    MISO_o        => miso_s,

    pc_i          => pc_spisck_r,

    fifo_empty_i  => fifo_2_empty_s,
    fifo_rd_o     => fifo_2_rd_s,
    fifo_data_i   => fifo_2_read_s,

    vidmem_en_o   => vidmem_en_s,
    vidmem_adr_o  => vidmem_adr_s,
    vidmem_data_i => vidmem_data_s,

    capmem_en_o     => capmem_en_s,
    capmem_adr_o    => capmem_adr_s,
    capmem_data_i   => capmem_data_s,

    -- ROM connections
    rom_en_o        => rom_wc_en_s,
    rom_we_o        => rom_wc_we_s,
    rom_di_o        => rom_wc_di_s,
    rom_addr_o      => rom_wc_addr_s,


    capture_clr_o   => capture_clr_spisck_s,
    capture_run_o   => capture_run_spisck_s,
    capture_len_i   => capture_len_s,       -- This is NOT sync!!
    capture_trig_i  => capture_triggered_s, -- This is NOT sync!!
    capture_cmp_o   => capture_cmp_spisck_s,

    capture_trig_mask_o => capture_trig_mask_spisck_s,
    capture_trig_val_o  => capture_trig_val_spisck_s,

    vidmode_o     => vidmode_s,
    ulahack_o     => ulahack_spisck_s,

    rstfifo_o     => fifo_reset_s,
    rstspect_o    => spect_reset_s,
    intenable_o   => spect_inten_spisck_s,
    capsyncen_o   => spect_capsyncen_spisck_s,
    frameend_o    => frameend_spisck_s,
    --forceromcs_o  => spect_forceromcs_spisck_s,

    resfifo_reset_o => resfifo_reset_s,
    resfifo_wr_o    => resfifo_wr_s,
    resfifo_write_o => resfifo_write_s,
    resfifo_full_i  => resfifo_full_s,
    -- TAP fifo/control
    tapfifo_reset_o   => tapfifo_reset_spisck_s,
    tapfifo_wr_o      => tapfifo_wr_s,
    tapfifo_write_o   => tapfifo_write_s,
    tapfifo_full_i    => tapfifo_full_s,
    tapfifo_used_i    => tapfifo_used_s,
    tap_enable_o      => tap_enable_spisck_s,

    -- Command FIFO

    cmdfifo_reset_o       => cmdfifo_reset_spiclk_s,
    cmdfifo_rd_o          => cmdfifo_rd_spiclk_s,
    cmdfifo_read_i        => cmdfifo_read_spiclk_s,
    cmdfifo_empty_i       => cmdfifo_empty_spiclk_s,
    cmdfifo_intack_o      => cmdfifo_intack_spisck_s,


    extram_addr_o         => extram_addr_s,
    extram_dat_i          => extram_dat_s,
    extram_dat_o          => extram_dat_write_s,
    extram_req_o          => extram_req_s,
    extram_we_o           => extram_we_s,
    extram_valid_i        => extram_valid_s,

    forceromonretn_trig_o => forceromonretn_trig_spisck_s,
    forceromcs_trig_on_o  => forceromcs_spisck_on_s,
    forceromcs_trig_off_o => forceromcs_spisck_off_s,
    forcenmi_trig_on_o    => forcenmi_spisck_on_s,
    forcenmi_trig_off_o    => forcenmi_spisck_off_s,
    -- USB
    usb_rd_o              => usb_rd_s,
    usb_wr_o              => usb_wr_s,
    usb_addr_o            => usb_addr_s,
    usb_dat_i             => usb_rdat_s,
    usb_dat_o             => usb_wdat_s,
    usb_int_i             => usb_int_s
  );

  fmretn: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => forceromonretn_trig_spisck_s,
    pulse_o   => forceromonretn_trig_s
  );

  fmromcson: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => forceromcs_spisck_on_s,
    pulse_o   => forceromcs_on_s
  );

  fmromcsoff: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => forceromcs_spisck_off_s,
    pulse_o   => forceromcs_off_s
  );

  fmnmion: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => forcenmi_spisck_on_s,
    pulse_o   => forcenmi_on_s
  );

  fmnmioff: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => forcenmi_spisck_off_s,
    pulse_o   => forcenmi_off_s
  );

  specinten_sync: entity work.sync generic map (RESET => '0')
      port map ( clk_i => clk_i, arst_i => arst_i, din_i => spect_inten_spisck_s, dout_o => spect_inten_s );

  capsync_sync: entity work.sync generic map (RESET => '0')
      port map ( clk_i => clk_i, arst_i => arst_i, din_i => spect_capsyncen_spisck_s, dout_o => spect_capsyncen_s );

  ulahack_sync: entity work.sync generic map (RESET => '0')
      port map ( clk_i => clk_i, arst_i => arst_i, din_i => ulahack_spisck_s, dout_o => ulahack_s );

  tapen_sync: entity work.sync generic map (RESET => '0')
      port map ( clk_i => clk_i, arst_i => arst_i, din_i => tap_enable_spisck_s, dout_o => tap_enable_s );

  tapreset_sync: entity work.sync generic map (RESET => '0')
      port map ( clk_i => clk_i, arst_i => arst_i, din_i => tapfifo_reset_spisck_s, dout_o => tapfifo_reset_s );

  intack_sync: entity work.async_pulse2
      port map (
        clki_i => SPI_SCK_i,
        clko_i => clk_i,
        arst_i => arst_i,
        pulse_i => cmdfifo_intack_spisck_s,
        pulse_o => cmdfifo_intack_s
      );

  -- Interrupt generation for command FIFO
  process(clk_i, arst_i)
  begin
    if arst_i='1' then
      spec_nreq_r   <= '1';
      spec_nreq_delay_r <= SPEC_NREC_DELAY_MAX;

    elsif rising_edge(clk_i) then
      if (spec_nreq_delay_r/=0) then
        spec_nreq_delay_r <= spec_nreq_delay_r - 1;
      end if;
      -- TODO TODO: fix this once we have a fifo with more than 1 element.
      --
      if cmdfifo_full_s='1' and spec_nreq_delay_r=0 then   -- !! Empty is generated by read (SPI)
        spec_nreq_r <= '0';
      elsif cmdfifo_intack_s='1' then
        spec_nreq_r <= '1';
        spec_nreq_delay_r <= SPEC_NREC_DELAY_MAX;
      end if;
    end if;
  end process;

  -- TAP player.

  tap_engine_inst: entity work.tap_engine
  port map (
    clk_i     => clk_i,
    arst_i    => arst_i,

    enable_i  => tap_enable_s,
    restart_i => tapfifo_reset_s,

    fclk_i    => SPI_SCK_i,
    fdata_i   => tapfifo_write_s,
    fwr_i     => tapfifo_wr_s,
    ffull_o   => tapfifo_full_s,
    fused_o   => tapfifo_used_s,

    audio_o   => tap_audio_s
  );


  process(clk_i, arst_i)
  begin
    if arst_i='1' then
      spect_forceromcs_s  <='0';
      forceromonretn_r    <= '0';
    elsif rising_edge(clk_i) then
      if forceromonretn_trig_s='1' then
        forceromonretn_r <= '1';
      end if;
      if forceromcs_on_s='1' then
        spect_forceromcs_s<='1';
      elsif forceromcs_off_s='1' or (forceromonretn_r='1' and retn_det_s='1') then
        spect_forceromcs_s<='0';
        if (forceromonretn_r='1' and retn_det_s='1') then
          forceromonretn_r<='0';
        end if;
      end if;
    end if;
  end process;

  process(clk_i, arst_i)
  begin
    if arst_i='1' then
      nmi_r <= '0';
      in_nmi_rom_r <= '0';
    elsif rising_edge(clk_i) then

      if forcenmi_off_s='1' then
        nmi_r <= '0';
        in_nmi_rom_r <='0';
      elsif (in_nmi_rom_r='0') and (forcenmi_on_s='1' or (keyb_trigger_s='1' and spect_forceromcs_bussync_s='0')) then
        nmi_r <= '1';
        -- Force ROMCS
      end if;

      if nmi_access_s='1' then -- Entered NMI.
        in_nmi_rom_r <= nmi_r;
        nmi_r <= '0';
      end if;

      if retn_det_s='1' then -- If we detect a RETN, leave ROM.
        in_nmi_rom_r <= '0';
      end if;
    end if;
  end process;

  insndet_inst: entity work.insn_detector
    port map (
      clk_i       => clk_i,
      arst_i      => arst_i,
      valid_i     => mem_rd_p_dly_s,
      a_i         => a_s,
      d_i         => d_unlatched_s,
      m1_i        => m1_s,
      pc_o        => pc_s,
      pc_valid_o  => pc_valid_s,
      retn_det_o  => retn_det_s,
      nmi_access_o=> nmi_access_s
    );

  process(clk_i, arst_i)
  begin
    if arst_i='1' then
    elsif rising_edge(clk_i) then
      if pc_valid_s='1' then
        pc_r <= pc_s;
      end if;
    end if;
  end process;

  pc_syncv: entity work.syncv generic map (RESET => '0', WIDTH => 16)
    port map ( clk_i => SPI_SCK_i, arst_i => arst_i, din_i => pc_r, dout_o => pc_spisck_r );

  sc: if SCREENCAP_ENABLED generate

  fci: entity work.async_pulse port map (
    clk_i     => clk_i,
    rst_i     => arst_i,
    pulse_i   => frameend_spisck_s,
    pulse_o   => framecmplt_s
  );

  screencap_inst: entity work.screencap
    port map (
      clk_i         => clk_i,
      rst_i         => arst_i,

      fifo_empty_i  => fifo_empty_s,
      fifo_rd_o     => fifo_rd_s,
      fifo_data_i   => fifo_read_s,

      vidmem_clk_i  => SPI_SCK_i,
      vidmem_en_i   => vidmem_en_s,
      vidmem_adr_i  => vidmem_adr_s,
      vidmem_data_o => vidmem_data_s,

      capsyncen_i   => spect_capsyncen_s,
      intr_i        => intr_p_s,
      framecmplt_i  => framecmplt_s,
      --
      vidmode_i     => vidmode_resync_s,
      border_i      => port_fe_s(2 downto 0),
      pixclk_i      => pixclk_s,
      pixrst_i      => pixrst_s,

      hsync_o       => hsync_o,
      vsync_o       => vsync_o,
      bright_o      => bright_o,
      grb_o         => grb_o
    );

  end generate;

  nsc: if not SCREENCAP_ENABLED generate
    fifo_rd_s       <= '0';
    vidmem_data_s   <= (others =>'0');
  end generate;

  --
  -- Do NOT allow changes to ROMCS while bus is busy, wait for bus idle
  --
  process(clk_i, arst_i)
  begin
    if arst_i='1' then
      spect_forceromcs_bussync_s <= '0';
    elsif rising_edge(clk_i) then
      if bus_idle_s='1' then
        spect_forceromcs_bussync_s <= spect_forceromcs_s or in_nmi_rom_r;  -- Also force ROM on NMI.
      end if;
    end if;
  end process;

  psram_inst: entity work.psram
    port map (
      clk_i   => clk_i,
      arst_i  => arst_i,

      ahb_i   => psram_ahb_m2s,
      ahb_o   => psram_ahb_s2m,

      cs_n_o  => RAMNCS_o,
      clk_o   => RAMCLK_o,
      d_o     => RAMD_o(3 downto 0),
      oe_o    => RAMD_oe_o(3 downto 0),
      d_i     => RAMD_i(3 downto 0)
    );

  ramadapt_inst: entity work.ram_adaptor
    port map (
      clk_i           => clk_i,
      arst_i          => arst_i,
      ahb_i           => ahb_spect_s2m,
      ahb_o           => ahb_spect_m2s,

      ram_addr_i      => ram_addr_s,
      ram_dat_o       => ram_dat_rd_s,
      ram_dat_i       => ram_dat_wr_s,
      ram_wr_i        => ram_wr_s,
      ram_rd_i        => ram_rd_s,
      ram_ack_o       => ram_ack_s
  );


  arb_inst: entity work.ahb_arb
    port map (
      CLK         => clk_i,
      RST         => arst_i,

      HMAST0_I    => ahb_spect_m2s,
      HMAST0_O    => ahb_spect_s2m,

      HMAST1_I    => ahb_spi_m2s,
      HMAST1_O    => ahb_spi_s2m,

      HMAST2_I    => ahb_null_m2s,
      HMAST2_O    => ahb_null_s2m,

      HMAST3_I    => ahb_null_m2s,
      HMAST3_O    => ahb_null_s2m,

      HSLAV_I     => psram_ahb_s2m,
      HSLAV_O     => psram_ahb_m2s
    );


  ahbr_inst: entity work.ahbreq_sync
  port map (
    mclk_i    => clk_i,
    marst_i   => arst_i,

    sclk_i    => SPI_SCK_i,
    sarst_i   => '0', -- TODO

    addr_i    => extram_addr_s,
    trans_i   => extram_req_s,
    we_i      => extram_we_s,
    valid_o   => extram_valid_s,
    data_o    => extram_dat_s,
    data_i    => extram_dat_write_s,

    m_i       => ahb_spi_s2m,
    m_o       => ahb_spi_m2s
  );

  usb_inst: ENTITY work.usbhostctrl
  PORT map (
    usbclk_i      => clk48_i,
    ausbrst_i     => rst48_s,

    clk_i         => SPI_SCK_i,
    arst_i        => arst_i,

    rd_i          => usb_rd_s,
    wr_i          => usb_wr_s,
    addr_i        => usb_addr_s,
    dat_i         => usb_wdat_s,
    dat_o         => usb_rdat_s,
    int_o         => usb_int_s,
    int_async_o   => usb_int_async_s,
    -- Interface to transceiver
    softcon_o     => USB_SOFTCON_o,
    noe_o         => USB_OE_o,
    speed_o       => USB_SPEED_o,
    vpo_o         => USB_VPO_o,
    vmo_o         => USB_VMO_o,

    rcv_i         => USB_RCV_i,
    vp_i          => USB_VP_i,
    vm_i          => USB_VM_i,
    pwren_o       => USB_PWREN_o,
    pwrflt_i      => USB_FLT_i
  );

  mosi_s          <= SPI_MOSI_i;
  SPI_MISO_o      <= miso_s;

  FORCE_ROMCS_o <= spect_forceromcs_bussync_s;
  FORCE_RESET_o <= spect_reset_s;
  FORCE_INT_o   <= '0';
  FORCE_NMI_o   <= nmi_r;
  --FORCE_IORQULA_o <= '0';

  --TP5 <= clk_i;
  TP5 <= tap_audio_s;

  spec_int_o <= '1' when spect_inten_s='0' else XINT_i;--sync_s; TBD
  spec_nreq_o <= spec_nreq_r;

  ahb_null_m2s <= C_AHB_NULL_M2S;
  USB_INTN_o <= not usb_int_async_s;

end beh;

