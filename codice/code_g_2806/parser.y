%{

  /**
  * +---------------------------------------------------------------------+
  * | P2C -- parser.y                                                     |
  * +---------------------------------------------------------------------+
  * |                                                                     |
  * |  Autori:  Vito Manghisi                                             |
  * |           Gianluca Grasso                                           |
  * +---------------------------------------------------------------------+
  * 
  *  Input file per Bison, generatore del parser per il traduttore da P2C
  *
  */

 #include "symbolTable.h"
 #define YYDEBUG 1

 /* Prototipo della funzione yyerror per la  visualizzazione degli errori sintattici. */
 void yyerror( const char *s );
 /* Il numero riga segnalato dalla variabile yylineno di Flex. */
 extern int yylineno;
 /** Variabile di controllo per il debug di Flex */
 extern int yy_flex_debug;
 /** Contatore usato per il conteggio dei parametri nella dichiarazione di una funzione */
 int actualNumParams = 0;
 /** Puntatori a file, il primo di input a bison, il secondo di uscita della traduzione C */
 FILE * yyin, * f_ptr; 
 /* Manipola il tipo corrente di una variabile o costante */ 
 char * current_type; 
 /* Contiene l'indice di un elemento di un array */
 char * index_element = NULL; 
 /* Contatore di errori, di warnings e di elementi di un array (che definiscono la sua dimensione.) */
 int dim = 0; 
 /** Puntatore al file di output del parser definito nel file di inclusioni */
 char * fout;
 /* Flag usati per discriminare la dichiarazione di un  array, una variabile in lettura o scrittura. */
 bool array, read; 

%}

  // imposta Bison attendere 9 conflitti di shift-riduzione
/*  %expect 9 */

 //Associatività degli operatori e dei Token
 %left ','
 %left T_LOGICAL_OR
 %left T_LOGICAL_AND
 %left '=' T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_MOD_EQUAL
 %left '?' ':'
 %left T_BOOLEAN_OR
 %left T_BOOLEAN_AND
 %nonassoc <id> T_IS_EQUAL T_IS_NOT_EQUAL
 %nonassoc '<' T_IS_SMALLER_OR_EQUAL '>' T_IS_GREATER_OR_EQUAL
 %left '+' '-'
 %left '*' '/' '%'
 %right T_INC T_DEC
 %left T_ELSEIF
 %left T_ELSE
 %left ')'
// Definizioni dei TOKEN
 %token <id> T_LNUMBER 				//token per numeri interi
 %token <id> T_DNUMBER 				//token per numeri decimali
 %token <id> T_STRING 				//token per le stringhe
 %token <id> T_VARIABLE 			//token per le variabili
 %token <id> T_CONSTANT 			//token per le costanti
 %token <id> T_NUM_STRING 			//token per numeri in stringhe
 %token <id> T_ENCAPSED_AND_WHITESPACE 		//token per whitespace e metacaratteri nelle stringhe
 %token <id> T_CONSTANT_ENCAPSED_STRING		//token per stringhe costanti
 %token <id> T_INLINE_HTML
 %token <id> T_FUNCTION_NAME
 %token T_IF
 %token T_CHARACTER
 %token T_ECHO
 %token T_DO
 %token T_WHILE
 %token T_FOR
 %token T_SWITCH
 %token T_CASE
 %token T_DEFAULT
 %token T_BREAK
 %token T_CONTINUE
 %token T_ARRAY
 %token T_DEFINE
 %token T_WHITESPACE
 %token T_INIT
 %token T_FINAL
 %token T_FUNCTION
 %token T_RETURN
 %token T_END_OF_FILE
 %token '~' '.' '[' ']' '(' ')' '|' '^' '&' '!' '$' '@'

// Definizione del tipo di dato per i valori semantici
%union{
  char *id;
}
// Dichiarazione dei simboli che utilizzano il tipo di dato con contenuto semantico
%type <id> variable r_variable w_variable element_array encaps_var common_scalar;

%error-verbose

%%


start:
  state_inscripting top_statement_list
 ;

epsilon: /* vuoto */
 ;

state_inscripting:
  /*T_INIT { avviaScritturaFileTraduzione(); } 
  | */possible_html
  ;
  
end:
 T_FINAL { ntab--; }
 | T_FINAL { ntab--; } possible_html
/*  | T_END_OF_FILE { insertNewLine(f_ptr); fprintf( f_ptr, "}" ); YYABORT; } */
 ;

possible_html:
   T_INIT { avviaScritturaFileTraduzione(); } 
   |T_INLINE_HTML 
    { 
      avviaScritturaFileTraduzione();   
      insInLista(&frasi,$1); 
      printEcho( f_ptr, NULL, frasi); 
      liberaStrutture(); 
      insertNewLine(f_ptr); 
    }
  | possible_html T_INIT
 ;

top_statement_list:
 top_statement_list top_statement
 | epsilon
 ;

top_statement: 
 epsilon { printTab( f_ptr, ntab ); } statement 
 | function_declaration_statement
 ;

inner_statement_list:
 inner_statement_list { printTab( f_ptr, ntab ); } inner_statement
 | epsilon
 ;

inner_statement:
  epsilon { printTab( f_ptr, ntab ); } statement
 ;

statement:
 unticked_statement 
 ; 

unticked_statement:
 '{' inner_statement_list { ntab++; } '}' 
 | T_DEFINE '(' T_CONSTANT ',' common_scalar ')' 
    { 
      liberaStrutture( ); 
      addElement( $3, "constant", current_type, $5, 0, yylineno ); 
      printConstant( f_ptr, $3, current_type, $5 ); 
    } 
    ';'
 | T_DEFINE '(' T_CONSTANT ',' T_CONSTANT ')' 
    { 
      check( $5, 0, yylineno, true ); 
      liberaStrutture( ); 
      addElement( $3, "constant", current_type, $5, 0, yylineno ); 
      printConstant( f_ptr, $3, current_type, $5 ); 
    } 
    ';'
 | T_DEFINE '(' T_STRING ',' common_scalar ')' ';' { yyerror("[ERRORE SINTATTICO] Errore nella definizione della costante"); }
 | T_DEFINE '(' T_CONSTANT_ENCAPSED_STRING ',' common_scalar ')' ';' { yyerror("[ERRORE SINTATTICO] Errore nella definizione della costante"); }
 | T_DEFINE '(' error ')' ';' { yyerror("[ERRORE SINTATTICO] Errore nella definizione della costante, parentesi mancante_1"); }
 | T_DEFINE error ')' ';'{ yyerror("[ERRORE SINTATTICO] Errore nella definizione della costante, parentesi mancante_2"); }
 | T_DEFINE error ';' { yyerror("[ERRORE SINTATTICO] Errore nella definizione della costante"); }
 | T_DEFINE '(' error end { insertNewLine(f_ptr); fprintf( f_ptr, "}" ); YYABORT; }
 | T_IF '(' expr ')' { printIF( f_ptr, espressioni ); liberaStrutture( ); } 
    statement elseif_list else_single 
 | T_IF '(' error ')' { printIF( f_ptr, espressioni ); liberaStrutture( ); } 
    statement elseif_list else_single 
    { 
      yyerror( "ERRORE SINTATTICO: espressione nel costrutto IF non accettata" ); 
    }
 | T_IF error expr ')' statement elseif_list else_single 
    { 
      yyerror( "ERRORE SINTATTICO: '(' mancante nel costrutto IF" ); 
    }
 | T_IF '(' expr error 
    { 
      yyerror("ERRORE SINTATTICO: ')' mancante nel costrutto IF, correzione effettuata in automatico" ); 
      printIF( f_ptr, espressioni ); 
      liberaStrutture( ); 
      ntab++; 
    } 
    statement elseif_list else_single
 | T_WHILE '(' expr ')' 
    { 
      printWhile( f_ptr, espressioni ); 
      liberaStrutture( ); 
    }
    while_statement { fprintf( f_ptr, "}" ); insertNewLine(f_ptr); }
 | T_WHILE '(' error ')' while_statement 
    { 
      yyerror( "ERRORE SINTATTICO: espressione nel costrutto WHILE non accettata" ); 
    }
 | T_WHILE error expr ')' 
    { 
      printWhile( f_ptr, espressioni ); 
      liberaStrutture( ); 
    } 
    while_statement 
    { 
      yyerror( "ERRORE SINTATTICO: '(' mancante nel costrutto WHILE , correzione effettuata in automatico" ); 
    }
 | T_DO 
    { 
      fprintf( f_ptr, "do {" ); 
      insertNewLine(f_ptr); 
      ntab++; 
    } 
   statement 
   T_WHILE 
    { 
      ntab--; 
      printTab( f_ptr, ntab ); 
      fprintf( f_ptr, "} while( " ); 
    } 
   '(' expr ')' 
    { 
      printExpression( f_ptr, espressioni ); 
      fprintf( f_ptr, " );" ); 
      insertNewLine(f_ptr); 
      liberaStrutture( ); 
    } 
    ';'
 | T_FOR
    '(' 
    for_expr { fprintf(f_ptr,";"); insertNewLine(f_ptr); printTab(f_ptr,ntab); fprintf( f_ptr, "for( " ); }
    ';' { fprintf( f_ptr, "; " ); }
    for_expr_condition { printExpression( f_ptr, espressioni ); liberaStrutture( ); }
    ';' { fprintf( f_ptr, "; " ); }
    for_expr_update { liberaStrutture( );  }
    ')' { fprintf( f_ptr, " ) {" ); insertNewLine(f_ptr); }
    for_statement { printTab( f_ptr, ntab); fprintf( f_ptr, "}" ); insertNewLine(f_ptr); liberaStrutture( ); }
 | T_FOR error for_statement ';' { yyerror( "ERRORE SINTATTICO: un argomento del costrutto FOR non è corretto" ); }
 | T_SWITCH '(' expr ')' 
    { 
      printSwitch( f_ptr, espressioni ); 
      liberaStrutture( ); 
    } 
    switch_case_list { printTab( f_ptr, ntab ); ntab--; fprintf( f_ptr, "}" ); insertNewLine(f_ptr); }
 | T_SWITCH error expr ')' 
    { 
      printSwitch( f_ptr, espressioni ); 
      liberaStrutture( ); 
    } 
    switch_case_list 
    { 
      yyerror( "ERRORE SINTATTICO: '(' mancante nel costrutto SWITCH, correzione effettuata in automatico," ); 
    }
 | T_BREAK ';' { fprintf( f_ptr, "break;" ); insertNewLine(f_ptr);}
 | T_CONTINUE ';' { fprintf( f_ptr, "continue;" ); insertNewLine(f_ptr);}
 | T_RETURN ';' { fprintf( f_ptr,"return;" ); insertNewLine(f_ptr); }
 | T_RETURN { buildReturnStatement(yylineno); } expr ';' { 
    printReturnStatement(yylineno); //scrittura dell'espressione di ritorno
    liberaStrutture(); 
  }
 | T_ECHO echo_expr_list ';'
    {
      printEcho( f_ptr, espressioni, frasi ); 
      //Stampa gli avvisi se notice è uguale a 5 ( avviso riservato alla funzione echo ).
      if( notice == 5 ) {
	printf( "\033[01;33mRiga %i. %s\033[00m", yylineno, warn[ notice ] );
	_warning++;
	notice = -1;
      }
      liberaStrutture( );
    }
 | T_ECHO echo_expr_list error
    {
      yyerror("[ERRORE SINTATTICO]: punto e virgola mancante nella espressione di ECHO. Corretto!");
      printEcho( f_ptr, espressioni, frasi ); liberaStrutture( );
      //Stampa gli avvisi se notice è uguale a 5 ( avviso riservato alla funzione echo ).
      if( notice == 5 ) {
	printf( "\033[01;33mRiga %i. %s\033[00m", yylineno, warn[ notice ] );
	_warning++;
	notice = -1;
      }
      liberaStrutture( );
    }
/*  | T_ECHO error ';' { yyerror ( "[ERRORE SINTATTICO]: argomento della funzione ECHO errato" ); liberaStrutture( ); } */
 | T_ECHO error { yyerror ( "[ERRORE SINTATTICO]: argomento della funzione ECHO errato" ); liberaStrutture( ); }
 | expr ';' {
    if( contaElementi( espressioni ) == 1 )
      printExpression( f_ptr, espressioni );
    liberaStrutture();
    if(lastFunctionCall==NULL)
      fprintf( f_ptr,";" );

    insertNewLine(f_ptr);
    //Stampa gli avvisi se notice è diverso da -1 e da 5 ( 5 è un avviso riservato alla funzione echo ).
    if( notice != -1 && notice != 5 ) {
      printf( "[WARNING] Riga %i. %s", yylineno, warn[ notice ] );
      _warning++;
      notice = -1;
      }
  }
 | ';' /* empty statement */
 | end
 ;

for_statement:
 epsilon statement { ntab--; }
 ;

switch_case_list:
 '{' { ntab++; } case_list '}'
 ;

case_list:
 epsilon
 | case_list T_CASE { ntab++; printTab( f_ptr, ntab ); fprintf( f_ptr, "case " ); }
   expr { printExpression( f_ptr, espressioni ); liberaStrutture( ); } 
   case_separator { insertNewLine(f_ptr); }
   inner_statement_list { ntab--; }
 | case_list T_DEFAULT { ntab++; printTab( f_ptr, ntab ); fprintf( f_ptr, "default" ); } 
   case_separator { insertNewLine(f_ptr); }
   inner_statement_list { ntab--; }
 ;

case_separator:
 ':' { fprintf( f_ptr, ":" ); }
 | ';' { fprintf( f_ptr, ";" ); }
 ;

while_statement:
 epsilon { printTab( f_ptr, ntab ); ntab++; } statement { ntab--; }
 ;

elseif_list:
 epsilon { printTab( f_ptr, ntab ); ntab--; fprintf( f_ptr, "}" ); insertNewLine(f_ptr); }
 | elseif_list T_ELSEIF '(' expr ')' { printIfElse( f_ptr, espressioni ); liberaStrutture( ); ntab++; }
   statement { insertNewLine(f_ptr); printTab( f_ptr, ntab ); ntab--; fprintf( f_ptr, "}" ); insertNewLine(f_ptr); }
 ;

else_single:
 epsilon { insertNewLine(f_ptr); }
 | T_ELSE { fprintf( f_ptr, " else {" ); insertNewLine(f_ptr); ntab++; } 
   statement { printTab( f_ptr, ntab ); ntab--; fprintf( f_ptr, "}" ); insertNewLine(f_ptr); }
 ;

echo_expr_list:
 '"' encaps_list '"'
 | T_STRING { echoCheck( $1, 0, yylineno ); }
 | T_CONSTANT { echoCheck( $1, 0, yylineno ); }
 | T_CONSTANT_ENCAPSED_STRING { insInLista( &espressioni, $1 ); }
 | r_variable { echoCheck( $1, index_element, yylineno ); }
 ;

for_expr:
 epsilon
 | expr
 | expr ',' {fprintf(f_ptr,"; "); } expr
 ;

for_expr_condition:
 epsilon
 | expr
 | expr ',' {insInLista(&espressioni,", "); } expr
 ;

for_expr_update:
 epsilon
 | expr_without_variable { printExpression( f_ptr, espressioni ); }
 | expr_without_variable { printExpression(f_ptr,espressioni); liberaStrutture(); } ',' {fprintf(f_ptr,", "); } expr_without_variable { printExpression(f_ptr,espressioni); }
 ;

function_declaration_statement:
		T_FUNCTION
		  T_FUNCTION_NAME { 
		    inFunctionDeclaration = true;
		    addFunctionElement( $2, "main", yylineno );
		    lastFunction = strdup($2);
		  }
		  '(' parameter_list ')'{  
		      printTab(f_ptr, ntab);
		      printDeclarationFunctionHeader(lastFunction);
		      inFunctionDeclaration = false;
		  } 
		  '{' inner_statement_list  
		  '}' {
		      fprintf(f_ptr,"}"); 
		      inFunctionDeclaration = false;
		      free(lastFunction);
		      lastFunction = NULL;
		      insertNewLine(f_ptr);
		  }
 ;

parameter_list:
  epsilon
  | T_VARIABLE { 
      addElementInFunctionSymbolTable(lastFunction, $1, "variable", "int", "0",  yylineno);
    }
  | T_VARIABLE 
    { 
      addElementInFunctionSymbolTable(lastFunction, $1, "variable", "int", "0",  yylineno); 
    } 
    ',' 
    parameter_list
 ;

function_call:
  T_FUNCTION_NAME { 
	  functionSymbolTablePointer f = findFunctionElement($1); 
	  if( f ){ 
	    lastFunctionCall = f->nomeFunzione; 
	  }else{
	    stampaMsg("\n[ERRORE FATALE] Riga ","red");
	    stampaMsg(itoa(yylineno),"yellow");
	    stampaMsg(": chiamata a funzione non definita \"","red");
	    stampaMsg($1,"yellow");	   
	    stampaMsg("\"\n Parsing Fallito.\n","red");
	    abort();
	  }
	}
    '('
     function_call_parameter_list
    ')' { 
      updateReturnType(lastFunctionCall,yylineno);
      printFunctionCall($1,yylineno);
      functionSymbolTablePointer f = findFunctionElement($1);
      if(f->chiamata == false)
	f->chiamata = true;
      if(actualNumParams != (f->numeroParam-1) ){
	stampaMsg("\n[ERRORE FATALE] Riga ","red");
	stampaMsg(itoa(yylineno),"yellow");
	stampaMsg(": numero di parametri attuali della chiamata alla funzione \"","red");
	stampaMsg(lastFunctionCall,"yellow");
	stampaMsg("\" non corretto\nParsing Fallito.\n","red");
	_error+=1;
      }
      actualNumParams = 0;
    }
 ;

function_call_parameter_list:
  epsilon 
 | function_call_parameter
 | function_call_parameter ',' function_call_parameter_list
 ;


function_call_parameter:
  r_variable 
    {
      actualNumParams +=1; 
      functionTypesUpdate(lastFunctionCall,$1,actualNumParams,0,yylineno);
    }
 | T_CONSTANT 
    { 
      check( $1, 0, yylineno, true ); 
      actualNumParams +=1;
      functionTypesUpdate(lastFunctionCall,$1,actualNumParams,1,yylineno);
      espressioni = NULL;
    }
 | common_scalar 
    { 
      actualNumParams +=1; 
      functionTypesUpdate(lastFunctionCall,"scalar",actualNumParams,2,yylineno);
      espressioni = NULL;
    }

 | expr_without_variable { 
      actualNumParams +=1;
      functionTypesUpdate(lastFunctionCall,"expression",actualNumParams,3,yylineno); 
      espressioni = NULL; 
    }
/* | w_variable '=' expr  { actualNumParams +=1;
      functionTypesUpdate(lastFunctionCall,$1,actualNumParams,0,yylineno);  }*/
;

expr_without_variable:
  T_CONSTANT '=' expr 
    { 
      isConstant( $1, yylineno ); 
      yyerror( "ERRORE SEMANTICO: non è consentito assegnare un valore a una costante" ); 
    }
 | w_variable '=' expr 
    {
      if( array ) {
	arrayTypeChecking( listaTipi, 0, NULL, yylineno );
	printArrayDeclaration( f_ptr, $1, current_type, espressioni );
	addElement( $1, "array", current_type, NULL, dim, yylineno );
	array = false;
      } else {
	if(lastFunctionCall!=NULL){ // assegnazioni di valore di ritorno da funzioni
	  functionSymbolTablePointer f = findFunctionElement(lastFunctionCall);
	  if( f )
	    check( f->nomeRitorno, index_element, yylineno, true );
	}
	  current_type = typeChecking( listaTipi );
	  contaElementi( listaTipi ) > 0 ? current_value = "0" : current_value;
	  printAssignment( f_ptr, 0, $1, current_type, espressioni, false );	  
	  addElement( $1, "variable", current_type, current_value, 0, yylineno );
      }
      lastFunctionCall = NULL;
      liberaStrutture();
    }
 | element_array '=' 
    {
      fprintf( f_ptr, "%s[%s]", $1, index_element ); checkIndex( $1, index_element, yylineno ); 
    }
    expr 
    {
      // La chiamata alla funzione checkElement effettua un controllo dei tipi.
      // Se il controllo ha esito positivo l'istruzione di assegnazione sarà stampata nel file tradotto 
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 0, $1, current_type, espressioni, true );
      liberaStrutture( );
  }
 | w_variable '=' error 
    { 
      insInLista(&espressioni,$1); 
      fprintf(f_ptr," /* riga sorgente %d: il costrutto presenta errori */", yylineno); 
      insertNewLine(f_ptr);
      yyerror("ERRORE SINTATTICO: espressione errata"); 
    }
 | error '=' expr { yyerror("ERRORE SINTATTICO: parte sinistra dell'espressione non riconosciuta"); }
 | w_variable T_PLUS_EQUAL expr 
    {
      contaElementi( listaTipi ) > 1 ? current_value = "0" : current_value;
      printAssignment( f_ptr, 1, $1, current_type, espressioni, false );
      addElement( $1, "variable", current_type, current_value, dim, yylineno );
      liberaStrutture( );
    }
 | element_array T_PLUS_EQUAL 
    { 
      fprintf( f_ptr, "%s[%s]", $1, index_element );
      checkIndex( $1, index_element, yylineno ); } expr {
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 1, $1, current_type, espressioni, true );
      liberaStrutture( );
    }
 | w_variable T_MINUS_EQUAL expr 
    {
      contaElementi( listaTipi ) > 1 ? current_value = "0" : current_value;
      printAssignment( f_ptr, 2, $1, current_type, espressioni, false );
      addElement( $1, "variable", current_type, current_value, dim, yylineno );
      liberaStrutture( );
    }
 | element_array T_MINUS_EQUAL 
    { 
      fprintf( f_ptr, "%s[%s]", $1, index_element );
      checkIndex( $1, index_element, yylineno ); 
    } 
    expr 
    {
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 2, $1, current_type, espressioni, true );
      liberaStrutture( );
    }
 | w_variable T_MUL_EQUAL expr 
    {
      contaElementi( listaTipi ) > 1 ? current_value = "0" : current_value;
      printAssignment( f_ptr, 3, $1, current_type, espressioni, false );
      addElement( $1, "variable", current_type, current_value, dim, yylineno );
      liberaStrutture( );
    }
 | element_array T_MUL_EQUAL 
    { 
      fprintf( f_ptr, "%s[%s]", $1, index_element ); checkIndex( $1, index_element, yylineno ); 
    } 
    expr 
    {
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 3, $1, current_type, espressioni, true );
      liberaStrutture( );
    }
 | w_variable T_DIV_EQUAL expr 
    {
      contaElementi( listaTipi ) > 1 ? current_value = "0" : current_value;
      printAssignment( f_ptr, 4, $1, current_type, espressioni, false );
      addElement( $1, "variable", current_type, current_value, dim, yylineno );
      liberaStrutture( );
    }
 | element_array T_DIV_EQUAL 
    { 
      fprintf( f_ptr, "%s[%s]", $1, index_element ); 
      checkIndex( $1, index_element, yylineno ); 
    } 
    expr 
    {
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 4, $1, current_type, espressioni, true );
      liberaStrutture( );
    }
 | w_variable T_MOD_EQUAL expr 
    {
      contaElementi( listaTipi ) > 1 ? current_value = "0" : current_value;
      printAssignment( f_ptr, 5, $1, current_type, espressioni, false );
      addElement( $1, "variable", current_type, current_value, dim, yylineno );
      liberaStrutture( );
    }
 | element_array T_MOD_EQUAL 
    { 
      fprintf( f_ptr, "%s[%s]", $1, index_element ); 
      checkIndex( $1, index_element, yylineno ); 
    } 
    expr 
    {
      checkElement( $1, index_element, yylineno, false );
      printAssignment( f_ptr, 5, $1, current_type, espressioni, true );
      liberaStrutture( );
    }
 | variable T_INC 
    {     
      check( $1, index_element, yylineno, true ); 
      typeChecking( listaTipi ); 
      aggEspressioneIncremeto(element, espressioni, "++", 1); 
    }
 | T_INC variable 
    {     
      check( $2, index_element, yylineno, true );      
      typeChecking( listaTipi );
      aggEspressioneIncremeto(element, espressioni, "++", 0); 
    }
 | r_variable T_DEC 
    { 
/*       insInLista(&listaTipi,"int");   */
      check( $1, index_element, yylineno, true ); 
      typeChecking( listaTipi );
      insInLista( &espressioni, "--" ); 
    }
 | T_DEC 
    { 
      insInLista( &espressioni, "--" ); 
    } 
    variable 
    { 
      check( $3, index_element, yylineno, true ); 
      typeChecking( listaTipi );
    }
 | expr T_BOOLEAN_OR { insInLista( &espressioni, " || " ); } expr
  | expr T_BOOLEAN_OR ')' { yyerror( "ERRORE SINTATTICO: (||) secondo termine dell'espressione mancante" ); abort(); }
 | expr T_BOOLEAN_AND { insInLista( &espressioni, " && " ); } expr
  | expr T_BOOLEAN_AND ')' { yyerror( "ERRORE SINTATTICO: (&&) secondo termine dell'espressione mancante" ); } 
 | expr T_LOGICAL_OR { insInLista( &espressioni, " OR " ); } expr
  | expr T_LOGICAL_OR ')' { yyerror( "ERRORE SINTATTICO: (OR) secondo termine dell'espressione mancante" ); } 
 | expr T_LOGICAL_AND { insInLista( &espressioni, " AND " ); } expr
  | expr T_LOGICAL_AND ')' { yyerror( "ERRORE SINTATTICO: (AND) secondo termine dell'espressione mancante" ); } 
 | expr T_IS_EQUAL { insInLista( &espressioni, " == " ); } expr
  | expr T_IS_EQUAL ')' { yyerror( "ERRORE SINTATTICO: (==) secondo termine dell'espressione mancante" ); } 
 | expr T_IS_NOT_EQUAL { insInLista( &espressioni, " != " ); } expr
  | expr T_IS_NOT_EQUAL ')' { yyerror( "ERRORE SINTATTICO: (!=) secondo termine dell'espressione mancante" ); } 
 | expr '<' { insInLista( &espressioni, " < " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '<' ')' { yyerror( "ERRORE SINTATTICO: (<) secondo termine dell'espressione mancante" ); } 
 | expr T_IS_SMALLER_OR_EQUAL { insInLista( &espressioni, " <= " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr T_IS_SMALLER_OR_EQUAL ')' { yyerror( "ERRORE SINTATTICO: (<=) secondo termine dell'espressione mancante" ); }
 | expr '>' { insInLista( &espressioni, " > " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '>' ')' { yyerror( "ERRORE SINTATTICO: (>) secondo termine dell'espressione mancante" ); }
 | expr T_IS_GREATER_OR_EQUAL { insInLista( &espressioni, " >= " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr T_IS_GREATER_OR_EQUAL ')' { yyerror( "ERRORE SINTATTICO: (>=) secondo termine dell'espressione mancante" ); }
 | expr '+' { insInLista( &espressioni, " + " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '+' ')' { yyerror( "ERRORE SINTATTICO: (+) secondo termine dell'espressione mancante" ); }
  | expr '+' ';' { yyerror( "ERRORE SINTATTICO: (+) secondo termine dell'espressione mancante" ); }
 | expr '-' { insInLista( &espressioni, "-" ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '-' ')' { yyerror( "ERRORE SINTATTICO: (-) secondo termine dell'espressione mancante" ); }
  | expr '-' ';' { yyerror( "ERRORE SINTATTICO: (-) secondo termine dell'espressione mancante" ); }
 | expr '*' { insInLista( &espressioni, " * " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '*' ')' { yyerror( "ERRORE SINTATTICO: (*) secondo termine dell'espressione mancante" ); }
  | expr '*' ';' { yyerror( "ERRORE SINTATTICO: (*) secondo termine dell'espressione mancante" ); }
 | expr '/' { insInLista( &espressioni, " / " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '/' ')' { yyerror( "ERRORE SINTATTICO: (/) secondo termine dell'espressione mancante" ); }
  | expr '/' ';' { yyerror( "ERRORE SINTATTICO: (/) secondo termine dell'espressione mancante" ); }
 | expr '%' { insInLista( &espressioni, " % " ); } expr { current_type = typeChecking( listaTipi ); }
  | expr '%' ')' { yyerror( "ERRORE SINTATTICO: (%) secondo termine dell'espressione mancante" ); }
  | expr '%' ';' { yyerror( "ERRORE SINTATTICO: (%) secondo termine dell'espressione mancante" ); }
 | '(' { insInLista( &espressioni, "(" ); } expr ')' { insInLista( &espressioni, ")" ); }
 | '+' { insInLista(&espressioni,"+"); } expr %prec T_INC 
 | '-' { insInLista(&espressioni,"-"); } expr %prec T_INC 
 | expr '?' expr ':' expr
 | T_ARRAY { array = true; dim = 0; } '(' array_pair_list ')'
 | function_call 
 ;

 common_scalar:
 T_LNUMBER {
    if( !read ) {
      current_value = $1; current_type = "int";
      if( array || index_element != NULL ) {
	dim++;
      }
    }
    insInLista( &listaTipi, "int" );
    insInLista( &espressioni, strdup($1) );
 }
 | T_DNUMBER {
    if( !read ) {
      current_value = $1; current_type = "float";
      if( array || index_element != NULL ) {
	dim++;
      }
    }
    insInLista( &listaTipi, "float" );
    insInLista( &espressioni, $1 );
 }
 | T_CONSTANT_ENCAPSED_STRING 
   {
    if( !read ) {
      current_value = $1; current_type = "char *";
      if( array || index_element != NULL ) {
	dim++;
      }
    }
    insInLista( &listaTipi, "char *" );
    insInLista( &espressioni, $1 );
 }
 | T_STRING 
  {
    current_type = isConstant($1, yylineno);
    if( !read ) {
      current_value = $1;
      if( array || index_element != NULL ) {
	dim++;
      }
    }
    insInLista( &listaTipi, current_type );
    insInLista( &espressioni, $1 );
  }
 ;

scalar:
 common_scalar
 | '"' encaps_list '"'
 | '\'' encaps_list '\''
 ;

possible_comma:
 epsilon
 | ','
 ;

expr:
 r_variable { if(inFunctionDeclaration == false) check( $1, index_element, yylineno, true ); }
 | T_CONSTANT { check( $1, 0, yylineno, true ); }
 | expr_without_variable
 | scalar
 ;

r_variable:
 variable { $$ = $1; read = true; }
 | element_array
 ;

w_variable:
 variable { $$ = $1; read = false; }
 ;

variable:
 T_VARIABLE { $$ = $1; }
 ;

element_array:
 T_VARIABLE '[' T_LNUMBER ']' { $$ = $1; index_element = $3; }
 | T_VARIABLE '[' T_VARIABLE ']' { $$ = $1; index_element = $3; }
 ;

array_pair_list:
 epsilon
 | non_empty_array_pair_list possible_comma
 ;

non_empty_array_pair_list:
 non_empty_array_pair_list ',' { insInLista( &espressioni, ", " ); } scalar
 | scalar
 ;

encaps_list:
 encaps_list encaps_var { echoCheck( $2, index_element, yylineno ); }
 | encaps_list T_STRING { insInLista( &frasi, $2 ); }
 | encaps_list T_NUM_STRING { insInLista( &frasi, $2 ); }
 | encaps_list T_ENCAPSED_AND_WHITESPACE { insInLista( &frasi, $2 ); }
 | epsilon
 ;

encaps_var:
 T_VARIABLE { $$=$1; index_element = 0; }
 | T_VARIABLE '[' T_NUM_STRING ']' { $$=$1; index_element = $3; }
 | T_VARIABLE '[' T_VARIABLE ']' { $$=$1; index_element = $3; }
 | T_CONSTANT { $$=$1; index_element = 0; }
 ;


 %%

 /** Estensione della funzione yyerror di Bison */
 void yyerror( const char *s ) {
    _error++;
    stampaMsg("\n[ERRORE FATALE] Riga ","red");
    stampaMsg(itoa(yylineno),"yellow");
    stampaMsg(": ","red");
    stampaMsg(s,"red");
 }

/** Procedura di avvio del parser per un file in input */
void startParsing(char * nomeFile){  
  // apertura in lettura del file php in input
  if( (yyin = fopen(nomeFile,"r")) != NULL ){
    stampaMsg("Parsing del file: ", "green");
    stampaMsg(nomeFile,"yellow");
    stampaMsg("\n","yellow");
    // impostazione del nome file C in uscita
    fout = (char*) malloc( strlen(nomeFile)-2);	
    strncpy(fout,nomeFile,strlen(nomeFile)-3);
    strncat(fout,"c",1);
    stampaMsg("Nome del file di output: ", "green");
    stampaMsg(fout, "yellow");
    stampaMsg("\n","none");
    // Avvio del parser
    yyparse();
//chiusura main del file di traduzione
insertNewLine(f_ptr); fprintf( f_ptr, "}" );
    // Stampa delle ST
    stampaFunctionSymbolTable(0);
    stampaSymbolTable(symbolTable, "MAIN");
    // Report del processo di parsing
    if( _error == 0 && _warning == 0 ) {
      stampaMsg("\nParsing del file ","green"); 
      stampaMsg(nomeFile,"yellow");
      stampaMsg(" riuscito.\n","green"); 
    } 
    else if ( _error == 0 && _warning != 0 ) {
      stampaMsg("\nParsing del file ","yellow"); 
      stampaMsg(nomeFile,"yellow");
      stampaMsg(" riuscito con Warning n^ ","yellow");
      char * numwarn = (char *) malloc(sizeof(char) * _warning);
      sprintf(numwarn,"%d",_warning);
      stampaMsg(numwarn, "red");
      stampaMsg("\n", "red");
    }
    else {
      stampaMsg("\nE' fallito il parsing del file ","red");
      stampaMsg(nomeFile,"yellow");
      stampaMsg(", con errori num^ ","red");
      stampaMsg(itoa(_error), "red");
      stampaMsg("\n", "red");
      eliminaFile(f_ptr);
    }
    // inizializzazione strutture interne ed eliminazione delle Symbol Table
    liberaStrutture();
    eliminaSymbolTables();
  }
  else { // in caso non sia stato possibile leggere il file di input stampa un errore
    stampaMsg("\nERRORE, file ","red"); 
    stampaMsg(nomeFile,"yellow");
    stampaMsg(" non trovato.\n", "red");
  }
}

/** Entry point del Traduttore P2C: inizia il processo di analisi e traduzione avviando 
  * la funzione Bison yyparse()
  * Argomenti:
  * 	argc: numero argomenti passati da riga di comando
  *	argv: array di stringe dei parametri passati a riga di comando 
  *
  * SYNOPSIS: p2c [-dp] [-dl] [-log] nomeFile.php [nomeSecondoFile.php ...]
  *	Parametri:
  *		-dp: abilita il debug verboso del parser generato da Bison
  *		-dl: abilita il debug verboso dello scanner generato da Flex
  *		-log: abilita il redirezionamento dello stdout e stderr 
  *		      verso il file di testo 'parselog.log'
  *
  * Ritorna 0 se l'esecuzione è andata a buon fine o 1 se la compilazione é fallita
  * 
  */

int main( int argc, char *argv[] ){ 
 ++argv; --argc; 	// esclusione nome eseguibile dai parametri
 int i;
 logging = false;
 if(argc > 0)
 {
    // forza ad off il debug di flex, per default abilitato
    yy_flex_debug = 0;
    // ciclo per controllare che vi sia almeno un file con ext PHP in input e per impostare le opzioni
    bool inputPHP = false;
    for( i = 0; i < argc; i++ ) 
    {
      if(strstr(argv[i],".php") != NULL)
      {
	  inputPHP = true;
	  continue;
      }
      if(strcmp(argv[i],"-dl") == 0)
      { //imposta il debug per flex se passato il parametro -dl
	yy_flex_debug = 1;
	continue;  
      }
      if(strcmp(argv[i],"-dp") == 0)
      { //imposta il debug per bison se passato il parametro -dp
	yydebug = 1;
	continue;	  
      }
      if(strcmp(argv[i],"-log") == 0)
      { //imposta il debug per bison se passato il parametro -log
	logging = true;
	continue;	  
      }
    }
    startLog();
    if(inputPHP == true)
    {
      for( i = 0; i < argc; i++ ) 
      {
	if(strstr(argv[i],".php") != NULL)
	{	  
	  startParsing(argv[i]); 
	  if( _error > 0)
	  {
	      stopLog();
	      logging = false;
	      stampaMsg("\n\nParsing fallito per uno o più file in input.\n", "red");   
	  }
	}
       }
    }
    else
    {
      stopLog();
      logging = false;
      stampaMsg("\nAttenzione è necessario passare come parametro un file con estensione php.\n\n", "red");
      exit(1);
    }
  stopLog();
  }
  else
  {
      stampaMsg("\nE' necessario passare come parametro almeno un file con estensione '.php'", "white");
      stampaMsg("\nSINOPSI:\n\t\t p2c [-dl|-dp|-log] nomefile.php [secondofile.php...]", "white" );
      stampaMsg("\n\t\t\t -dl = abilita il debug dello scanner", "white" );
      stampaMsg("\n\t\t\t -dp = abilita il debug del parser", "white" );
      stampaMsg("\n\t\t\t -log = abilita il logging nel file parserlog.log\n\n", "white" );
      exit(1);
  }
 return 0;
}