
-- Paquete "const_buses":
-- Descripción: Aquí se definen los posibles valores que pueden ser asignados al bus
-- de control de la PC para determinar, por un lado, el tipo de operación a realizar
-- sobre la memoria principal (lectura o escritura) y, por otro, la sección de memoria
-- a acceder (datos, instrucciones o pila) para llevar a cabo dicha operación.


LIBRARY IEEE;

USE std.textio.all;
USE IEEE.std_logic_1164.all; 


PACKAGE const_buses is
	
	CONSTANT READ_WRITE_POS:	INTEGER := 1;
	CONSTANT SECTION_POS:		INTEGER := 0;
	CONSTANT READ_MEM:			std_logic := '0';
	CONSTANT WRITE_MEM:			std_logic := '1';
	CONSTANT DATA_MEM:			std_logic := '0';
	CONSTANT INST_MEM:			std_logic := '0';
	CONSTANT STACK_MEM:			std_logic := '1';
	CONSTANT NO_ACCESS_MEM:		std_logic_vector(READ_WRITE_POS downto SECTION_POS) := "ZZ";
	CONSTANT READ_DATA_MEM:		std_logic_vector(READ_WRITE_POS downto SECTION_POS) := READ_MEM & DATA_MEM;	
	CONSTANT WRITE_DATA_MEM:	std_logic_vector(READ_WRITE_POS downto SECTION_POS) := WRITE_MEM & DATA_MEM;		
	CONSTANT READ_INST_MEM:		std_logic_vector(READ_WRITE_POS downto SECTION_POS) := READ_MEM & INST_MEM;
	CONSTANT WRITE_INST_MEM:	std_logic_vector(READ_WRITE_POS downto SECTION_POS) := WRITE_MEM & INST_MEM;
	CONSTANT READ_STACK_MEM:	std_logic_vector(READ_WRITE_POS downto SECTION_POS) := READ_MEM & STACK_MEM;
	CONSTANT WRITE_STACK_MEM:	std_logic_vector(READ_WRITE_POS downto SECTION_POS) := WRITE_MEM & STACK_MEM;
	

END const_buses;




PACKAGE BODY const_buses is 
	

END const_buses;


