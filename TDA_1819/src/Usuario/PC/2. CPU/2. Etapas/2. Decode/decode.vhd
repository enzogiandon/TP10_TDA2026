
-- Entidad "decode":
-- Descripción: Aquí se define la etapa de decodificación de la segmentación del 
-- procesador: obtiene del Registro de Instrucción (IR) el código de operación de la
-- instrucción a ejecutar, lo interpreta y en función del resultado procederá a
-- obtener la información sobre los operandos a partir de las señales recibidas de la
-- etapa de búsqueda. Luego, en caso de ser necesario, utilizará dicha información 
-- para acceder al banco de registros de la CPU y leer de él los operandos propiamente
-- dichos de la instrucción a fin de asignarlos a las etapas que los necesiten para
-- trabajar con ellos. Por ejemplo, si se trata de una instrucción aritmético/lógica
-- la etapa "execute" necesitará algunos de ellos para realizar	la respectiva
-- operación, mientras que la etapa "writeback" deberá conocer en qué registro se
-- guardará el resultado; en cambio, si es una instrucción de almacenamiento en 
-- memoria, la etapa "memory access" tendrá que saber qué dato debe ser guardado y a
-- partir de qué dirección de la memoria de datos necesitará hacerlo. Además, la etapa
-- "decode" ofrece información adicional obtenida directamente a partir del código de 
-- operación que las siguientes etapas del pipeline también necesitarán para ser 
-- llevadas a cabo: el tipo de operación a realizar, el tipo y tamaño de los operandos, 
-- etc.
-- Procesos:
-- Main: En primer lugar, recibe la señal del administrador de la CPU para comenzar la
-- etapa de decodificación de una nueva instrucción. Luego, en la primera mitad del ciclo de
-- reloj comprueba si existen actualmente atascos de algún tipo en el cauce, deteniendo
-- temporalmente la ejecución en caso afirmativo. También obtiene del registro IR el código
-- de operación de la operación a ejecutar. Finalmente, en la segunda mitad del ciclo 
-- decodifica dicho código, accede en caso de ser necesario al banco de registros para obtener
-- los operandos y configura y envía toda la información requerida para que el resto de las 
-- etapas del pipeline puedan realizar su trabajo sin inconvenientes.
-- Procedimientos y funciones:
-- Initialize(): Configura y carga toda la información inicial para las siguientes etapas
-- del pipeline, antes de que la misma sea modificada durante la decodificación de la 
-- instrucción: operaciones nulas, operandos y direcciones vacías, etc.


library TDA_1819;
use TDA_1819.const_buses.all;
use TDA_1819.const_registros.all;
use TDA_1819.const_flags.all; -- Requerido para FLAG_F al evaluar saltos FP (BFPT/BFPF) en Decode
use TDA_1819.const_cpu.all;
use TDA_1819.repert_cpu.all;
use TDA_1819.tipos_cpu.all;



library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;
library std;
use std.TEXTIO.all;



entity decode is  
	
	generic (
		Pipelining	: BOOLEAN);

    port (
		StallHLT			: out	std_logic;
		StopInit			: out   std_logic;
		DoneID				: out   std_logic;
		IdInstIncWrPend		: out	std_logic_vector(7 downto 0);
		IdRegIncWrPend		: out   std_logic_vector(7 downto 0);
		BranchIDtoSM		: out   state_branch;
		IDtoMA				: out   memaccess_record;
		DataRegInID			: out   std_logic_vector(31 downto 0);
		IdRegID				: out   std_logic_vector(7 downto 0);
		SizeRegID			: out   std_logic_vector(3 downto 0);
		EnableRegID			: out   std_logic;
		EnableRegIDIP		: out   std_logic;
		EnableRegIDSP		: out   std_logic;
		EnableIncWrPend		: out   std_logic;
		EnableIncFPWrPend 	: out	std_logic;
		IDtoEX				: inout execute_record;
		IDtoWB				: inout writeback_record;
		StallBrEX			: inout std_logic;
		StallSTR			: in	std_logic;
		StallRAW			: in    std_logic;
		StallWAWAux			: in	std_logic;
		BranchEXALUtoSM		: in    state_branch;
		EXFPUPending		: in	std_logic;
		IFtoID				: in    decode_record;
		DataRegOutID		: in    std_logic_vector(31 downto 0);
		EnableID			: in    std_logic);

end decode;




architecture decode_architecture of decode is		


	SIGNAL IFtoIDAnt:	decode_record;
	SIGNAL IFtoIDLocal:	decode_record; 
	SIGNAL CodOp:		std_logic_vector(7 downto 0);
	SIGNAL StallBrID:	std_logic;

	
begin	
	
		
	Main: PROCESS	
	
	PROCEDURE Initialize (constant idAux: in integer) IS
	
	BEGIN
		IDtoEX.empty <= '1';
		IDtoEX.op <= std_logic_vector(to_unsigned(EX_NULL, IDtoEX.op'length)); 
		IDtoEX.fp <= 'Z';
		IDtoEX.sign <= 'Z';
		IDtoEX.op1 <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
		IDtoEX.op2 <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
		IDtoEX.address <= "ZZZZZZZZZZZZZZZZ";
			
		IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_NULL, IDtoMA.mode'length));
		IDtoMA.control <= NO_ACCESS_MEM;
		IDtoMA.datasize <= "ZZZZ";
		IDtoMA.source <= "ZZZZ";
		IDtoMA.address <= "ZZZZZZZZZZZZZZZZ";
		IDtoMA.data.decode <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"; 
			
		IDtoWB.mode <= std_logic_vector(to_unsigned(WB_NULL, IDtoWB.mode'length));
		IDtoWB.id <= std_logic_vector(to_unsigned(idAux, IDtoWB.mode'length));
		IDtoWB.datasize <= "ZZZZ";
		IDtoWB.source <= std_logic_vector(to_unsigned(WB_NULL, IDtoWB.source'length));
		IDtoWB.data.decode <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
	End Initialize;	
	
	VARIABLE First:			BOOLEAN := true;
	--VARIABLE wasRAW:		BOOLEAN := false;
	VARIABLE updateCodOp:	BOOLEAN := true;
	VARIABLE rgAux:			INTEGER;
	VARIABLE rfAux:			INTEGER;
	VARIABLE rdAux:			INTEGER;
	VARIABLE addrAux:		INTEGER; 
	VARIABLE idAux:			INTEGER := 0;
	-- Variables para resolución de saltos condicionales en Decode (TP10 Ejercicio 3)
	VARIABLE branchOp1:		std_logic_vector(31 downto 0); -- Operando 1 leido del banco de registros en ID
	VARIABLE branchOp2:		std_logic_vector(31 downto 0); -- Operando 2 leido del banco de registros en ID
	VARIABLE branchAddr:	std_logic_vector(15 downto 0); -- Dirección destino de salto (16 bits)
	
	BEGIN 
		if (First) then
			First := false;
			StallHLT <= '0';
			StallBrID <= '0';
			StallBrEX <= '0';
			BranchIDtoSM.enable <= '0';
			EnableRegID <= '0';
			EnableRegIDIP <= '0';
			EnableRegIDSP <= '0';
			EnableIncWrPend <= '0';
			EnableIncFPWrPend <= '0';
			DoneID <= '0';
			StopInit <= '0';
			Initialize(idAux);
			WAIT FOR 1 ns;
		end if;	
		WAIT UNTIL rising_edge(EnableID);
		idAux := idAux + 1;
		if ((StallRAW = '0') and (StallBrID = '0') and (StallBrEX = '0') and (StallSTR = '0') and (StallWAWAux = '0')) then
			IFtoIDLocal <= IFtoID;
		elsif (StallRAW = '1') then
			IFtoIDLocal <= IFtoIDAnt; 
			Initialize(idAux);	
			WAIT UNTIL falling_edge(StallRAW); 
			--WAIT UNTIL rising_edge(EnableID);
			WAIT FOR 1 ns; 
			updateCodOp := false;
		elsif (StallBrID = '1') then
			if (StallSTR = '1') then
				WAIT UNTIL falling_edge(EnableID);
				Initialize(idAux);
				WAIT UNTIL rising_edge(EnableID);
				if (StallSTR = '1') then
					--IFtoIDLocal <= IFtoIDAnt;
					--Initialize(idAux);
					WAIT UNTIL falling_edge(StallSTR);
					WAIT UNTIL rising_edge(EnableID);
					WAIT UNTIL rising_edge(EnableID);
				end if;
			elsif (StallWAWAux = '1') then 
				Initialize(idAux);
				WAIT UNTIL falling_edge(StallWAWAux);
				WAIT FOR 1 ns;
				if (StallSTR = '1') then
					WAIT UNTIL rising_edge(EnableID);
					WAIT UNTIL rising_edge(EnableID); 
					WAIT UNTIL rising_edge(EnableID);
				else
					WAIT UNTIL rising_edge(EnableID);
					WAIT UNTIL rising_edge(EnableID);
				end if;
			else
				WAIT UNTIL falling_edge(EnableID);
				Initialize(idAux);
				WAIT UNTIL rising_edge(EnableID);
				if (StallSTR = '1') then
					WAIT UNTIL falling_edge(StallSTR);
					WAIT UNTIL rising_edge(EnableID);
				end if;
			end if;
			IFtoIDLocal <= IFtoID;
		elsif (StallBrEX = '1') then
			if (StallSTR = '1') then
				--WAIT UNTIL falling_edge(EnableID);
				--Initialize(idAux);
				WAIT UNTIL rising_edge(BranchEXALUtoSM.enable);
				if (BranchEXALUtoSM.branch_taken = '1') then	
					WAIT UNTIL rising_edge(EnableID);
					--WAIT UNTIL rising_edge(EnableID);
					if (StallSTR = '1') then
						WAIT UNTIL falling_edge(StallSTR);
						WAIT UNTIL rising_edge(EnableID);
						WAIT UNTIL rising_edge(EnableID);
						WAIT UNTIL rising_edge(EnableID);
					else
						WAIT UNTIL rising_edge(EnableID);
					end if;
				else  
					Initialize(idAux);
					WAIT UNTIL rising_edge(EnableID);
					if (StallSTR = '1') then
						WAIT UNTIL falling_edge(StallSTR);
						WAIT UNTIL rising_edge(EnableID);
					end if;
				end if;
			else
				WAIT FOR 1 ns;
				if (StallWAWAux = '1') then
					WAIT UNTIL rising_edge(BranchEXALUtoSM.enable);
					Initialize(idAux);
					if (BranchEXALUtoSM.branch_taken = '1') then	
						WAIT UNTIL rising_edge(EnableID);
						if (StallWAWAux = '1') then
							WAIT UNTIL falling_edge(StallWAWAux);
							WAIT UNTIL rising_edge(EnableID);
							if (StallSTR = '1') then
								WAIT UNTIL rising_edge(EnableID);
								WAIT UNTIL rising_edge(EnableID);
							else
								WAIT UNTIL rising_edge(EnableID);
							end if;
						else
							WAIT UNTIL rising_edge(EnableID);
						end if;
					else
						WAIT UNTIL rising_edge(EnableID);
						if (StallWAWAux = '1') then
							WAIT UNTIL falling_edge(StallWAWAux);
							WAIT UNTIL rising_edge(EnableID);
							if (StallSTR = '1') then
								 WAIT UNTIL rising_edge(EnableID);
							end if;
						end if;
					end if;
					IFtoIDLocal <= IFtoID;
				else	
					WAIT UNTIL falling_edge(EnableID);
					Initialize(idAux);
					WAIT UNTIL rising_edge(BranchEXALUtoSM.enable);
					if (BranchEXALUtoSM.branch_taken = '1') then
						WAIT UNTIL rising_edge(EnableID);
						WAIT UNTIL rising_edge(EnableID);
						if (StallSTR = '1') then
							WAIT UNTIL falling_edge(StallSTR);
							WAIT UNTIL rising_edge(EnableID);
							WAIT UNTIL rising_edge(EnableID);
						end if;
					else
						WAIT UNTIL rising_edge(EnableID); 
						if (StallSTR = '1') then
							WAIT UNTIL falling_edge(StallSTR);
							WAIT UNTIL rising_edge(EnableID);
						end if;
					end if;	
				end if;
			end if;
			IFtoIDLocal <= IFtoID;
		elsif (StallSTR = '1') then
			IFtoIDLocal <= IFtoIDAnt;
			--Initialize(idAux);
			WAIT UNTIL falling_edge(StallSTR); 
			if (StallWAWAux = '1') then
				WAIT UNTIL falling_edge(StallWAWAux);
			end if;
			WAIT UNTIL rising_edge(EnableID);
			IFtoIDLocal <= IFtoID;
			--updateCodOp := false;
		elsif (StallWAWAux = '1') then
			IFtoIDLocal <= IFtoIDAnt; 
			--Initialize(idAux);
			WAIT UNTIL falling_edge(StallWAWAux);
			WAIT FOR 1 ns;
			if (StallSTR = '1') then
				WAIT UNTIL rising_edge(EnableID);
				WAIT UNTIL rising_edge(EnableID);
			else
				WAIT UNTIL rising_edge(EnableID);
			end if;
			IFtoIDLocal <= IFtoID;
			--updateCodOp := false;
		end if;
		StallBrID <= '0';
		StallBrEX <= '0';
		IdInstIncWrPend <= IDtoWB.id;
		IdRegIncWrPend <= IDtoWB.mode;
		EnableIncWrPend <= '1';	
		if (IDtoEX.fp = '1') then
			EnableIncFPWrPend <= '1';
		end if;
		WAIT FOR 1 ns;
		EnableIncWrPend <= '0';
		EnableIncFPWrPend <= '0';
		WAIT FOR 1 ns;
		if (updateCodOp) then
			IdRegID <= std_logic_vector(to_unsigned(ID_IR, IdRegID'length));
			SizeRegID <= std_logic_vector(to_unsigned(1, SizeRegID'length));
			EnableRegID <= '1';
			WAIT FOR 1 ns;
			EnableRegID <= '0';
			WAIT FOR 1 ns;
			CodOp <= DataRegOutID(7 downto 0);
		else
			updateCodOp := true;
		end if;
		--IFtoIDLocal <= IFtoID;

		WAIT UNTIL falling_edge(EnableID);
		Initialize(idAux);
		IDtoEX.empty <= '0';
		CASE CodOp IS
			WHEN LB =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= READ_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(1, IDtoMA.datasize'length));
				IDtoWB.datasize <= std_logic_vector(to_unsigned(1, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_MEM, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
				IdRegID <= IFtoIDLocal.package2(7 downto 0);
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length)); 
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
				IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
			WHEN SB =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= WRITE_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(1, IDtoMA.datasize'length));
				IDtoMA.source <= std_logic_vector(to_unsigned(MEM_ID, IDtoMA.source'length));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(1, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.data.decode(7 downto 0) <= DataRegOutID(7 downto 0);
				if (StallRAW = '0') then
					addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
					IdRegID <= IFtoIDLocal.package2(7 downto 0);
					SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
					IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
				end if;
			WHEN LH =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.datasize <= std_logic_vector(to_unsigned(2, IDtoMA.datasize'length));
				IDtoWB.datasize <= std_logic_vector(to_unsigned(2, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_MEM, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
				if (to_integer(unsigned(IFtoIDLocal.package2(7 downto 0))) = ID_SP) then
					IDtoMA.control <= READ_STACK_MEM;
				else
					IDtoMA.control <= READ_DATA_MEM;
				end if;
				IdRegID <= IFtoIDLocal.package2(7 downto 0);
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
				IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
			WHEN SH =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.datasize <= std_logic_vector(to_unsigned(2, IDtoMA.datasize'length));
				IDtoMA.source <= std_logic_vector(to_unsigned(MEM_ID, IDtoMA.source'length));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.data.decode(15 downto 0) <= DataRegOutID(15 downto 0);
				if (StallRAW = '0') then
					addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
					if (to_integer(unsigned(IFtoIDLocal.package2(7 downto 0))) = ID_SP) then
						IDtoMA.control <= WRITE_STACK_MEM;
					else
						IDtoMA.control <= WRITE_DATA_MEM;
					end if;
					IdRegID <= IFtoIDLocal.package2(7 downto 0);
					SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
					IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
				end if;
			WHEN LW =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= READ_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(4, IDtoMA.datasize'length));
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_MEM, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
				IdRegID <= IFtoIDLocal.package2(7 downto 0);
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
				IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
			WHEN SW => 
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= WRITE_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(4, IDtoMA.datasize'length));
				IDtoMA.source <= std_logic_vector(to_unsigned(MEM_ID, IDtoMA.source'length));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.data.decode(31 downto 0) <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
					IdRegID <= IFtoIDLocal.package2(7 downto 0);
					SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
					IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length)); 
				end if;
			WHEN TDA_1819.repert_cpu.LF =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= READ_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(4, IDtoMA.datasize'length));
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_MEM, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
				IdRegID <= IFtoIDLocal.package2(7 downto 0);
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
				IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
			WHEN SF =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= WRITE_DATA_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(4, IDtoMA.datasize'length));
				IDtoMA.source <= std_logic_vector(to_unsigned(MEM_ID, IDtoMA.source'length));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.data.decode(31 downto 0) <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					addrAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 8)));
					IdRegID <= IFtoIDLocal.package2(7 downto 0);
					SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					addrAux := addrAux + to_integer(unsigned(DataRegOutID(15 downto 0)));
					IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length)); 
				end if;
			WHEN MFF =>
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_ID, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length)); 
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoWB.data.decode(31 downto 0) <= DataRegOutID(31 downto 0); 
			WHEN MFR =>
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_ID, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length)); 
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoWB.data.decode(31 downto 0) <= DataRegOutID(31 downto 0);  
			WHEN MRF =>
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_ID, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length)); 
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoWB.data.decode(31 downto 0) <= DataRegOutID(31 downto 0);
			WHEN TF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_TF, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN TI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_TI, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);	
			WHEN DADD =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_ADD, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns; 
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DADDI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_ADD, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DADDU =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_ADD, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN DADDUI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_ADD, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN ADDF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_ADD, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns; 
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DSUB =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SUB, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN DSUBI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SUB, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));				
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DSUBU =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SUB, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 	
				end if;
			WHEN SUBF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SUB, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN DMUL =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_MUL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);
				end if;
			WHEN DMULU =>
		  		IDtoEX.op <= std_logic_vector(to_unsigned(EX_MUL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN MULF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_MUL, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN DDIV =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DIV, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);   
				end if;
			WHEN DDIVU =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DIV, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);	
				end if;
			WHEN DIVF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DIV, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN SLT =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SLT, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);
				end if;
			WHEN SLTI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_SLT, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN LTF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_LTF, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN LEF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_LEF, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN EQF =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_EQF, IDtoEX.op'length));
				IDtoEX.fp <= '1';
				IDtoEX.sign <= '1';	
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN NEGR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_NEG, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN ANDR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_AND, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN ANDI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_AND, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
			WHEN ORR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_OR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN ORI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_OR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN XORR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_XOR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN XORI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_XOR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN XNORR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_XNOR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0); 
				end if;
			WHEN NOTR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_NOT, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DSL =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DSLI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DSR =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DSRI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '0';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DSLS =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DSLSI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSL, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN DSRS =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				rgAux := to_integer(unsigned(IFtoIDLocal.package1(23 downto 16)));
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rgAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					IDtoEX.op2 <= DataRegOutID(31 downto 0);  
				end if;
			WHEN DSRSI =>
				IDtoEX.op <= std_logic_vector(to_unsigned(EX_DSR, IDtoEX.op'length));
				IDtoEX.fp <= '0';
				IDtoEX.sign <= '1';
				IDtoWB.datasize <= std_logic_vector(to_unsigned(4, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_EX, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				IDtoEX.op2(7 downto 0) <= IFtoIDLocal.package1(23 downto 16);
				IDtoEX.op2(31 downto 8) <= IFtoIDLocal.package2(23 downto 0);
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoEX.op1 <= DataRegOutID(31 downto 0);
			WHEN JMP =>	
				DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
				DataRegInID(15 downto 0) <= IFtoIDLocal.package1(15 downto 0);
				if (Pipelining) then
					StallBrID <= '1';
				end if;
				BranchIDtoSM.branch_taken <= '1';
				BranchIDtoSM.enable <= '1';
				EnableRegIDIP <= '1';
				WAIT FOR 1 ns;
				BranchIDtoSM.enable <= '0';
				EnableRegIDIP <= '0';
				WAIT FOR 1 ns;
			WHEN BEQ =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL (no se ejecuta operación en ALU).
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				branchAddr(7 downto 0) := IFtoIDLocal.package1(23 downto 16);
				branchAddr(15 downto 8) := IFtoIDLocal.package2(7 downto 0);
				-- Lectura de operando 1 (rdAux) desde el banco de registros
				IdRegID <= std_logic_vector(to_unsigned(rdAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				branchOp1 := DataRegOutID(31 downto 0); 
				-- Protección RAW: Solo leer el segundo operando si no hay atasco de datos pendiente
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					branchOp2 := DataRegOutID(31 downto 0); 
				end if;
				-- Evaluación combinacional de condición de salto en Decode
				if (StallRAW = '0') then
					if (branchOp1 = branchOp2) then
						-- Rama Tomada: Cargar dirección de salto directamente en registro IP
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						-- Parada en ID: Descarta la instrucción incorrecta ya traída en IF (1 ciclo de penalización)
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo secuencial continuo (0 ciclos de penalización, IP inalterado)
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN BNE =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(15 downto 8)));
				branchAddr(7 downto 0) := IFtoIDLocal.package1(23 downto 16);
				branchAddr(15 downto 8) := IFtoIDLocal.package2(7 downto 0);
				-- Lectura de operando 1 (rdAux)
				IdRegID <= std_logic_vector(to_unsigned(rdAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				branchOp1 := DataRegOutID(31 downto 0);  
				-- Protección RAW: Lectura de operando 2 (rfAux)
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					branchOp2 := DataRegOutID(31 downto 0);
				end if;
				-- Evaluación combinacional en Decode (desigualdad)
				if (StallRAW = '0') then
					if (branchOp1 /= branchOp2) then
						-- Rama Tomada: Actualizar IP y activar parada corta (StallBrID)
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo continuo sin paradas
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN BEQZ =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				branchAddr := IFtoIDLocal.package1(23 downto 8);
				-- Lectura de único operando (rdAux)
				IdRegID <= std_logic_vector(to_unsigned(rdAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				branchOp1 := DataRegOutID(31 downto 0); 
				-- Evaluación de condición respecto a cero en Decode
				if (StallRAW = '0') then
					if (to_integer(unsigned(branchOp1)) = 0) then
						-- Rama Tomada: Cargar IP y generar burbuja de 1 ciclo (StallBrID)
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo continuo sin paradas
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN BNEZ =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				branchAddr := IFtoIDLocal.package1(23 downto 8);
				-- Lectura de único operando (rdAux)
				IdRegID <= std_logic_vector(to_unsigned(rdAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(4, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				branchOp1 := DataRegOutID(31 downto 0); 
				-- Evaluación de condición respecto a distinto de cero en Decode
				if (StallRAW = '0') then
					if (to_integer(unsigned(branchOp1)) /= 0) then
						-- Rama Tomada: Cargar IP y generar burbuja de 1 ciclo (StallBrID)
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo continuo sin paradas
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN BFPT =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL
				branchAddr := IFtoIDLocal.package1(15 downto 0);
				-- Lectura del registro de flags de punto flotante (ID_FPFLAGS)
				IdRegID <= std_logic_vector(to_unsigned(ID_FPFLAGS, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(1, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				-- Evaluación del flag FLAG_F en Decode (salto si flag = '1')
				if (StallRAW = '0') then
					if (DataRegOutID(FLAG_F) = '1') then
						-- Rama Tomada: Cargar IP y activar parada corta (StallBrID)
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo continuo
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN BFPF =>
				-- [TP10 Ej. 3 - Decode Branching]
				-- Desacople de EX: IDtoEX.op permanece en EX_NULL
				branchAddr := IFtoIDLocal.package1(15 downto 0);
				-- Lectura del registro de flags de punto flotante (ID_FPFLAGS)
				IdRegID <= std_logic_vector(to_unsigned(ID_FPFLAGS, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(1, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				-- Evaluación del flag FLAG_F en Decode (salto si flag = '0')
				if (StallRAW = '0') then
					if (DataRegOutID(FLAG_F) = '0') then
						-- Rama Tomada: Cargar IP y activar parada corta (StallBrID)
						DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
						DataRegInID(15 downto 0) <= branchAddr;
						if (Pipelining) then
							StallBrID <= '1';
						end if;
						BranchIDtoSM.branch_taken <= '1';
						BranchIDtoSM.enable <= '1';
						EnableRegIDIP <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						EnableRegIDIP <= '0';
						WAIT FOR 1 ns;
					else
						-- Rama No Tomada: Flujo continuo
						BranchIDtoSM.branch_taken <= '0';
						BranchIDtoSM.enable <= '1';
						WAIT FOR 1 ns;
						BranchIDtoSM.enable <= '0';
						WAIT FOR 1 ns;
					end if;
				end if;
			WHEN PUSHH =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= WRITE_STACK_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(2, IDtoMA.datasize'length));
				IDtoMA.source <= std_logic_vector(to_unsigned(MEM_ID, IDtoMA.source'length));
				rfAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0)));
				IdRegID <= std_logic_vector(to_unsigned(rfAux, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.data.decode(15 downto 0) <= DataRegOutID(15 downto 0); 
				if (StallRAW = '0') then
					IdRegID <= std_logic_vector(to_unsigned(ID_SP, IdRegID'length));
					SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
					EnableRegID <= '1';
					WAIT FOR 1 ns;
					EnableRegID <= '0';
					WAIT FOR 1 ns;
					addrAux := to_integer(unsigned(DataRegOutID(15 downto 0))) - 2;
					IDtoMA.address <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
					DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
					DataRegInID(15 downto 0) <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
					EnableRegIDSP <= '1';
					WAIT FOR 1 ns;
					EnableRegIDSP <= '0';
					WAIT FOR 1 ns;
				end if;				
			WHEN POPH =>
				IDtoMA.mode <= std_logic_vector(to_unsigned(MEM_MEM, IDtoMA.mode'length));
				IDtoMA.control <= READ_STACK_MEM;
				IDtoMA.datasize <= std_logic_vector(to_unsigned(2, IDtoMA.datasize'length));
				IDtoWB.datasize <= std_logic_vector(to_unsigned(2, IDtoWB.datasize'length));
				IDtoWB.source <= std_logic_vector(to_unsigned(WB_MEM, IDtoWB.source'length));
				rdAux := to_integer(unsigned(IFtoIDLocal.package1(7 downto 0))) + 1;
				IDtoWB.mode <= std_logic_vector(to_unsigned(rdAux, IDtoWB.mode'length));
				IdRegID <= std_logic_vector(to_unsigned(ID_SP, IdRegID'length));
				SizeRegID <= std_logic_vector(to_unsigned(2, SizeRegID'length));
				EnableRegID <= '1';
				WAIT FOR 1 ns;
				EnableRegID <= '0';
				WAIT FOR 1 ns;
				IDtoMA.address <= DataRegOutID(15 downto 0);
				addrAux := to_integer(unsigned(DataRegOutID(15 downto 0))) + 2;
				DataRegInID(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
				DataRegInID(15 downto 0) <= std_logic_vector(to_unsigned(addrAux, IDtoMA.address'length));
				EnableRegIDSP <= '1';
				WAIT FOR 1 ns;
				EnableRegIDSP <= '0';
				WAIT FOR 1 ns;
			WHEN NOP =>
				WAIT FOR 1 ns;
			WHEN HALT =>  
				Initialize(idAux); 
				WAIT FOR 2 ns; 
				if (EXFPUPending = '1') then
					StallHLT <= '1';
					DoneID <= '1';
					WAIT FOR 1 ns;
					DoneID <= '0';
					WAIT UNTIL falling_edge(EXFPUPending);
					StallHLT <= '0';
					if (StallSTR = '1') then
						WAIT UNTIL falling_edge(StallSTR); 
						WAIT UNTIL falling_edge(EnableID);
					end if;
				elsif (StallWAWAux = '1') then
					StallHLT <= '1';
					DoneID <= '1';
					WAIT FOR 1 ns;
					DoneID <= '0';
					WAIT UNTIL falling_edge(StallWAWAux);
					StallHLT <= '0';
					WAIT FOR 1 ns;
					if (StallSTR = '1') then
						WAIT UNTIL falling_edge(StallSTR); 
						WAIT UNTIL falling_edge(EnableID);
						WAIT UNTIL falling_edge(EnableID);
					end if;
				else
					WAIT FOR 1 ns;
					if (StallSTR = '1') then
						StallHLT <= '1';
						DoneID <= '1';
						WAIT FOR 1 ns;
						DoneID <= '0';
						WAIT UNTIL falling_edge(StallSTR);
						StallHLT <= '0'; 
						WAIT UNTIL falling_edge(EnableID);
					end if;
				end if;
				StopInit <= '1';
			WHEN OTHERS =>
				report "Error: el código de operación de la instrucción no es válido"
				severity FAILURE;
		END CASE;
		IFtoIDAnt <= IFtoIDLocal;
		--IdRegIncWrPend <= IDtoWB.mode;
		--EnableIncWrPend <= '1';
		DoneID <= '1';
		WAIT FOR 1 ns;
		--EnableIncWrPend <= '0';
		DoneID <= '0';
		WAIT FOR 1 ns;
		if (StallRAW = '1') then
			Initialize(idAux);
		end if;
	END PROCESS Main;					
	

end decode_architecture;