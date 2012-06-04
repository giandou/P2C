 //%expect 53
 //%glr-parser

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
 %token <id> T_SNUMBER				//token per numeri interi con segno
 %token <id> T_DNUMBER 				//token per numeri decimali
 %token <id> T_SDNUMBER 			//token per numeri decimali con segno
 %token <id> T_STRING 				//token per le stringhe
 %token <id> T_VARIABLE 			//token per le variabili
 %token <id> T_CONSTANT 			//token per le costanti
 %token <id> T_NUM_STRING 			//token per numeri in stringhe
 %token <id> T_ENCAPSED_AND_WHITESPACE 		//token per whitespace e metacaratteri nelle stringhe
 %token <id> T_CONSTANT_ENCAPSED_STRING		//token per stringhe costanti
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

 /* Specifica del tipo di dato usato dalla per la variabile yylval, usata dallo scanner
  * per memorizzare un valore associato a determinati token di ritorno 
  * Il tipo usato è rappresentato da una stringa */
%union{
  char *id;
}

/* Definizione del tipo per alcuni simboli della grammatica */
%type <id> variable r_variable w_variable element_array encaps_var common_scalar;

 /** Abilita il reporting verboso degli errori di Bison */
%error-verbose

%% 

/** Sequenza di simboli di avvio del parsing */
start:
  state_inscripting top_statement_list
 ;

/** Terminale di avvio del parsing corrispondente al lessema "<?php" */
state_inscripting:
  T_INIT 
  ;

/* Simbolo che genera il terminale identificante la fine del parsing, ovvero il lessema "?>" */
end:
 T_FINAL 
 ;

/* simbolo vuoto, nessuna azione */
epsilon: 
  ;

/* Statement iniziale, rappresentato da una lista di top_statement, eventualmente vuoto */
top_statement_list:
 top_statement_list top_statement
 | epsilon
 ;

/* Statement sub iniziale o dichiarazione di funzione */
top_statement: 
 epsilon statement
 | function_declaration_statement
 ;

/* Simbolo per uno statement generico */
statement:
 unticked_statement
 ;

/* Statement annidato, derivato da unticked_statement racchiuso tra parentesi graffe, eventualmente vuoto */
inner_statement_list:
 inner_statement_list  inner_statement
 | epsilon
 ;

/* Genalizzazione di uno statement annidato */
inner_statement:
  epsilon statement
 ;

/* Genalizzazione di uno statement, genera i principali statement PHP
 * tra quelli considerati nella restrizione alla grammatica PHP 
 */
unticked_statement:
 '{' inner_statement_list '}'
 | T_DEFINE '(' T_CONSTANT ',' common_scalar ')'  ';'
 | T_IF '(' expr ')'  statement elseif_list else_single 
/*  | T_IF '(' error ')' statement elseif_list else_single  */
/*  | T_IF error expr ')' statement elseif_list else_single  */
 | T_WHILE '(' expr ')' while_statement
 | T_WHILE '(' error ')' while_statement 
 | T_WHILE error expr ')' while_statement 
 | T_DO statement T_WHILE '(' expr ')' ';'
 | T_FOR '(' for_expr ';' for_expr ';' for_expr ')' for_statement 
 | T_FOR '(' error ';' error ';' error ')' for_statement 
 | T_SWITCH '(' expr ')' switch_case_list 
 | T_SWITCH error expr ')' switch_case_list 
 | T_BREAK ';' 
 | T_CONTINUE ';' 
 | T_RETURN ';' 
 | T_RETURN  expr ';' 
 | T_ECHO echo_expr_list ';' 
 | T_ECHO error ';' 
 | expr ';' 
 | ';' /* statement vuoto */
 | end
 ;

/* Generalizzazione di uno statement per il costrutto for */ 
for_statement:
 epsilon statement 
 ;

/* Simbolo che genera la lista dei case dello statement "switch" */
switch_case_list:
 '{' case_list '}'
 ;

/* Simbolo che genera il costrutto della lista dei case dello statement "switch-case" */
case_list:
 epsilon
 | case_list T_CASE expr case_separator inner_statement_list 
 | case_list T_DEFAULT case_separator inner_statement_list 
 ;

/* Generazione dei terminali di separazione di una lista di "case" */
case_separator:
 ':' 
 | ';' 
 ;

/* Generalizzazione di uno statement per il costrutto "while" */
while_statement:
 epsilon statement 
 ;

/* Generazione della stringa di simboli identificante un costrutto "elseif" */
elseif_list:
 epsilon 
 | elseif_list T_ELSEIF '(' expr ')' statement 
 ;

/* Generazione della stringa di simboli identificante un costrutto "else" */
else_single:
 epsilon 
 | T_ELSE statement 
 ;

/* Generazione dei simboli costituenti una lista di espressioni valide per un token "echo" */
echo_expr_list:
 '"' encaps_list '"'
 | T_CONSTANT 
 | T_CONSTANT_ENCAPSED_STRING 
 | r_variable 
 ;

/* Generazione di una espressione valida per un costrutto "for" */
for_expr:
 epsilon
 | expr
 ;

/* Generazione di una sequenza di simboli identificante una dichiarazione di funzione */
function_declaration_statement:
  T_FUNCTION T_STRING '(' parameter_list ')' '{' inner_statement_list '}'
 ;

/* Generazione di una lista di parametri formali per la firma di un prototipo di funzione */
parameter_list:
  epsilon
  | T_VARIABLE 
  | T_VARIABLE ',' parameter_list
 ;

/* Generazione della stringa di simboli identificante una chiamata a procedura o funzione */
function_call:
  T_STRING '(' function_call_parameter_list ')'
 ;

/* Generazione di una lista di parametri attuali per chiamata a procedura o funzione */
function_call_parameter_list:
  epsilon 
 | function_call_parameter
 | function_call_parameter ',' function_call_parameter_list
 ;

/* Produzione di simboli validi per i paramentri di una chiamata a funzione o procedura */
function_call_parameter:
  variable 
 | common_scalar 
 | T_CONSTANT 
;

/* Generazione delle espressioni valide principali del linguaggio PHP, tra quelle rientranti 
 * nella restrizione alla grammatica effettuata (vedi documentazione)
 */
expr_without_variable:
  T_CONSTANT '=' expr 
 | w_variable '=' expr
 | element_array '=' 
    expr 
 | error '=' expr  
 | w_variable T_PLUS_EQUAL expr 
 | element_array T_PLUS_EQUAL 
 | w_variable T_MINUS_EQUAL expr 
 | element_array T_MINUS_EQUAL 
 | w_variable T_MUL_EQUAL expr 
 | element_array T_MUL_EQUAL  expr 
 | w_variable T_DIV_EQUAL expr 
 | element_array T_DIV_EQUAL  expr 
 | w_variable T_MOD_EQUAL expr 
 | element_array T_MOD_EQUAL  expr 
 | variable T_INC 
 | T_INC variable 
 | r_variable T_DEC 
 | T_DEC variable 
 | expr T_BOOLEAN_OR  expr
  | expr T_BOOLEAN_OR error 
 | expr T_BOOLEAN_AND  expr
  | expr T_BOOLEAN_AND error  
 | expr T_LOGICAL_OR  expr
  | expr T_LOGICAL_OR error  
 | expr T_LOGICAL_AND  expr
  | expr T_LOGICAL_AND error  
 | expr T_IS_EQUAL  expr
  | expr T_IS_EQUAL error  
 | expr T_IS_NOT_EQUAL  expr
  | expr T_IS_NOT_EQUAL error  
 | expr '<' expr 
  | expr '<' error  
 | expr T_IS_SMALLER_OR_EQUAL expr 
  | expr T_IS_SMALLER_OR_EQUAL error 
 | expr '>' expr 
  | expr '>' error 
 | expr T_IS_GREATER_OR_EQUAL expr 
  | expr T_IS_GREATER_OR_EQUAL error 
 | expr '+' expr 
  | expr '+' error 
 | expr '-' expr 
  | expr '-' error 
 | expr '*' expr 
  | expr '*' error 
 | expr '/' expr 
  | expr '/' error 
 | expr '%' expr 
  | expr '%' error 
 | '(' expr ')' 
 | '(' error ')' 
 | '+'  expr %prec T_INC 
 | '-'  expr %prec T_INC 
 | expr '?' expr ':' expr
 | scalar
 | scalar scalar // ? motivo
 //| expr common_signed_scalar
// | common_signed_scalar
 | T_ARRAY  '(' array_pair_list ')'
 | function_call
 ;

common_signed_scalar:
  T_SNUMBER
  | T_SDNUMBER
 ;

common_scalar:
 T_LNUMBER 
 | T_DNUMBER 
 | T_CONSTANT_ENCAPSED_STRING 
 | T_STRING
 ;

scalar:
 common_scalar
 | common_signed_scalar
 | '"' encaps_list '"'
 | '\'' encaps_list '\''
 ;

/* possible_comma:
 epsilon
 | ','
 ;*/

/* Simbolo identificante la generica espressione valida per il linguaggio */
expr:
 r_variable 
 | T_CONSTANT 
 | expr_without_variable
 ;

/* Simbolo identificante una variabile acceduta in lettura */
r_variable:
 variable 
 ;

/* Simbolo identificante una variabile acceduta in scrittura */
w_variable:
 variable 
 ;

/* Simbolo identificante una generica variabile */
variable:
 T_VARIABLE 
/*  | element_array */ // utile o ridondato da expr_without_variable ?
 ;

element_array:
 T_VARIABLE '[' T_LNUMBER ']' 
 | T_VARIABLE '[' T_VARIABLE ']' 
 ;

array_pair_list:
 epsilon
 | non_empty_array_pair_list /*possible_comma*/
 ;

non_empty_array_pair_list:
 non_empty_array_pair_list ','  scalar
 | scalar
 ;

/* Generalizzazione di simboli terminali formanti una stringa in una espressione di "echo" valida */
encaps_list:
 encaps_list encaps_var 
 | encaps_list T_STRING 
 | encaps_list T_NUM_STRING 
 | encaps_list T_ENCAPSED_AND_WHITESPACE 
 | epsilon
 ;

/* Simboli consentiti in una espressione di "echo" come lariabili o costanti incapsulate in una stringa */
encaps_var:
 T_VARIABLE 
 | T_VARIABLE '[' T_NUM_STRING ']' 
 | T_VARIABLE '[' T_VARIABLE ']' 
 | T_CONSTANT 
 ;


 %%