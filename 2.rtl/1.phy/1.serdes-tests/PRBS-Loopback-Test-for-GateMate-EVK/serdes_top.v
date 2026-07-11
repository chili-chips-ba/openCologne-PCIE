// Glavni modul za testiranje SERDES komunikacije
module serdes_top (
    input  wire       clk_10m,            // Prima glavni takt od 10 MHz sa ploče
    input  wire       rst_n,              // Prima signal sa tipke SW3 (aktivno nisko)
    output wire [7:0] led                 // Kontroliše 8 LED indikatora na ploči
);


// INDIKATOR RADA PLOČE 

reg [23:0] hb_cnt = 24'd0;                // Inicijalizuje brojač takta
always @(posedge clk_10m) hb_cnt <= hb_cnt + 1; // Uvećava brojač na svaku uzlaznu ivicu takta


// LOGIKA TIPKE (DEBOUNCE I LATCH)

reg [15:0] btn_cnt = 16'd0;              
reg        started = 1'b0;                

always @(posedge clk_10m) begin
    if (!rst_n) begin                    
        if (btn_cnt == 16'hFFFF) started <= 1'b1; 
        else                     btn_cnt <= btn_cnt + 1; 
    end else begin
        btn_cnt <= 16'd0;                
    end
end


// GENERISANJE RESETA ZA SERDES

reg serdes_rst = 1'b1;                    // Inicijalizuje reset signal u aktivno stanje
always @(posedge clk_10m) serdes_rst <= ~started; // Otpušta reset kada se sistem inicijalizuje


// FSM ZA INICIJALIZACIJU SERDES PLL-A

reg        reg_we   = 0;                  // Oznaka za dozvolu upisa
reg        reg_en   = 0;                  // Oznaka za aktivaciju registra
reg [7:0]  reg_addr = 8'h00;              // Adresa registra u SERDES-u
reg [15:0] reg_data = 16'h0000;           // Podatak koji se upisuje
wire       reg_rdy;                       // Signal spremnosti registra

reg [2:0] fsm    = 3'd0;                  // Stanje konačnog automata
reg [1:0] idx    = 2'd0;                  // Indeks trenutnog registra
reg [5:0] wcnt   = 6'd0;                  // Brojač za vremensko kašnjenje (delay)

always @(posedge clk_10m) begin
    case (fsm)
        3'd0: begin                       // Nulto stanje: čeka pokretanje
            reg_we <= 0; reg_en <= 0; idx <= 0; // Postavlja signale upisa na nulu
            if (started) fsm <= 3'd1;     // Prelazi u stanje za upis nakon klika
        end
        3'd1: begin                       // Prvo stanje: priprema adrese i podatke
            case (idx)
                2'd0: begin reg_addr <= 8'h51; reg_data <= 16'h16FA; end // Postavlja parametre za PLL
                2'd1: begin reg_addr <= 8'h5C; reg_data <= 16'h0001; end // Globalno omogućava SERDES
                2'd2: begin reg_addr <= 8'h50; reg_data <= 16'h0C03; end // Uključuje PLL
                default: begin reg_addr <= 8'h00; reg_data <= 16'h0000; end // Defaultna vrijednost
            endcase
            reg_we <= 1; reg_en <= 1;     // Aktivira upis u hardverski registar
            fsm <= 3'd2;                  // Prelazi u stanje čekanja
        end
        3'd2: begin                       // Drugo stanje: gasi upisne signale
            reg_we <= 0; reg_en <= 0;     // Deaktivira upis
            wcnt   <= 6'd0;               // Resetuje brojač kašnjenja
            fsm    <= 3'd3;               // Prelazi u petlju za čekanje
        end
        3'd3: begin                       // Treće stanje: čeka stabilizaciju takta
            wcnt <= wcnt + 1;             // Uvećava brojač kašnjenja
            if (wcnt == 6'd31) fsm <= 3'd4; // Prelazi dalje nakon 32 takta
        end
        3'd4: begin                       // Četvrto stanje: prelazi na idući registar
            if (idx < 2'd2) begin idx <= idx + 1; fsm <= 3'd1; end // Vraća se na upis
            else            fsm <= 3'd5;  // Završava proces konfiguracije
        end
        3'd5: fsm <= 3'd5;                // Peto stanje: zadržava FSM u mirovanju zauvijek
        default: fsm <= 3'd0;             // Zaštita od greške, vraća na početak
    endcase
end


// INTERNI SIGNALI I AUTOMATSKI RESET

wire        serdes_clk;                   // Generisani brzi takt
wire        tx_done;                      // Potvrda o spremnosti predajnika
wire        rx_done;                      // Potvrda o spremnosti prijemnika
wire [63:0] rx_data;                      // Linija za primljene podatke
wire        rx_prbs_err;                  // Zastavica hardverske greške na linku

// localparam [63:0] TX_PAT = 64'hA5A5A5A5_A5A5A5A5; 

reg [24:0] err_cnt = 0;                   // Brojač dužine trajanja prekida linka
reg        rx_recover = 0;                // Signal za forsirani oporavak prijemnika

always @(posedge serdes_clk) begin
    if (rx_recover) begin                 // Aktiviran je proces oporavka
        err_cnt <= err_cnt + 1;           // Zadržava reset signal kratko vrijeme
        if (err_cnt == 25'h20000FF) begin // Kada istekne reset sekvenca
            rx_recover <= 1'b0;           // Gasi signal za resetovanje
            err_cnt <= 0;                 // Vraća brojač grešaka na nulu
        end
    end else if (rx_prbs_err && rx_done) begin // Prijemnik radi ali detektuje prekid
        err_cnt <= err_cnt + 1;           // Uvećava brojač trajanja prekida
        if (err_cnt == 25'h1FFFFFF) begin // Provjerava da li prekid traje duže od ~300ms
            rx_recover <= 1'b1;           // Okida automatski reset prijemnika za hvatanje linka
        end
    end else begin                        // Komunikacija radi bez smetnji
        err_cnt <= 0;                     // Drži brojač resetovan
    end
end


// INSTANCIRANJE GATEMATE SERDES MODULA

CC_SERDES #(
    .SERDES_ENABLE    (1),                // Uključuje SERDES instancu
    .SERDES_AUTO_INIT (0)                 // Gasi automatsku inicijalizaciju
) u_serdes (
    // Povezivanje PLL modula
    .PLL_RESET_I          (serdes_rst),   // Povezuje sistemski reset na PLL
    .PLL_CLK_O            (serdes_clk),   // Izvozi generisani brzi takt
    
    // Povezivanje konfiguracijskih registara (Regfile)
    .REGFILE_CLK_I        (clk_10m),      // Prima osnovni takt za upis
    .REGFILE_WE_I         (reg_we),       // Prima signal za odobrenje upisa
    .REGFILE_EN_I         (reg_en),       // Prima signal za aktivaciju modula
    .REGFILE_ADDR_I       (reg_addr),     // Prima izračunatu adresu iz FSM-a
    .REGFILE_DI_I         (reg_data),     // Prima generisane podatke iz FSM-a
    .REGFILE_MASK_I       (16'hFFFF),     // Postavlja masku za cijelu 16-bitnu riječ
    .REGFILE_RDY_O        (reg_rdy),      // Obezbjeđuje povratni signal spremnosti registra
    
    // Konfigurisanje predajnika (TX)
    .TX_RESET_I           (serdes_rst),   // Povezuje sistemski reset na predajnik
    .TX_PCS_RESET_I       (1'b0),         // Fiksira reset digitalnog koda na 0
    .TX_PMA_RESET_I       (1'b0),         // Fiksira reset analognog interfejsa na 0
    .TX_CLK_I             (serdes_clk),   // Povezuje brzi radni takt
    .TX_DATA_I            (TX_PAT),       // Postavlja testni podsistem na statični uzorak
    .TX_RESET_DONE_O      (tx_done),      // Izvozi status inicijalizacije predajnika
    .TX_POWER_DOWN_N_I    (1'b1),         // Onemogućava prelazak predajnika u stanje mirovanja
    .TX_POLARITY_I        (1'b0),         // Održava standardni polaritet signala
    .TX_8B10B_EN_I        (1'b0),         // Onemogućava 8B/10B linijsko kodiranje
    .TX_ELEC_IDLE_I       (1'b0),         // Onemogućava električno mirovanje
    .TX_DETECT_RX_I       (1'b0),         // Gasi detekciju statusa prijemnika na drugom kraju
    .TX_PRBS_SEL_I        (3'b001),       // Aktivira PRBS-7 hardverski generator sekvence
    .TX_PRBS_FORCE_ERR_I  (1'b0),         // Gasi forsirano ubacivanje grešaka u prenos
    .TX_CHAR_IS_K_I       (8'h00),        // Postavlja kontrolne K-karaktere na nulu
    .TX_CHAR_DISPMODE_I   (8'h00),        // Održava nepromijenjen mod disproporcije 
    .TX_CHAR_DISPVAL_I    (8'h00),        // Održava nepromijenjene vrijednosti disproporcije
    .TX_8B10B_BYPASS_I    (8'h00),        // Gasi bypass interfejs za 8B10B enkoder
    
    // Konfigurisanje prijemnika (RX)
    .RX_RESET_I           (serdes_rst | rx_recover), // Povezuje globalni reset i auto-reset
    .RX_PMA_RESET_I       (1'b0),         // Fiksira reset analognog prijemnika na 0
    .RX_EQA_RESET_I       (1'b0),         // Fiksira reset ekvilajzera signala na 0
    .RX_CDR_RESET_I       (rx_recover),   // Povezuje reset modula za sinhronizaciju
    .RX_PCS_RESET_I       (1'b0),         // Fiksira reset digitalnog dijela prijemnika na 0
    .RX_BUF_RESET_I       (1'b0),         // Fiksira reset internih bafera na 0
    .RX_CLK_I             (serdes_clk),   // Povezuje brzi radni takt na prijemnik
    .RX_CLK_O             (),             // Ostavlja RX takt interfejs nepovezanim
    .RX_DATA_O            (rx_data),      // Izvozi primljene sirove podatke
    .RX_RESET_DONE_O      (rx_done),      // Izvozi status inicijalizacije prijemnika
    .RX_POWER_DOWN_N_I    (1'b1),         // Onemogućava prelazak prijemnika u stanje mirovanja
    .RX_POLARITY_I        (1'b0),         // Održava standardni polaritet prijemnog signala
    .RX_8B10B_EN_I        (1'b0),         // Onemogućava 8B/10B dekodiranje
    .RX_8B10B_BYPASS_I    (8'h00),        // Gasi bypass interfejs za 8B10B dekoder
    .RX_PRBS_SEL_I        (3'b001),       // Aktivira PRBS-7 provjeru na prijemu
    .RX_PRBS_CNT_RESET_I  (rx_recover),   // Povezuje reset PRBS brojača 
    .RX_PRBS_ERR_O        (rx_prbs_err),  // Izvozi PRBS status 
    .RX_EN_EI_DETECTOR_I  (1'b0),         // Gasi detektor električnog mirovanja linije
    .RX_COMMA_DETECT_EN_I (1'b0),         // Onemogućava detekciju zareza
    .RX_SLIDE_I           (1'b0),         // Gasi ručno pomjeranje okvira
    .RX_MCOMMA_ALIGN_I    (1'b0),         // Gasi negativno poravnanje simbola
    .RX_PCOMMA_ALIGN_I    (1'b0),         // Gasi pozitivno poravnanje simbola
    .LOOPBACK_I           (3'b000)        // Podešava mod rada na eksterni 
);


// LOGIKA ZA PROVJERU LINKA I STATUSNE INDIKATORE

reg [26:0] pll_cnt = 27'd0;               // Inicijalizuje brojač za LED prikaz aktivnosti sata
always @(posedge serdes_clk) pll_cnt <= pll_cnt + 1; // Uvećava se sa brzim taktom SERDES-a

reg [15:0] lock_cnt = 0;                  // Inicijalizuje brojač za provjeru stabilnosti linka
reg        loopback_ok = 1'b0;            // Inicijalizuje finalni logički izlaz za stabilan rad

always @(posedge serdes_clk) begin
    if (tx_done && rx_done) begin         // Provjerava da li su hardverski blokovi spremni
        if (rx_prbs_err == 1'b0) begin    // Provjerava da li ima grešaka u prijenosu
            if (lock_cnt == 16'hFFFF)     // Provjerava da li je link stabilan duzi period
                loopback_ok <= 1'b1;      // Potvrđuje ispravnost linka
            else 
                lock_cnt <= lock_cnt + 1; // Uvećava brojač stabilnog perioda
        end else begin
            lock_cnt <= 0;                // Resetuje brojač ukoliko se desi hardverska greška
            loopback_ok <= 1'b0;          // Gasi potvrdu stabilnosti
        end
    end else begin
        lock_cnt <= 0;                    // Resetuje brojač u slučaju niske spremnosti modula
        loopback_ok <= 1'b0;              // Forsira logičku nulu na indikator
    end
end


// UPRAVLJANJE LED SIGNALIZACIJOM (Aktivno nisko stanje)

assign led[0] = ~hb_cnt[23];              // Mapira sistemski radni indikator
assign led[1] = ~started;                 // Mapira indikator inicijalizacije
assign led[2] = ~tx_done;                 // Mapira indikator spremnosti predajnika
assign led[3] = ~rx_done;                 // Mapira indikator spremnosti prijemnika
assign led[4] = ~pll_cnt[26];             // Mapirac indikator rada SERDES takta
assign led[5] = ~loopback_ok;             // Mapira glavni indikator uspješnog gigabitnog linka
assign led[6] = serdes_rst;               // Mapira indikator statusa reseta SERDES bloka

endmodule