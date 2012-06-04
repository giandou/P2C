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

 /* L’opzione %union consente di specificare una varietà di tipi di dato che sono usati dalla
variabile yylval in Flex. L'unico tipo specificato è la stringa di caratteri. */
%union{
  char *id;
}

%type <id> variable r_variable w_variable element_array encaps_var common_scalar;

 /** Abilita il reporting verboso degli errori */
%error-verbose

%% 

start:
  state_inscripting top_statement_list
 ;

state_inscripting:
  T_INIT 
  ;
  
end:
 T_FINAL 
 ;

epsilon: /* simbolo vuoto = nessuna azione */
  ;

 top_statement_list:
 top_statement_list top_statement
 | epsilon
 ;

 top_statement: 
 epsilon  statement
 | function_declaration_statement
 ;

 inner_statement_list:
 inner_statement_list  inner_statement
 | epsilon
 ;

 inner_statement:
  epsilon  statement
  // | function_declaration_statement
 ;

 statement:
 unticked_statement
 ;

 unticked_statement:
 '{' inner_statement_list '}'
 | T_DEFINE '(' T_CONSTANT ',' common_scalar ')'  ';'
 | T_IF '(' expr ')'  statement elseif_list else_single 
/*  | T_IF '(' error ')' statement elseif_list else_single  */
/*  | T_IF error expr ')' statement elseif_list else_single  */
 | T_WHILE '(' expr ')' while_statement
 | T_WHILE '(' error ')' while_statement 
 | T_WHILE error expr ')' while_statement 
 | T_DO statement T_WHILE 
    '(' expr ')' ';'
 | T_FOR
    '(' 
    for_expr
    ';' 
    for_expr 
    ';' 
    for_expr 
    ')' 
    for_statement 
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
 | ';' /* empty statement */
 | end
 ;

 for_statement:
 epsilon statement 
 ;

 switch_case_list:
 '{' case_list '}'
 ;

 case_list:
 epsilon
 | case_list T_CASE 
   expr  
   case_separator 
   inner_statement_list 
 | case_list T_DEFAULT  
   case_separator 
   inner_statement_list 
 ;

 case_separator:
 ':' 
 | ';' 
 ;

 while_statement:
 epsilon statement 
 ;

 elseif_list:
 epsilon 
 | elseif_list T_ELSEIF '(' expr ')' 
   statement 
 ;

 else_single:
 epsilon 
 | T_ELSE  
   statement 
 ;

 echo_expr_list:
 '"' encaps_list '"'
 | T_CONSTANT 
 | T_CONSTANT_ENCAPSED_STRING 
 | r_variable 
 ;

 for_expr:
 epsilon
 | expr
 ;

 function_declaration_statement:
		T_FUNCTION 
		  T_STRING 
		  '(' parameter_list ')'
		  '{' inner_statement_list  
		  '}'
 ;

 parameter_list:
  epsilon
  | T_VARIABLE 
  | T_VARIABLE  ',' parameter_list
 ;

 function_call:
  T_STRING 
    '('
     function_call_parameter_list
    ')'
 ;

function_call_parameter_list:
  epsilon 
 | function_call_parameter
 | function_call_parameter ',' function_call_parameter_list
 ;


function_call_parameter:
  variable 
 | common_scalar 
 | T_CONSTANT 
;

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
 | scalar scalar
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

 expr:
 r_variable 
 | T_CONSTANT 
 | expr_without_variable
 ;

 r_variable:
 variable 
 ;

 w_variable:
 variable 
 ;

 variable:
 T_VARIABLE 
/*  | element_array */
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

 encaps_list:
 encaps_list encaps_var 
 | encaps_list T_STRING 
 | encaps_list T_NUM_STRING 
 | encaps_list T_ENCAPSED_AND_WHITESPACE 
 | epsilon
 ;

 encaps_var:
 T_VARIABLE 
 | T_VARIABLE '[' T_NUM_STRING ']' 
 | T_VARIABLE '[' T_VARIABLE ']' 
 | T_CONSTANT 
 ;


 %%