#!/usr/bin/perl

#CSV:xslamp01

#úloha:CSV: Převod tabulky zapsané pomocí CSV na XML
#autor: Ondřej Šlampa, xslamp01@stud.fit.vutbr.cz

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use IO::Handle;
use Encode;
use Text::CSV_PP;
use XML::Simple;
use Getopt::Long qw(:config no_auto_abbrev pass_through);

#pokud byl poslední načtený řádek ukončen pomocí CRLF, má hodnotu 1, jinak 0
our $end=1;

#vrátí řetězec ze vstupního souboru, představující jeden záznam CSV
sub get_parse_string()
{
	my $record="";
	my $line=undef;
	my $result=-1;
	my $counter=0;
	my $offset=0;
	
	do
	{
		#načtení řádku
		$line=<STDIN>;
		
		#pokud byl načten řádek, nastaví se proměnná $end
		if(defined($line))
		{
			if(substr($line, -1, 1) eq "\n")
			{
				$end=1;
			}
			else
			{
				#print(STDERR "0");
				$end=0;
			}
			
		}
		else
		{
			#pokud se načítá jiný než první řádek záznamu,
			#nebo předchozí řádek byl ukončen CRLF, ukončí se skript s chybou 4
			if($counter!=0 || $end==1)
			{
				exit(4);
			}
			else
			{
				return undef;
			}
		}
		
		#připojení řádu k záznamu
		$record.=$line;
		#kontrola počtu uvozovek
		do
		{
			$result = index($record, '"', $offset);
			if($result!=-1)
			{
				$counter++;
				$offset=$result+1;
			}
		}
		#pokud dosud načtené řádky záznamu obsahují lichý počet uvozovek
		#znamená to, že se musí načíst další řádek
		while ($result != -1);
	}
	while($counter%2==1);
	
	return $record;
}

#funkce, která vrátí jestli je její první parametr, platné jméno pro XML element
sub is_XML_element_name($)
{
	my $name=$_[0];
	
	if(!defined($name) || length($name)==0)
	{
		return 0;
	}
	
	if(length($name)>=3)
	{
		if(uc(substr($name,0,3)) eq "XML")
		{
			return 0;
		}
	}
	
	if($name=~m/^[:A-Za-z\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}][:A-Za-z\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}-.0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]*$/)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

#funkce, která vrátí opravené jméno XML elementu, zadané jako první parametr
#pokud by oprava vedla na neplatné jméno, je vráceno undef
sub fix_XML_element_name($)
{
	my $name=$_[0];
	
	if(!defined($name))
	{
		return undef;
	}
	
	my $name_len=length $name;
	
	if($name!~m/^[:A-Za-z\x{C0}-\x{D6}\x{D8}-\x{F6}\{xF8}-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/)
	{
		return undef;
	}

	$name =~ s/[^:A-Za-z\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}-.0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]/-/g;
	
	return $name;
}

################################################################################
#
#začátek skriptu
#

#proměnné nastavení
my $help=undef;
my $input=undef;
my $output=undef;
my $no_XML_header=undef;
my $root_element=undef;
my $separator=undef;
my $CSV_header=undef;
my $line_element=undef;
my $index=undef;
my $start=undef;
my $error_recovery=undef;
my $missing_value=undef;
my $all_columns=undef;

#překódování argumentů příkazové řádky
for my $i (0..(scalar @ARGV-1))
{
	$ARGV[$i]=decode("utf8",$ARGV[$i]);
} 

#zpracování argumentů příkazové řádky
GetOptions
(
	'help'=>\$help,
	'input=s'=>\$input,
	'output=s'=>\$output,
	'n'=>\$no_XML_header,
	'r=s'=>\$root_element,
	's=s'=>\$separator,
	'h'=>\$CSV_header,
	'l=s'=>\$line_element,
	'i'=>\$index,
	'start=i'=>\$start,
	'e|error-recovery'=>\$error_recovery,
	'missing-value=s'=>\$missing_value,
	'all-columns'=>\$all_columns,
	'<>'=>sub{exit(1);},
);

#vypsání nápovědy
if($help)
{
	#kontrola jestli byl zadán i přepínač než --help
	if($input || $output || $no_XML_header || $root_element || $separator || $CSV_header || $line_element || $index || $start || $error_recovery || $missing_value || $all_columns)
	{
		exit(1);
	}
	else
	{
		print 'Autor:       Ondřej Šlampa, xslamp01@stud.fit.vutbr.cz', "\n";
		print "Zadání:      CSV: CSV2XML\n";
		print "Popis zadání:Program, který převede tabulku v CVS do XML.\n\n";
		print "Přepínače:\n";
		print "  --help               vypíše tuto nápovědu\n";
		print "  --input=filename     vstupní soubor\n";
		print "  --output=filename    výstupní soubor\n";
		print "  -n                   generování XML hlavičky\n";
		print "  -r=root-element      jméno párového kořenového elementu XML\n";
		print "  -s=separator         separátor sloupců CVS\n";
		print "  -h                   první řádek CSV je hlavička tabulky\n";
		print "  -l=line-element      jméno XML elementu, který obaluje každý řádek tabulky\n";
		print "  -i                   vložení atributu index na každý řádek tabulky, pouze s -l\n";
		print "  --start=n            inicializační hodnota čítače pro -i\n";
		print "  -e, --error-recovery zotavení z chybného počtu sloupců\n";
		print "  --missing-value=val  doplní chybějící sloupce hodnotou val, posuze s -e\n";
		print "  --all-columns        vloží všechny sloupce, pouze s -e\n";
		
		exit(0);
	}
}


#kontrola nastavení, některé přepínače vyžadují jiné
if(defined($index))
{
	if(!defined($line_element))
	{
		exit(1);
	}
}
if(defined($start))
{
	if((!defined($index)) || ($start<0))
	{
		exit(1);
	}
}

if(defined($missing_value) || defined($all_columns))
{
	if(!defined($error_recovery))
	{
		exit(1);
	}
}

#nastavení výchozích hodnot a kontrola uživatelem zadaných
if(!defined($separator))
{
	$separator=',';
}
elsif($separator eq "TAB")
{
	$separator="\t";
}
elsif((length $separator)!=1)
{
	exit(1);
}

if(!defined($line_element))
{
	$line_element="row";
}
elsif(!is_XML_element_name($line_element))
{
	exit(30);
}

if(defined($root_element))
{
	if(!is_XML_element_name($root_element))
	{
		exit(30);
	}
}

if(!defined($start))
{
	$start=1;
}

my $XML_header=undef;

#nastavení hlavičky XML
if(!defined($no_XML_header))
{
	$XML_header='<?xml version="1.0" encoding="UTF-8"?>';
}

my $input_file=undef;
my $output_file=undef;

#otevření souborů na vstup a výstup
if(defined($input))
{
	open(INPUT,  '<', "$input") || (exit(2));
	STDIN->fdopen( \*INPUT,  'r' ) || (exit(2));
}

if(defined($output))
{
	open(OUTPUT, '>', "$output") || (exit(3));
	STDOUT->fdopen( \*OUTPUT, 'w' ) || (exit(3));
}

#parser CSV souboru
my $csv=Text::CSV_PP->new
({
    quote_char=>'"',
    escape_char=>'"',
    sep_char=>$separator,
    eol=>"\r\n",
    always_quote=>0,
    binary=>1,
    keep_meta_info=>0,
    allow_loose_quotes=>0,
    allow_loose_escapes=>0,
    allow_whitespace=>0,
    blank_is_undef=>0,
    verbatim=>0,
});

#načtení prvního řádku CSV
my $tmp=$csv->parse(get_parse_string());
my @line=undef;

#pokud nastala chba na vstupu, skript se ukončí s chybbou 4
if(defined($csv->error_input()))
{
	exit(4);
}
else
{
	@line=$csv->fields();
}

#tabulka, hlavička, počitadlo řádků
my @table=();
my @header=();
my $row_counter=$start-1;
my $added_cols=0;

#vytvoření hlavičky tabulky, když první řádek je hlavička tabulky
if(defined($CSV_header))
{
	@header=@line;
	
	#kontrola a oprava jmen sloupců tabulky (jmen XML elemenů)
	for my $i (0..((scalar @header)-1))
	{
		my $item=$header[$i];
		
		if(!is_XML_element_name($item))
		{
			if($item=fix_XML_element_name($item))
			{
				$header[$i]=$item;
			}
			else
			{
				exit(31);
			}
		}
	}
}
#když není, vygeneruje se,
#řádek se vloží jako první řádek tabulky
else
{
	@header=();
	
	for my $i (1..((scalar @line)))
	{
		push @header, ("col"."$i");
	}
	
	my %row=();
	
	$row_counter++;
	
	#pokud se má vložit index řádku,vloží se
	if(defined($index))
	{
		$row{"index"}=$row_counter;
	}
	
	#vytvoření řádku tabulky
	for my $i (0..((scalar @line)-1))
	{
		$row{$header[$i]}=[$line[$i]];
	}
	
	#vložení řádku do tabulky
	push @table, \%row;
}

#délka prvního řádku CSV
my $first_line_len=scalar @header;

#načítání řádků CSV a zpracovávání na tabulku
while($tmp=$csv->parse(get_parse_string()))
{
	#$csv->parse($tmp);
	@line=$csv->fields();
	
	while((scalar @header)!=$first_line_len)
	{
		pop @header;
	}
	
	
	
	#pokud má současný řádek jinou délku než hlavička
	if((scalar @line)!=(scalar @header))
	{
		#pokud je má provádět oprava počtu sloupců tabulky
		if(defined($error_recovery))
		{
			#pokud je současný řádek kratší, doplní se
			while((scalar @line)<(scalar @header))
			{
				push @line, $missing_value;
			}
			
			#pokud se nemají tisknout všechny sloupce
			if(!defined($all_columns))
			{
				#současný řádek se zkrátí na velikost hlavičky
				while((scalar @line)>(scalar @header))
				{
					pop @line;
				}
			}
			#pokud mají, je hlavička prodloužena
			else
			{
				for my $i (((scalar @header)+1)..(scalar @line))
				{
					push @header, ("col"."$i");
				}
			}
		}
		#neprovádí se oprava počtu sloupců, chyba
		else
		{
			exit(32);
		}
	}
	
	my %row=();
	
	$row_counter++;
	
	#pokud se má vkládat index, vloží se
	if(defined($index))
	{
		$row{"index"}=$row_counter;
	}
	
	#vytvoření řádku tabulky
	for my $i (0..((scalar @line)-1))
	{
		$row{$header[$i]}=[$line[$i]];
	}
	
	#vložení řádku do tabulky
	push @table, \%row;
}

#pokud nastala chba na vstupu, skript se ukončí s chybbou 4
if(defined($csv->error_input()))
{
	exit(4);
}


#závěrečná oprava počtu sloupců tabulky podle, nejdelšího řádku
#if(defined($all_columns) && $first_line_len!=(scalar @header))
#{
	#foreach my $row_ref (@table)
	#{
	#	for my $i (((scalar keys %$row_ref))..((scalar @header)-1))
	#	{
	#		$row_ref->{$header[$i]}=[$missing_value];
	#	}
	#}
#}

#konečná podoba, úprava pro zracování převaděčem
my %final=($line_element=>\@table);

#převaděč tabulky na XML
my $XML_Simple=XML::Simple->new
(
	XMLDecl=>$XML_header,
	NoSort=>0,
	RootName=>$root_element,
	#OutputFile=>$output_file,
);

#převedení
print($XML_Simple->XMLout(\%final));

#konec
exit(0);

