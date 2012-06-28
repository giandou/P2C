%top{
 /**
 * +-----------------------------------------------------------------------+
 * | P2C - scanner.l                                                       |
 * +-----------------------------------------------------------------------+
 * |                                                                       |
 * |  Autori: Vito Manghisi                                                |
 * |          Gianluca Grasso                                              |
 * +-----------------------------------------------------------------------+
 *	
 * Input file per Flex, generatore dello scanner per il traduttore da PHP a C
 *
 */
  #include <stdio.h>
  #include "parser.h"

}
%{
/** Dichiarazione delle variabili intere definite nelle inclusioni per la gestione degli errori */
extern int _error, _warning;

/** Funzione che effettua un ritaglio di una stringa 
  * ed aggiunge un terminatore '\0'
  *
  * Argomenti:
  * 	literal: la stringa da manipolare
  * 	start: intero che indica l'offset iniziale dal quale copiare
  *	end: intero che indica la lunghezza da considerare
  * Ritorna una nuova copia della stringa ritagliata secondo i parametri
  */
char * nullTerminateTheLexem(char * literal, const int start, const int end){
  char * str = (char *)malloc(sizeof(char)*((end-start)+1));
  int i = start;
  while(i <= (end-start)){
    str[i-start] = literal[i++];
  }
  str[end-start] = '\0';
  return str;
}

/** Funzione che effettua l'escape dei newline in una stringa 
 *  Parametri:
 *	str: la stringa da controllare
 *  Ritorna una copia con i newline escaped
 */
char * escapeNewline(char * str){
  if(yy_flex_debug)
    printf("--Esecuzione della funzione escapeNewline sulla stringa %s: \n", str);
  char * s = (char *) strdup(str);  
  int i = -1 , j = 0, count = 0, lung = strlen(s), found = 0;
  while( ++i < lung ){ 	//conta i newline effettivi
     if ( s[i] == 0x0D && s[i+1] == 0x0A ){
	i += 2; 
	found = 1;
     }
     else if( s[i] == 0x0A || s[i] == 0x0D ){
        count++;
	found = 1;
     }
  }
  i = 0;
  if(found){
    int dim = count + lung;
    char * snew = (char *) malloc(sizeof(char) * dim);
    int cicla = -1;
    while( ++cicla < lung ){
      if ( s[i] == 0x0D && s[i+1] == 0x0A ){
	snew[j++] = '\\';
	snew[j++] = 'n';
	i += 2;
      }
      else if ( s[i] == 0x0A || s[i] == 0x0D ){
	snew[j++] = '\\';
	snew[j++] = 'n';
	i++;
      }
      else
	snew[j++]=s[i++];
    }    
    snew[dim] = '\0';
    return snew; 
  }
  else{
    return s;
  } 
}

/** Funzione che effettua l'escape dei doppi apici in una stringa 
 *  Parametri:
 *	str: la stringa da controllare
 *  Ritorna una copia con doppi apici escaped
 */
char * escapeDoubleQuote(char * str){
  if(yy_flex_debug)
    printf("--Esecuzione della funzione escapeNewline sulla stringa %s: \n", str);
  char * s = (char *) strdup(str);  
  int i = -1 , j = 0, count = 0, lung = strlen(s), found = 0;
  while( ++i < lung ){ 	//conta i newline effettivi
     if( s[i] == 0x22 ){
        count++;
	found = 1;
     }
  }
  i = 0;
  if(found){
    int dim = count + lung;
    char * snew = (char *) malloc(sizeof(char) * dim);
    int cicla = -1;
    while( ++cicla < lung ){
     if ( s[i] == 0x22 ){
	snew[j++] = '\\';
	snew[j++] = '"';
	i++;
      }
      else
	snew[j++]=s[i++];
    }    
    snew[dim] = '\0';
    return snew; 
  }
  else{
    return s;
  } 
}

%}
/* Parte dedicata alla definizione degli stati iniziali; (%x) indica che sono esclusivi,
 * ovvero non attivi simultaneamente. Flex avvia la scansione dallo stato INITIAL, richiamabile
 * mediante l'istruzione BEGIN(INITIAL) o BEGIN(0).
 */

/* Stato indicante la scansione di letterali e token PHP. Si ricorda che il linguaggio permette
 * che all'interno di un sorgente vi sia del testo puro, ovvero codice HTML, quindi questo stato
 * starà ad indicare che la scansione sta avvendo all'intero di uno script PHP (cioè dentro i tag
 * di apertura e chiusura dello script PHP <?php ?>)
 */
%x ST_IN_SCRIPTING

/* Stato indicante la scansione all'interno di stringhe delimitate da virgolette (") */
%x ST_DOUBLE_QUOTES

/* Stato indicante la scansione all'interno di strighe delimitate da singolo apice */
%x ST_SINGLE_QUOTE

/* Stato indicante la scansione all'interno di un blocco di commenti */ 
%x ST_COMMENT

/* Stato indicante la scansione in un blocco di commenti multilinea, tipo documentazione del codice */
%x ST_DOC_COMMENT

/* Stato indicante la scansione in una singola linea di commento */
%x ST_ONE_LINE_COMMENT

/** Imposta lo scanner per mantenere il numero della linea di input corrente nella variabile globale yylineno */
%option yylineno

/** Imposta lo scanner per NON chiamare la procedura yywrap() al termine del file di input */
%option noyywrap

/** Imposta Flex per gestire pile di stati */
%option stack

/** Imposta Flex in modalità debug */
%option debug

%{
/** variabile che tiene traccia della linea di input corrente */
int lineno = 1;
/** indica la riga nel file sorgente dove è stato aperto un commento */
int comment_start_line = 0;
%}

/** Definizione della regex che matcha uno o più digit numeriche*/
LNUM [0-9]+
/** Definizione della regex che matcha una floating del tipo [+|-][n].n oppure [+|-]n.[n], 
    dove n è un intero da 0 a 9, e [] indica opzionalità. */
DNUM ([0-9]*[\.][0-9]+)|([0-9]+[\.][0-9]*)
/** Definizione della regex per le label costanti nella forma _ALFA[ALFA|0-9], cioè che iniziano con un underscore 
    seguito da almeno un letterale char maiuscolo, seguito opzionalmente da letterali maiuscoli o numeri da 0 a 9*/
CONST_LABEL ("_")([A-Z][A-Z0-9_]*)("_")
/** Definizione della regex per le label delle variabili, costituite da almeno un letterale a carattere maiuscolo o minuscolo da
    A a Z, un underscore, oppure un carattere nel range UNICODE \x7f-\xff */
LABEL [a-zA-Z_\x7f-\xff][a-zA-Z0-9_\x7f-\xff]*
/** Definizione per tabulazioni, whitespace e carriage return */
WHITESPACE [ \n\r\t]+
/** Definizione per tabulazioni e spazi vuoti
TABS_AND_SPACES [ \t]* */
/** Definizione dei token del linguaggio PHP */
TOKENS [;:,.\[\]()|^&+-/*=%!~$<>?@]
/** Definizione regex per token quali [,],{,},$ che possono comparire in una stringa */
ENCAPSED_TOKENS [\[\]{}$]
/** Definizione per letterali validi all'interno di una stringa */
ESCAPED_AND_WHITESPACE [\\\n\t\r #'.:;,() |^&+-/*=%!~<>?@]+
/** Definizione per letterali costituiti da qualsiasi carattere alfanumerico o newline */
ANY_CHAR (.|[\n])
/** Definizione per terminatori di linea Unix o Windows */
NEWLINE ("\r"|"\n"|"\r\n")

%%

 /** Regola per il terminale per la definizione di funzioni PHP */  
<ST_IN_SCRIPTING>"function" {
  return T_FUNCTION;
}

 /** Regola per il terminale if */  
<ST_IN_SCRIPTING>"if" {
  return T_IF;
}

 /** Regola per il terminale elseif */
<ST_IN_SCRIPTING>"elseif" {
  return T_ELSEIF;
}
 /** Regola per il terminale else */
<ST_IN_SCRIPTING>"else" {
  return T_ELSE;
}

 /** Regola per il terminale while */
<ST_IN_SCRIPTING>"while" {
  return T_WHILE;
}

 /** Regola per il terminale do */
<ST_IN_SCRIPTING>"do" {
  return T_DO;
}

 /** Regola per il terminale for */
<ST_IN_SCRIPTING>"for" {
  return T_FOR;
}

 /** Regola per il terminale switch */
<ST_IN_SCRIPTING>"switch" {
  return T_SWITCH;
}

 /** Regola per il terminale case */
<ST_IN_SCRIPTING>"case" {
  return T_CASE;
}

 /** Regola per il terminale default */
<ST_IN_SCRIPTING>"default" {
  return T_DEFAULT;
}

 /** Regola per il terminale break */
<ST_IN_SCRIPTING>"break" {
  return T_BREAK;
}

 /** Regola per il terminale continue */
<ST_IN_SCRIPTING>"continue" {
  return T_CONTINUE;
}

 /** Regola per il terminale echo (per la stampa di una variabile o costante) */
<ST_IN_SCRIPTING>"echo" {
  return T_ECHO;
}

<ST_IN_SCRIPTING>"return" {
	return T_RETURN;
}

 /** Regola per il terminale define (per la definizione di una costante) */
<ST_IN_SCRIPTING>"define" {
  return T_DEFINE;
}

 /** Regola per il terminale array (per la dichiarazione esplicita di un array) */
<ST_IN_SCRIPTING>"array" {
  return T_ARRAY;
}

 /** Regola per il terminale ++ (auto incremento) */
<ST_IN_SCRIPTING>"++" {
  return T_INC;
}

 /** Regola per il terminale -- (auto decremento) */
<ST_IN_SCRIPTING>"--" {
  return T_DEC;
}

 /** Regola per il terminale == (uguaglianza) */
<ST_IN_SCRIPTING>"==" {
  return T_IS_EQUAL;
}

 /** Regola per i terminali != o <> (disuguaglianza) */
<ST_IN_SCRIPTING>"!="|"<>" {
  return T_IS_NOT_EQUAL;
}

 /** Regola per il terminale <= (disuguaglianza minore o uguale) */
<ST_IN_SCRIPTING>"<=" { 
  return T_IS_SMALLER_OR_EQUAL;
}

 /** Regola per il terminale >= (disuguaglianza maggiore o uguale) */
<ST_IN_SCRIPTING>">=" {
  return T_IS_GREATER_OR_EQUAL;
}

 /** Regola per il terminale += (incremento autoriferito */
<ST_IN_SCRIPTING>"+=" {
   return T_PLUS_EQUAL;
}

 /** Regola per il terminale -= (decremento autoriferito) */
<ST_IN_SCRIPTING>"-=" {
  return T_MINUS_EQUAL;
}

 /** Regola per il terminale *= (moltiplicazione autoriferita) */
<ST_IN_SCRIPTING>"*=" {
  return T_MUL_EQUAL;
}

 /** Regola per il terminale /= (divisione intera autoriferita) */
<ST_IN_SCRIPTING>"/=" {
  return T_DIV_EQUAL;
}

 /** Regola per il terminale %= (resto della divisione intera autoriferito) */
<ST_IN_SCRIPTING>"%=" {
  return T_MOD_EQUAL;
}

 /** Regola per il terminale || (OR logico) */
<ST_IN_SCRIPTING>"||" {
  return T_BOOLEAN_OR;
}

 /** Regola per il terminale && (AND logico) */
<ST_IN_SCRIPTING>"&&" {
  return T_BOOLEAN_AND;
}

 /** Regola per il terminale OR (bitwise OR) */
<ST_IN_SCRIPTING>"OR" {
  return T_LOGICAL_OR;
}

 /** Regola per il terminale AND (bitwise AND) */
<ST_IN_SCRIPTING>"AND" {
  return T_LOGICAL_AND;
}

 /** Regola per i terminali token del linguaggio PHP */
<ST_IN_SCRIPTING>{TOKENS} {
  return yytext[0];
}
 /** Regola per il terminale di apertira dello scope o blocco */
<ST_IN_SCRIPTING>"{" {
  return '{';
}

 /** Regola per il terminale di chiusura dello scope o blocco */
<ST_IN_SCRIPTING>"}" {
  return '}';
}

 /** Regola per non terminali costituiti da interi */
<ST_IN_SCRIPTING>{LNUM} {
  yylval.id = nullTerminateTheLexem(yytext,0,yyleng);
  return T_LNUMBER;
}

  /** Regola per numeri decimali */
<ST_IN_SCRIPTING>{DNUM} {
  yylval.id = nullTerminateTheLexem(yytext,0,yyleng);
  return T_DNUMBER;
}

 /** Regola per identificare l'inizio di uno script PHP */
<INITIAL>"<?php"([ \t]|{NEWLINE}) {
  if (yytext[yyleng-1] == '\n') {
    lineno++;
  }
  BEGIN(ST_IN_SCRIPTING);
  return T_INIT;
}

 /** Regola per identificare il termine di uno script PHP */
<ST_IN_SCRIPTING>("?>"){NEWLINE}? {
  BEGIN(INITIAL);
  return T_FINAL;
}

 /** Regola per identificare una variabile */
<ST_IN_SCRIPTING,ST_DOUBLE_QUOTES>"$"{LABEL} {
  yylval.id = ( char * )strdup( yytext + 1 );
  return T_VARIABLE;
}

 /** Regola per identificare una variabile mal definita */
<ST_IN_SCRIPTING,ST_DOUBLE_QUOTES>"$"([0-9]|{TOKENS})([0-9]|{TOKENS})*{LABEL} {
  printf("\033[01;31m[ERRORE LESSICALE] Riga %i: e' stato corretto il nome della variabile \"%s\"\033[00m", yylineno, ( char * )strdup( yytext + 1 ) );
  char * str = ( char * )strdup( yytext + 1 );
  int num = 0;
  while( *str )
  {
    if( ! isalpha( *str ) ) //conta i caratteri non alfabetici
      num++;
    str++;
  }
  // stampa del nome corretto
  printf("\033[01;31m in \"%s\".\033[00m", ( char * )strdup( yytext + num + 1 )); 
  /*Salta il simbolo "$" ed i caratteri non validi (numeri o token) conteggiati prima */
  yylval.id = ( char * )strdup( yytext + num + 1 );
  _warning+=1;
  return T_VARIABLE;
}

 /** Regola per identificare una costante */
<ST_IN_SCRIPTING,ST_DOUBLE_QUOTES>{CONST_LABEL} {
  yylval.id = ( char * )strdup( yytext );
  return T_CONSTANT;
}


 /** Regola per identificare una stringa nello script PHP */
<ST_IN_SCRIPTING>{LABEL} {
  yylval.id = ( char * )strdup( yytext );
  return T_FUNCTION_NAME;
}

 /** Regola per identificare una costante in una stringa PHP */
<ST_DOUBLE_QUOTES>{LABEL} {
  yylval.id = ( char * )strdup( yytext );
  return T_STRING;
}

 /** Regola per identificare un whitespace nello script PHP */
<ST_IN_SCRIPTING>{WHITESPACE} {
  /* elimina gli spazi, le tabulazioni e i newline nel codice contando le righe */
  int i;
  for (i = 0; i < yyleng; i++) {
    if (yytext[i] == '\n') {
      lineno++;
    }
  }
}

 /** Regola per identificare l'avvio di un commento in linea */
<ST_IN_SCRIPTING>"#"|"//" {
  BEGIN(ST_ONE_LINE_COMMENT);
  yymore();
}

 /** Regola per l'escape dei letterali speciali PHP in un commento in linea */
<ST_ONE_LINE_COMMENT>"?"|">" {
  yymore();
}

 /** Regola per escapare i terminatori PHP in un commento in linea */
<ST_ONE_LINE_COMMENT>[^\n\r?%>]+{ANY_CHAR} {
  switch ( yytext[yyleng - 1] ) {
    case '?': case '%': case '>':
      yyless(yyleng-1);
      yymore();
    break;
    case '\n':
      lineno++;
    default:
      BEGIN(ST_IN_SCRIPTING);
  }
}

 /** Regola per il newline in un commento in linea */
<ST_ONE_LINE_COMMENT>{NEWLINE} {
  BEGIN(ST_IN_SCRIPTING);
  lineno++;
}

 /** Regola per escapare il terminatore script PHP in un commento in linea */
<ST_ONE_LINE_COMMENT>"?>" {
  yymore();
}

 /** Regola per identificare l'avvio di un commento multilinea in stile documentazione */
<ST_IN_SCRIPTING>"/**"{WHITESPACE} {
  comment_start_line = lineno;
  BEGIN(ST_DOC_COMMENT);
  yymore();
}

 /** Regola per identificare l'avvio di un commento multilinea */
<ST_IN_SCRIPTING>"/*" {
  comment_start_line = lineno;
  BEGIN(ST_COMMENT);
  yymore();
}

 /** Regola per ignorare qualsiasi carattere diverso da '*' in un commento */
<ST_COMMENT,ST_DOC_COMMENT>[^*]+ {
  yymore();
}

 /** Regola per concludere un commento multilinea */
<ST_DOC_COMMENT>"*/" {
  BEGIN(ST_IN_SCRIPTING);
}

 /** Regola per concludere un commento multilinea */
<ST_COMMENT>"*/" {
  BEGIN(ST_IN_SCRIPTING);
}

 /** Regola per ignorare '*' in un commento multilinea */
<ST_COMMENT,ST_DOC_COMMENT>"*" {
  yymore();
}

 /** Regola identificare una costante tra apici */
<ST_IN_SCRIPTING>([']({CONST_LABEL})[']) {
  yylval.id = nullTerminateTheLexem(yytext, 1 , yyleng - 1);
  return T_CONSTANT;
}

 /** Regola identificare una costante tra apici */
<ST_IN_SCRIPTING>(["]({CONST_LABEL})["]) {
  yylval.id = nullTerminateTheLexem(yytext, 1 , yyleng - 1);
  return T_CONSTANT;
}

 /** Regola identificare una stringa tra virgolette */
<ST_IN_SCRIPTING>(["]([^$_"\\]|("\\".))*["]) {
  yylval.id = escapeNewline(yytext);
  return T_CONSTANT_ENCAPSED_STRING;
}

 /** Regola identificare una stringa costante di letterali tra singolo apice */
<ST_IN_SCRIPTING>([']([^'\\]|("\\".))*[']) {
  /* sostituisce i singli apici con le virgolette per evitare problemi 
     con la definizione delle costanti. */
  char * s = strdup(yytext);
  s[0] = '"';
  s[yyleng-1] = '"';
  yylval.id = s;
  return T_CONSTANT_ENCAPSED_STRING;
}

 /** Regola identificare le virgolette ed avviare lo stato esclusivo ST_DOUBLE_QUOTES */
<ST_IN_SCRIPTING>["] {
  BEGIN(ST_DOUBLE_QUOTES);
  return '\"';
}

 /** Regola identificare gli apici ed avviare lo stato esclusivo ST_SINGLE_QUOTE */
<ST_IN_SCRIPTING>['] {
  BEGIN(ST_SINGLE_QUOTE);
  return '\'';
}

 /** Regola per letterali validi all'interno di una stringa */
<ST_DOUBLE_QUOTES>{ESCAPED_AND_WHITESPACE} {
  yylval.id = strdup( yytext );
  return T_ENCAPSED_AND_WHITESPACE;
}

 /** Regola per letterali validi all'interno di una stringa */
<ST_SINGLE_QUOTE>([^'\\]|\\[^'\\])+ {
  return T_ENCAPSED_AND_WHITESPACE;
}

 /** Regola identificare il backquote all'interno di una stringa */
<ST_DOUBLE_QUOTES>[`]+ {
  return T_ENCAPSED_AND_WHITESPACE;
}

 /** Regola per includere il simbolo speciale $ in una stringa */
<ST_DOUBLE_QUOTES>"$"[^a-zA-Z_\x7f-\xff{] {
  if (yyleng == 2) {
    yyless(1);
  }
  return T_CHARACTER;
}

  /** Regola per il ritono di un numero nel contesto di una stringa */
<ST_DOUBLE_QUOTES>{LNUM} { 
  yylval.id = nullTerminateTheLexem(yytext,0,yyleng);
  return T_NUM_STRING;
}

 /** Regola per token quali [,],{,},$ che possono comparire in una stringa */
<ST_DOUBLE_QUOTES>{ENCAPSED_TOKENS} {
  return yytext[0];
}

<ST_DOUBLE_QUOTES>"\\{" {
  return T_STRING;
}

<ST_SINGLE_QUOTE>"\\'" {
  return T_CHARACTER;
}

<ST_SINGLE_QUOTE>"\\\\" {
  return T_CHARACTER;
}

<ST_DOUBLE_QUOTES>"\\\"" {
  return T_CHARACTER;
}

<ST_DOUBLE_QUOTES>"\\"[0-7]{1,3} {
  return T_CHARACTER;
}

<ST_DOUBLE_QUOTES>"\\x"[0-9A-Fa-f]{1,2} {
  return T_CHARACTER;
}

<ST_DOUBLE_QUOTES>["] {
  BEGIN(ST_IN_SCRIPTING);
  return '\"';
}

<ST_SINGLE_QUOTE>['] {
  BEGIN(ST_IN_SCRIPTING);
  return '\'';
}

 /** Segnalazione di un commento non terminato correttamente */
<ST_COMMENT,ST_DOC_COMMENT><<EOF>> {
  printf( "\n\033[01;33m[WARNING] Riga %d: commento non terminato correttamente.\033[00m\n", comment_start_line );
  return 0;
}

  /** Caratteri che in uno script PHP o nel contesto di una stringa
  * non costituiscono un token valido vengono segnalati con un warning
  * e vengono ignorati senza passaggio di token o valori semantici al parser
  */
<ST_IN_SCRIPTING,ST_DOUBLE_QUOTES,ST_SINGLE_QUOTE>{ANY_CHAR} {
  char * res = escapeNewline(yytext);
  _warning+=1;
  printf( "\n\033[01;33m[WARNING] Riga %d: carattere inatteso '%s', Parsing State '%d'",yylineno, res, YYSTATE );
}

  /** Carattere non all'interno di uno script PHP vengono ritornati come token
  * che indica un insieme di caratteri appartenenti a codice HTML
  */
<INITIAL>(([^<]|"<"[^?%s<]){1,400})|"<s"|"<" {
  char * res = escapeNewline(yytext);
  res = escapeDoubleQuote(res);
  yylval.id = res;
  return T_INLINE_HTML;
}
 /** Regola per il ritorno del token speciale che indica la fine del file scansionato */
<INITIAL,ST_IN_SCRIPTING><<EOF>> {
	BEGIN(INITIAL);
	return T_END_OF_FILE;
}


%%
