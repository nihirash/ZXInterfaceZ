library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
library work;
use work.zxinterfacepkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity interfacez_io is
  port  (
    clk_i     : in std_logic;
    rst_i     : in std_logic;

    --ioreq_i   : in std_logic;
    --rd_i      : in std_logic;
    wrp_i     : in std_logic;
    rdp_i     : in std_logic;
    rdp_dly_i : in std_logic;
    active_i  : in std_logic;
    ulahack_i : in std_logic;

    adr_i     : in std_logic_vector(15 downto 0);
    dat_i     : in std_logic_vector(7 downto 0);
    dat_o     : out std_logic_vector(7 downto 0);
    enable_o  : out std_logic;

    port_fe_o : out std_logic_vector(5 downto 0);
    audio_i   : in std_logic;

    forceiorqula_o  : out std_logic;
    keyb_trigger_o  : out std_logic;

    -- Resource request control
    spec_nreq_o : out std_logic; -- Spectrum data request.

    -- Resource FIFO connections

    resfifo_rd_o           : out std_logic;
    resfifo_read_i         : in std_logic_vector(7 downto 0);
    resfifo_empty_i        : in std_logic;
    -- Command FIFO connection

    cmdfifo_wr_o           : out std_logic;
    cmdfifo_write_o        : out std_logic_vector(7 downto 0);
    cmdfifo_full_i         : in std_logic;
    -- Ram
    ram_addr_o             : out std_logic_vector(23 downto 0);
    ram_dat_o              : out std_logic_vector(7 downto 0);
    ram_dat_i              : in std_logic_vector(7 downto 0);
    ram_wr_o               : out std_logic;
    ram_rd_o               : out std_logic;
    ram_ack_i              : in std_logic
  );

end entity interfacez_io;

architecture beh of interfacez_io is

  signal port_fe_r        : std_logic_vector(5 downto 0);
  signal addr_match_s     : std_logic;
  signal enable_s         : std_logic;
  signal dataread_r       : std_logic_vector(7 downto 0);
  signal testdata_r       : unsigned(7 downto 0);
  signal d_write_r        : std_logic_vector(7 downto 0);
  signal cmdfifo_wr_r     : std_logic;
  signal uladata_r        : std_logic_vector(7 downto 0);
  signal forceoutput_s    : std_logic;
  signal ram_wr_r         : std_logic;
  signal ram_rd_r         : std_logic;
  signal ram_addr_r       : unsigned(23 downto 0);

  signal scratch0_r       : std_logic_vector(7 downto 0);
  signal scratch1_r       : std_logic_vector(7 downto 0);

begin

  -- Address match for reads
  process (adr_i)
  begin
    addr_match_s<='0';
    if adr_i(0)='1' then
      case adr_i(7 downto 0) is
        when x"03" | x"05" | x"07" | x"0B" | x"0D" | x"17" | x"1F"=>
          addr_match_s<='1';
        when others =>
		end case;
     end if;
  end process;

	enable_s  <=  active_i and addr_match_s; -- Report all IOs

  process(clk_i, rst_i)
  begin
    if rst_i='1' then

      port_fe_r     <= (others => '0');
      dataread_r    <= (others => 'X');
      resfifo_rd_o  <= '0';
      testdata_r    <= (others => '0');
      cmdfifo_wr_r  <= '0';
      ram_wr_r      <= '0';
      ram_rd_r      <= '0';

    elsif rising_edge(clk_i) then

      resfifo_rd_o <= '0';
      cmdfifo_wr_r <= '0';

      if wrp_i='1' and adr_i(7 downto 0)=x"FE" then -- ULA write
        port_fe_r <= dat_i(5 downto 0);
        -- synthesis translate_off
        report "SET BORDER: "&hstr(dat_i);
        -- synthesis translate_on
      end if;

      -- WRITE REQUEST from Spectrum.

      if wrp_i='1' then
        case adr_i(7 downto 0) is
          when x"03" =>
            scratch0_r <= dat_i;
          when x"05" =>
            scratch1_r <= dat_i;
          when x"0B" => -- FIFO status/control
          when x"09" => -- Command FIFO write.
            d_write_r <= dat_i;
            if cmdfifo_full_i='0' then
              cmdfifo_wr_r    <= '1';
            end if;
          when x"11" =>
            ram_addr_r(7 downto 0) <= unsigned(dat_i);
          when x"13" =>
            ram_addr_r(15 downto 8) <= unsigned(dat_i);

          when x"15" =>
            ram_addr_r(23 downto 16) <= unsigned(dat_i);

          when x"17" => -- RAM write.
            d_write_r     <= dat_i;
            ram_wr_r      <= '1';


          when others =>
        end case;

      end if;

      if rdp_i='1' then
        case adr_i(7 downto 0) is

          when x"03" =>
            dataread_r <= scratch0_r;

          when x"05" =>
            dataread_r <= scratch1_r;

          when x"07" => -- Command FIFO status read
            dataread_r <= "0000000" & cmdfifo_full_i;

          when x"0B" => -- Resource FIFO status read
            dataread_r <= "0000000" & resfifo_empty_i;

          when x"0D" => -- FIFO read
            dataread_r <= resfifo_read_i;
            -- Pop data on next clock cycle
            resfifo_rd_o <= '1';
            testdata_r <= testdata_r + 1;

          when x"17" => -- RAM read
            ram_rd_r <= '1';

          when x"1F" => -- Joy
            dataread_r <= x"00";

          when others =>
            --dataread_r <= (others => '1');
        end case;

      end if;

      if ram_ack_i='1' then
        if ram_rd_r='1' then
          -- data
          dataread_r <= ram_dat_i;
        end if;
        ram_wr_r <= '0';
        ram_rd_r <= '0';
        ram_addr_r <= ram_addr_r + 1;
      end if;

    end if;
  end process;

  process(clk_i, rst_i)
  begin
    if rst_i='1' then
      forceiorqula_o  <= '0';
      forceoutput_s <= '0';
      keyb_trigger_o <= '0';
    --
    elsif rising_edge(clk_i) then
      keyb_trigger_o <= '0';
      if rdp_dly_i='1' and ulahack_i='1' and adr_i(7 downto 0)=x"FE" then
        -- ULA read. Capture ULA data
        uladata_r <= dat_i(7) & audio_i & dat_i(5 downto 0);
        -- Start delay. Force IRQULA immediatly
        forceiorqula_o <= '1';
        forceoutput_s <= '1';
      end if;
      if active_i='0' or ulahack_i='0' then
        forceiorqula_o <= '0';
        forceoutput_s <='0';
      end if;

      if rdp_dly_i='1' and adr_i=x"7FFE" then
        if dat_i(4 downto 0)="11100" then
          keyb_trigger_o <= '1';
        end if;
      end if;
    end if;
  end process;

  dat_o           <= dataread_r when forceoutput_s='0' else uladata_r;
  port_fe_o       <= port_fe_r;
  enable_o        <= enable_s or forceoutput_s;
  cmdfifo_write_o <= d_write_r;
  ram_dat_o       <= d_write_r;
  cmdfifo_wr_o    <= cmdfifo_wr_r;
  ram_wr_o        <= ram_wr_r;
  ram_rd_o        <= ram_rd_r;
  ram_addr_o      <= std_logic_vector(ram_addr_r);
 
end beh;
