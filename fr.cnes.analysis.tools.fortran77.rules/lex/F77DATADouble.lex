/************************************************************************************************/
/* i-Code CNES is a static code analyzer.                                                       */
/* This software is a free software, under the terms of the Eclipse Public License version 1.0. */ 
/* http://www.eclipse.org/legal/epl-v10.html                                                    */
/************************************************************************************************/ 

/*****************************************************************************/
/* This file is used to generate a rule checker for F77.Data.Double rule.	 */
/* For further information on this, we advise you to refer to RNC manuals.	 */
/* As many comments have been done on the ExampleRule.lex file, this file    */
/* will restrain its comments on modifications.								 */
/*																			 */
/*****************************************************************************/

package fr.cnes.analysis.tools.fortran77.rules;

import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.File;
import java.util.LinkedList;
import java.util.List;

import org.eclipse.core.runtime.Path;

import fr.cnes.analysis.tools.analyzer.exception.JFlexException;
import fr.cnes.analysis.tools.analyzer.datas.AbstractChecker;
import fr.cnes.analysis.tools.analyzer.datas.CheckResult;

%%

%class F77DATADouble
%extends AbstractChecker
%public
%line
%column
%ignorecase

%function run
%yylexthrow JFlexException
%type List<CheckResult>


%state COMMENT, NAMING, NEW_LINE, LINE, DBL_STATE, NUMBER

COMMENT_WORD = \!         | c          | C     | \*
FREE_COMMENT = \!
FUNC         = FUNCTION   | function
PROC         = PROCEDURE  | procedure
SUB          = SUBROUTINE | subroutine
PROG         = PROGRAM    | program
MOD          = MODULE     | module
TYPE		 = {FUNC}     | {PROC}	   | {SUB} | {PROG} | {MOD}
DOUBLE		 = DOUBLE[\ ]+PRECISION | double[\ ]+precision
LOGIC	     = \.AND\.	  | \.OR\.	   | \.NEQV\.		| \.XOR\.	|
			   \.EQV\.	  | \.NOT\.	
RELAT		 = \.LT\.	  | \.LE\.	   | \.EQ\.			|\.NE\.		|
			   \.GT\.	  | \.GE\.
OPERATOR     = {LOGIC}    | {RELAT}
SPACE		 = [\ \t\r]
EQUAL		 = \= 
EVAL		 = {EQUAL}	  | {OPERATOR}
VAR		     = [a-zA-Z][a-zA-Z0-9\_]*
NUMD		 = [0-9]+\.[0-9]*"D"   |  [0-9]*\.[0-9]+"D" 
NUM			 = [0-9]+\.[0-9]*      |  [0-9]*\.[0-9]+
SIMBOL		 = \& 		  | \$ 		   | \+			| [A-Za-z][\ ]	| \.	| [0-9]		| \~
																
%{
	String location = "MAIN PROGRAM";
	/** List that contains all the double precision variables**/
	List<String> identifiers = new LinkedList<String>();
	/** Current variabe to analize **/
	String variable = "";
	/** Evluation boolean to detect if an error can be thrown or not **/
	boolean eval = false; 
	/** name of the file parsed */
	private String parsedFileName;
	
	public F77DATADouble() {
    }

	@Override
	public void setInputFile(final File file) throws FileNotFoundException {
		super.setInputFile(file);
		this.parsedFileName = file.toString();
        this.zzReader = new FileReader(new Path(file.getAbsolutePath()).toOSString());
	}
	
	/** If the var found is a double precision, check is there is a number after that
	    oterwise, there can't be an error **/
	private void findVar(String word) {
		variable = word;
		if (identifiers.contains(word)) 
			yybegin(NUMBER);
		else
			yybegin(LINE);
	}
	

%}

%eofval{
    return getCheckResults();
%eofval}

%%          

				{FREE_COMMENT}	{yybegin(COMMENT);}

<COMMENT>   	\n             	{yybegin(NEW_LINE);}  
<COMMENT>   	.              	{}

/** Create the location variable and clear the variables to avoid overload **/
<NAMING>		{VAR}			{location = location + " " + yytext();
								 identifiers.clear();
								 yybegin(COMMENT);}
<NAMING>    	\n             	{identifiers.clear(); 
								 yybegin(NEW_LINE);}
<NAMING>    	.              	{}

/** Initial, new line and lnie state toidentify the variable declaration and  
    use of this variables **/
<YYINITIAL>  	{COMMENT_WORD} 	{yybegin(COMMENT);}
<YYINITIAL>		{TYPE}        	{location = yytext(); yybegin(NAMING);}
<YYINITIAL>		{DOUBLE}       	{yybegin(DBL_STATE);}
<YYINITIAL>		{VAR}       	{findVar(yytext());}
<YYINITIAL> 	\n             	{yybegin(NEW_LINE);}
<YYINITIAL> 	.              	{yybegin(LINE);}

<NEW_LINE>  	{COMMENT_WORD} 	{yybegin(COMMENT);}
<NEW_LINE>		{TYPE}        	{location = yytext(); yybegin(NAMING);}
<NEW_LINE>		{DOUBLE}       	{yybegin(DBL_STATE);}
<NEW_LINE>		{VAR}       	{findVar(yytext());}
<NEW_LINE>  	\n             	{}
<NEW_LINE>  	.              	{yybegin(LINE);}


<LINE>			{TYPE}        	{location = yytext(); yybegin(NAMING);}
<LINE>			{DOUBLE}       	{yybegin(DBL_STATE);}
<LINE>			{VAR}       	{findVar(yytext());}
<LINE>      	\n             	{yybegin(NEW_LINE);}
<LINE>      	.              	{}

/** Storage all the double precision variables to **/
<DBL_STATE>		{TYPE}        	{location = yytext(); yybegin(NAMING);}
<DBL_STATE>		{VAR}			{identifiers.add(yytext());}
<DBL_STATE>		\n[\ ]{1,5}{SIMBOL}	{}
<DBL_STATE>		\n				{yybegin(NEW_LINE);}
<DBL_STATE>		.				{}

/** If a double precision variable is followed by a number without D is an error and it is an evaluation, 
    otherwise not.
    An evaluation means that there is a comparison (EQ, LT, ...) or assignation ( = ), between a variable and
    a number **/
<NUMBER>		{NUMD}			{if(eval) { eval = false; yybegin(LINE); }}
<NUMBER>		{NUM}			{if(eval) { eval = false; setError(location,"The double precision variable " +
																   variable + " is not correctly initialized. It misses the character D in its declaration.",
																   yyline+1);
										    yybegin(LINE);} }
<NUMBER>		{EVAL}			{eval = true;}
<NUMBER>		{VAR}			{eval = false; yybegin(LINE);}
<NUMBER>		{SPACE}			{}
<NUMBER>		\n				{eval = false; yybegin(NEW_LINE);}
<NUMBER>		.				{eval = false; yybegin(LINE);}

				[^]            {
								
				                    final String errorMessage = "Analysis failure : Your file could not be analyzed. Please verify that it was encoded in an UNIX format.";
				                    throw new JFlexException(this.getClass().getName(), parsedFileName,
				                                    errorMessage, yytext(), yyline, yycolumn);
								}