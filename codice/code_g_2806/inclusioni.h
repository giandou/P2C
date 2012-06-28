  /**
  * +---------------------------------------------------------------------+
  * | P2C -- inclusioni.h                                                 |
  * +---------------------------------------------------------------------+
  * |                                                                     |
  * |  Autori:  Vito Manghisi                                             |
  * |           Gianluca Grasso                                           |
  * +---------------------------------------------------------------------+
  *
  * Header contenente funzioni di supporto al traduttore P2C
  *
  */

#include <stdio.h> 	/** Libreria inclusa per la gestione dei messaggi di errore semantico */
#include <string.h> 	/** Libreria inclusa per facilitare la manipolazione delle stringhe */
#include <ctype.h>	/** Libreria inclusa per l'utilizzo della funzione isdigit */
#include "uthash.h" 	/** gestione degli indici HASH per la gestione dei record della symbol symbolTable. */

#define NUM_CONSTANTS 3 /** Indica la dimensione della tabella delle costanti predefinite nel linguaggio PHP. */
#define NUM_WARNINGS 6 /** Indica la dimensione dell'array warn contenente tutti i messaggi di warning previsti. */


// *********** INIZIO SEZIONE DI DICHIARAZIONE STRUTTURE E VARIABILI **********

// *********** DICHIARAZIONE DI STRUTTURE E VARIABILI DI SUPPORTO
/** Nome del file in uscita */
char * fout;

/** Puntatore al file con la traduzione in linguaggio target C */
FILE * f_ptr;

/** Puntatore al file di log */
FILE * log_file;

/** Struttura per la definizione del tipo di dato booleano  */
typedef enum { false, true } bool;

/** Flag per identificare che si sta parsando la firma di una dichiarazione di funzione PHP */
bool inFunctionDeclaration = false;

/** Stringa che identifica il nome della funzione PHP corrente di cui si analizza la dichiarazione */
char * lastFunction;

/** Stringa che identifica il nome della funzione PHP corrente di cui si analizza la chiamata */
char * lastFunctionCall;

/** Contatori degli errori e dei warning */
int _error = 0, _warning = 0;

/** Flag per abilitare il logging su file */
bool logging;

/** Puntatori allo standard input ed error utili per il salvataggio e ripristono dopo il logging su file */
FILE * tmpStderr, * tmpStdout;

/** Array con tutti i possibili operatori di assegnazione. */
char *op_name[] = { "=", "+=", "-=", "*=", "/=", "%=" };

/** Procedura che inserirsce nel file passato un newline o un backslash, utilizzato per le macro C define  */
void insertNewLine ( FILE* f_ptr );

/** Nuovo tipo di dato "listaStringhe" definito come lista concatenata di stringhe. */
typedef struct listaStringhe
{
    char * stringa;
    struct listaStringhe * next;
} listaStringhe;

/** Lista di stringhe contenente i tipi delle variabili conivolte in una espressione, sulla quale 
 * solitamente si effettua di congruenza.
 */
listaStringhe *listaTipi;

/** Lista contenente gli i nomi dei token presenti in una espressione (variabili, array, costanti, operatori).
 *  Utile per scrivere espressioni complete nel file di traduzione
 */
listaStringhe *espressioni;

/** Lista contenente frasi o parole utile per scrivere in uscita intere frasi, associate ad espressioni.
 */
listaStringhe *frasi;

/** Quando viene sollevato un warning, questo indice viene settato ad un
numero appropriato. */
int notice = -1;

/** Contatore dei simboli di tabulazione. */
int ntab = 1;

/** Tale array contiene alcuni dei possibili messaggi di warning che il compilatore potrebbe
sollevare. L'accesso a uno specifico elemento è effettuato nel parser mediante l'indice notice.
*/
char* warn[NUM_WARNINGS]={ "ATTENZIONE: l'uso di un operando di tipo stringa su operatori binari non è corretto nel linguaggio target C.\n",
                           "ATTENZIONE: l'uso di un operando di tipo boolean su operatori binari non è corretto nel linguaggio target C.\n",
                           "ATTENZIONE: l'uso di un operando di tipo intero non è corretto nel linguaggio target C.\n",
                           "ATTENZIONE: l'uso di un operando di tipo float non è corretto nel linguaggio target C.\n",
                           "ATTENZIONE: l'uso di un elemento con offset negativo o superiore alla dimensione dell'array potrebbe causare problemi nel linguaggio target C.\n", 
			   "ATTENZIONE: la stampa di un elemento con offset negativo o superiore alla dimensione dell'array potrebbe causare problemi nel linguaggio target C.\n"
                             };

/** Definizione della struttura della tabella delle costanti predefinite del linguaggio PHP. */
typedef struct CONSTANTS_TABLE
{
    char *ctM; //parola maiuscola.
    char *ctm; //parola minuscola.
} CONSTANTS_TABLE;

/** La tabella delle costanti */
CONSTANTS_TABLE const_tab[ NUM_CONSTANTS ] = {
    { "TRUE","true" },
    { "FALSE","false" },
    { "NULL","null" }
};

// *********** DICHIARAZIONE DELLE SYMBOL TABLE E DI PUNTATORI DI SUPPORTO

/** Definizione della struttura della Symbol Table. Può memorizzare variabili, costanti o array. */
typedef struct {
    char *nomeToken; /**nome del token e chiave per UtHash (garantita univocità) */
    char *tipoToken; /**indica se è una "variable" o una "constant" o un "array" */
    char *type; /** il tipo primitivo tra int, float, char * o bool.*/
    char *value; /** valore variabile o zero per assegnazioni complesse o NULL per gli array.*/
    int dim; /** dimensione per un array */
    UT_hash_handle hh; /** Maniglia per Uthash */
} symbolTableEntry;

/** Dichiarazione tipo puntatore ad elemento della ST */
typedef symbolTableEntry *symbolTablePointer;
symbolTablePointer symbolTable = NULL;

/** Definizione della struttura della Symbol Table per le funioni */
typedef struct {
    char *nomeFunzione; /**nome del token funzione, univoco per usare Uthash */
    int numeroParam; /** il numero dei parametri */
    bool tipizzata; /** Flag per indicare se la tipizzazione del valore di ritorno è avvenuta o meno */
    bool chiamata; /** Flag per indicare se è stata effettuata una prima chiamata alla funzione */
    bool conRitorno; /** Flag per indicare se la funzione ritorna un valore */
    listaStringhe *tipiExprRitorno; /** Puntatori ad elementi coinvolti in una espressione di ritorno */
    char *tipoRitorno; /** Il tipo di ritorno della funione */
    char *nomeRitorno; /** Nome per la variabile di ritorno */
    char *scope; /** Lo scope di definizione della funzione */
    symbolTablePointer sf; /** Symbol symbolTable locale alla funzione */
    UT_hash_handle hh; /** Maniglia per Uthash */
} functionSymbolTableEntry;

/** Dichiarazione tipo puntatore ad elemento della ST per le funzioni */
typedef functionSymbolTableEntry *functionSymbolTablePointer;
functionSymbolTablePointer functionSymbolTable = NULL;

/** Dichiarazione tipo puntatore ad elemento della ST  */
symbolTablePointer element;
 
/** Dichiarazione di una strigna ustata per contenere il valore corrente di una variabile o costante */
char *current_value;

// *************** FINE SEZIONE DI DICHIARAZIONE STRUTTURE E VARIABILI ************
 

// *************** INIZIO DICHIARAZIONE DEI PROTOTIPI ************************

// *************** INIZIO SEZIONE DI DICHIARAZIONE DEI PROTOTIPI
// *************** PER LE FUNZIONI E PROCEDURE DI MANIPOLAZIONE DELLE ST

/** Procedura per l'inserimento di un elemento nella ST */
void addElement( char *nomeToken, char *tipoToken, char *tipoCorrente, char *valoreCorrente, int dimensione, int numeroRiga);
 
/** Procedura per l'inserimento di un elemento nella ST delle funzioni */
void addFunctionElement( char *nomeFunzione, char *scope, int numeroRiga );

/** Procedura per l'inserimento di un elemento nella ST interna alle funzioni */
void addElementInFunctionSymbolTable(char * nomeFunzione, char * nomeToken, char * tipoToken, char * tipo, char * value, int numeroRiga);

/** Funzione che trova e restituisce un elemento della Symbol Table. */
symbolTablePointer findElement( char *nomeToken );

/** Procedura per costruire lo statement di ritorno da una funzione */
void buildReturnStatement(int numeroRiga);

/** Funzione che trova e restituisce un elemento della Symbol Table per le funzioni. */
functionSymbolTablePointer findFunctionElement( char *nomeFunzione );

/** Procedura per l'aggiornamento del tipo di ritorno di una funzione nella ST per le funzioni */
void updateReturnType(char * nomeFunzione,int numeroRiga);

/** Funzione che rimuove un elemento dalla Symbol Table. */
void deleteElement( symbolTablePointer s_pnt );

/** Funzione che rimuove un elemento dalla Symbol Table per le Funzioni. */
void deleteFunctionElement( functionSymbolTablePointer f_pnt ); 

/** Procedura che aggiorna il tipo dei parametri di una funzione all'atto della chiamata */
void functionTypesUpdate(char * lastFunctionCall, char * parametroAttuale, int actualParamNum, int constantType,int numeroRiga);

/** Procedura per l'aggiornamento della lista dei tipi di ritorno nella ST per le funzioni */
void insInListaTipiRitorno();

/** Funzione dedita al controllo di contruenza dei tipi, torna il tipo congruente o stampa un messaggio di errore */
char * typeChecking( listaStringhe * listaTipi);

/** Funzione che controlla l'esistenza di elementi nella Symbol Talbe */
symbolTablePointer checkElement( char *nomeToken, char *offset, int numeroRiga, bool read );

/** Funzione per il controllo di esistenza di una variabile, costante o elemento di un array */
void check( char *nomeToken, char *offset, int numeroRiga, bool read );

/** Funzione che verifica l'esistenza nella ST del token passato come argomento. */
void echoCheck( char *nomeToken, char *offset, int numeroRiga );

/** Procedura che controlla se l'operazione di assegnazione di un elemento di un array
 *  sia di tipo congruente al tipo memorizzato nella ST */
void arrayTypeChecking( listaStringhe *listaTipi, short int contesto, symbolTablePointer element, int numeroRiga );

/** Procedura chiamata in caso di assegnazione di un valore a un elemento di un array */
void checkIndex( char *nomeToken, char *indice, int numeroRiga );

/** Procedura che elimina tutte le ST utilizzate */
void eliminaSymbolTables();

/** Procedura di supporto alla scrittura degli statement di pre e post incremento */
void aggEspressioneIncremeto(symbolTablePointer element, listaStringhe * pnt, const char * unary_op, int mode);

/** Procedura dedicata alla stampa a video gli elementi della Symbol Table passata come parametro */
void stampaSymbolTable(symbolTablePointer st, const char * intestazione);

/** Procedura per la stampa a video gli elementi della Symbol symbolTable delle funzioni */
void stampaFunctionSymbolTable(int stampaSTInterna);

// ******************* INIZIO SEZIONE DI DICHIARAZIONE DEI PROTOTIPI
// ******************* PER LE FUNZIONI E PROCEDURE DI GENERAZIONE DEL CODICE TARGET

/** Procedura che scrive una costante nella traduzione */
void printConstant( FILE* f_ptr, char *nomeConstante, char *tipo, char *valore );

/** Procedura che scrive nel file di traduzione gli elementi una espressione */
void printExpression( FILE * f_ptr, listaStringhe * espressioni );

/** Procedura che scrive nella traduzione la dichiarazione di un array */
void printArrayDeclaration( FILE * f_ptr, char * nome_array, char *tipo, listaStringhe * exp );

/** Procedura che scrive nella traduzione la dichiarazione di una variabile o di elementi di un array */
void printAssignment( FILE * f_ptr, int op_index, char * left_var, char * tipo, listaStringhe * exp, bool array );

/** Procedura che scrive nella traduzione l'istruzione condizionale if */
void printIF( FILE * f_ptr, listaStringhe * exp );

/** Procedura che scrive l'istruzione condizionale else if nel file di traduzione */
void printIfElse( FILE * f_ptr, listaStringhe * exp );

/** Procedura che genera l'istruzione while */
void printWhile( FILE * f_ptr, listaStringhe * exp );

/** Procedura che genera l'istruzione per il costrutto switch */
void printSwitch( FILE * f_ptr, listaStringhe * exp );

/** Funzione che realizza la funzione builtin echo di PHP, traducendola con una opportuna printf C */
void printEcho( FILE * f_ptr, listaStringhe * espressioni, listaStringhe * frasi );

/** Procedura la generazione di uno statement di ritorno da una funzione */
void printReturnStatement(int numeroRiga);

/** Procedura che scrive nel file di traduzione l'intestazione di una dichiarazione */
void printDeclarationFunctionHeader(char * nomeFunzione);

/** Procedura per la scrittura sul file di traduzione di una chiamata a funzione. */
void printFunctionCall(char * nomeFunzione, int numeroRiga);

/** Procedura che inserisce tabulazioni nel file di uscita della traduzione */
void printTab( FILE * f_ptr, int ntab );

/** Funzione che genera una espressione a partire da variabili, elementi di array 
 *  e costanti con i relativi operatori, presenti in una lista concatenata di stringhe */
char * genExpression( listaStringhe * expr );

/** Funzione usata per generare l'espressione da stampare nella traduzione per la 
 *  funzione echo di PHP a partire da una lista concatenata di stringhe contenente
 *  gli elementi dell'espressione.
 */
char * genEchoExpression( listaStringhe *exp );


// ******************* INIZIO SEZIONE DI DICHIARAZIONE DEI PROTOTIPI
// ******************* PER LE FUNZIONI E PROCEDURE DI SUPPORTO


/** Funzione che inizializza le tre liste di supporto. */
void liberaStrutture();

/** Funzione che invia allo standard output la stringa passata. */
void stampaMsg( const char * str, const char * col );

/** Funzione che verifica se la stringa passata appartenga o meno ad una costante */
char * isConstant( char *string, int numeroRiga );

/** stampaLista stampa a video tutti i valori di una lista concatenata */
void stampaLista( listaStringhe *pointer, char *label );

/** Conta il numero di elementi presenti in una lista concatenata */
int contaElementi( listaStringhe *testa );

/** Funzione che stabilisce se il contenuto di una stringa è costituito */
int isNumeric( char * str );

/** Funzione che converte un intero in una stringa con dimensione opportuna */
char * itoa( int val );

/** Funzione che apre in scrittura il file in output della traduzione e 
 *  Restituisce il puntatore a tale file */
void apriFileTraduzione();

/** Funzione che chiude il file di traduzione. */
void chiudiFile( FILE *f_ptr );

/** Funzione che elimina il file di output della traduzione */
void eliminaFile ( FILE *f_ptr );

/** Procedura per la scrittura dell'header del file di traduzione C */
void genIntestazione ( FILE* f_ptr );

/** Procedura di avvio della scrittura nel file di traduzione */
void avviaScritturaFileTraduzione();

/** Interrompe il processo ed elimina il file di uscita */
void abort();

// ****************************** FINE DICHIARAZIONE DEI PROTOTIPI *******************************


/** Funzione che inizializza le tre liste di supporto. */
void liberaStrutture( )
{
    free(espressioni); free(frasi);free(listaTipi);
    listaTipi = NULL;
    espressioni = NULL;
    frasi = NULL;
}

/** Funzione che invia allo standard output la stringa passata. Se l'avvio 
 *  avviene in console verrà usato il colore passato come secondo parametro
 *  Parametri: 	
 * 	str = stringa data in pasto ad una printf
 * 	col = stringa che identifica un colore per la console, tra red, 
 * 	      green, blue, purple, yellow, white, azure
 */
void stampaMsg ( const char * str, const char * col )
{
    if ( logging == false )
    {
        if ( strcmp ( col,"blue" ) == 0 )
            printf ( "\033[01;34m" );
        else if ( strcmp ( col,"azure" ) == 0 )
            printf ( "\033[01;36m" );
        else if ( strcmp ( col,"yellow" ) == 0 )
            printf ( "\033[01;33m" );
        else if ( strcmp ( col,"green" ) == 0 )
            printf ( "\033[01;32m" );
        else if ( strcmp ( col,"purple" ) == 0 )
            printf ( "\033[01;35m" );
        else if ( strcmp ( col,"white" ) == 0 )
            printf ( "\033[01;37m" );
        else if ( strcmp ( col,"none" ) == 0 )
            printf ( "\033[0m" );
        else
            printf ( "\033[01;31m" );
    }
    printf ( "%s",str );
    if ( logging == false )
        printf ( "\033[0m" );
}

/** Procedura per l'inserimento in coda di stringhe in una lista di stringhe
 * Argomenti:
 * 	pointer: doppio puntatore alla testa della lista
 * 	stringa: stringa da inserire
 */

void insInLista( listaStringhe **pointer ,char *stringa )
{
    listaStringhe *punt, *nuovo;
    // allocazione memoria per il nuovo elemento
    nuovo = ( listaStringhe * )malloc( sizeof( listaStringhe ) );
    nuovo->stringa = ( char * )strdup( stringa );
    nuovo->next = NULL;

    if ( * pointer == NULL )
        *pointer = nuovo; 	// lista vuota, inserimento in testa
    else			// lista non vuota, inserimento in coda
    {
        punt = *pointer;
        while ( punt->next != NULL )
            punt = punt->next;
        punt->next = nuovo;
    }
}

/** stampaLista stampa a video tutti i valori di una lista.
 * Argomenti sono:
 * 	pointer: puntatore alla testa della lista
 * 	label: stringa per etichettare la stampa
 */
void stampaLista ( listaStringhe *pointer, char *label )
{
    listaStringhe *punt = pointer;
    if ( punt )
    {
	stampaMsg("#################### Start \"","purple");
	stampaMsg(label,"white");
	stampaMsg("\" ####################\n\n","purple");
        while ( punt != NULL )
        {
            printf ( "Elemento: %s\n", punt->stringa );
            punt = punt->next;
        }
        stampaMsg("\n#################### End \"","purple");
	stampaMsg(label,"white");
	stampaMsg("\" ####################\n\n","purple");
    }
    else
    {
        stampaMsg ( "[INFO] #################### LISTA \"","purple" );
        stampaMsg ( label,"white" );
        stampaMsg ( "\" VUOTA ####################\n\n","purple" );
    }
}

/** Conta il numero di elementi presenti in una lista.
 *  Argomenti:
 *  	- testa: un puntatore alla testa della lista delle stringhe;
 *  Ritorna un intero valorizzato al numero degli elementi trovati nella lista oppure 0
 */
int contaElementi ( listaStringhe *testa )
{
    listaStringhe *punt = testa;
    int value = 0;
    while ( punt != NULL )
    {
        value++;
        punt = punt->next;
    }
    return value;
}

/** Funzione che stabilisce se il contenuto di una stringa è costituito da soli numeri
 *  Argomenti:
 * 	str: la stringa da analizzare
 *
 *  Ritorna un intero valorizzato ad 1 se la stringa è un numero, 0 altrimenti.
 */
int isNumeric ( char *str )
{
    char *c = ( char * ) strndup ( str, 1 ); //copia del primo carattere
    if ( strcmp ( c, "-" ) == 0 )  //se è un "-" si scarta il segno
    {
        c = ( char * ) strdup ( str + 1 );
        while ( *c )
        {
            if ( !isdigit ( *c ) )
                return 0;
            c++;
        }
    }
    else
    {
        while ( *str )
        {
            if ( !isdigit ( *str ) )
                return 0;
            str++;
        }
    }
    return 1;
}


/** Funzione che apre in scrittura il file in aoutput della traduzione 
 *  Restituisce il puntatore al file.
 */
void apriFileTraduzione()
{
    if ( ( f_ptr = fopen ( fout, "w" ) ) == NULL )
    {
        stampaMsg ( "[ERRORE FATALE]: apertura del file tradotto in C fallita.", "red" );
        exit ( 1 );
    }
}

/** Funzione che chiude il file di traduzione. */
void chiudiFile ( FILE *f_ptr )
{
    fflush ( f_ptr );
    fclose ( f_ptr );
}

/** Funzione usata in caso di errore grave per chiudere ed eliminare il file di output della traduzione
 *  Argomenti:
 * 	f_ptr: puntatore al file.
 */
void eliminaFile ( FILE *f_ptr )
{
    if ( f_ptr != NULL )
        chiudiFile ( f_ptr );
    if ( remove ( fout ) == -1 )
        stampaMsg ( "\n[WARNING]: file di traduzione inesistente. Verrà creato un nuovo file.\n", "yellow" );
}

/** Interrompe il processo ed elimina il file di uscita */
void abort(){
    _error+=1;
    stampaMsg("\nE' fallito il parsing del file ","red");
    stampaMsg(fout,"yellow");
    stampaMsg(", con errori num^ ","red");      
    stampaMsg(itoa(_error), "red");
    stampaMsg("\n", "red");
    liberaStrutture();
    eliminaSymbolTables();
    eliminaFile(f_ptr);
    exit(1);  
}

/** Procedura per la scrittura delle prime linee di codice nel file di traduzione. 
 *  Inserisce le direttive di inclusione delle librerie standard C per l'accesso
 *  allo standard I/O e per la manipolazione delle stringhe.
 *  Inoltre scrive la definizione di un tipo utile a mappare il tipo Booleno
 *  del linguaggio sorgente in quello target
 *  Argomenti:
 * 	f_ptr: il puntatore al file di uscita della traduzione
 */
void genIntestazione ( FILE* f_ptr )
{
    fprintf ( f_ptr, "#include <stdio.h>\n" );
    fprintf ( f_ptr, "#include <string.h>\n\n" );
    fprintf ( f_ptr, "void main( void ) {\n" );
    fprintf ( f_ptr, "\ttypedef enum { false, true } bool;\n" );
}

/** Procedura di avvio della scrittura nel file di traduzione */
void avviaScritturaFileTraduzione(){
  if(!f_ptr){
    eliminaFile(f_ptr); 
    apriFileTraduzione(); 
    genIntestazione(f_ptr);
  }
}


/** Procedura che scrive nella traduzione le costanti
 *  Argomenti:
 *	f_ptr: puntatore al file in uscita della traduzione
 * 	nomeConstante: il nome della costante
 * 	tipo: il tipo della costante
 * 	valore: il valore della costante
 */
void printConstant( FILE* f_ptr, char *nomeConstante, char *tipo, char *valore )
{
//se è una costante di tipo stringa allora devo stampare un array di caratteri.
    if ( strcmp ( tipo, "char *" ) == 0 )
        fprintf ( f_ptr, "char %s[] = %s;", nomeConstante, valore);
    else
        fprintf ( f_ptr, "const %s %s = %s;", tipo, nomeConstante, valore );
    insertNewLine(f_ptr);
}

/** Funzione che genera una espressione a partire da variabili, elementi di array e costanti 
 *  legate da operatori previsti dalla grammatica. 
 *  Argomenti:
 * 	expr: lista di stringhe contenente gli elementi dell'espressione
 *
 *  Torna una stringa contenente l'espressione.
 */
char * genExpression( listaStringhe *expr )
{
    char * expression;

    if ( expr == NULL )
    {
        expression = ( char * ) malloc ( sizeof ( char ) );
        expression = "\0";
    }
    else
    {
        expression = strdup ( expr->stringa );
        expr = expr->next;
    }
    while ( expr != NULL )
    {
        expression = ( char* ) realloc ( expression, sizeof ( char ) * ( strlen ( expr->stringa ) + strlen ( expression ) +1 ) );
        expression = strcat ( expression, expr->stringa );
        expr = expr->next;
    }
    return expression;
}

/** Funzione che crea una stringa da una lista concatenata. Usata per generare
 *  l'espressione da stampare nella traduzione per la funzione echo di PHP
 * 
 *  Argomenti:
 * 	exp: una lista di stringhe contenenti gli elementi della espressione di echo
 * 	Restituisce l'espressione.
 */

char * genEchoExpression ( listaStringhe *expr )
{
    char * expression;
    int elements = contaElementi(expr);
    
    if ( expr == NULL )
    {
        expression = ( char * ) malloc ( sizeof ( char ) );
        expression = "\0";
    }
    else
    {
        expression = strdup ( expr->stringa );
        expr = expr->next;
    }
    while ( expr != NULL )
    {
      if ( elements > 1 ){
	expression = ( char* ) realloc ( expression, sizeof ( char ) * ( strlen ( expression ) + 2 ) );
	strcat (expression,", ");	
      }      
        expression = ( char* ) realloc ( expression, sizeof ( char ) * ( strlen ( expr->stringa ) + strlen ( expression ) +1 ) );
        expression = strcat ( expression, expr->stringa );
        expr = expr->next;
    }
    return expression;
}

/** Procedura che scrive nel file di traduzione gli elementi che trova in una lista 
 * concatenata di stringhe contenente i chunk dell'espressione.
 * Argomenti:
 * 	f_ptr: puntatore al file nel quale scrivre
 * 	espressioni: lista concatenata di stringhe con gli elementi dell'espressione
 */

void printExpression( FILE * f_ptr, listaStringhe * espressioni ) {
    char * espressione = genExpression(espressioni);
    if(strlen(espressione) > 0)
      fprintf( f_ptr, "%s", espressione );
}

/** Procedura che scrive nella traduzione la dichiarazione di un array
 *  Argomenti:
 * 	f_ptr: puntatore al file della traduzione
 * 	nome_array: il nome dell'array
 * 	tipo: il tipo dell'array
 * 	exp: lista contenenti gli elementi della dichiarazione
 */
void printArrayDeclaration ( FILE* f_ptr, char * nome_array, char *tipo, listaStringhe * exp )
{
    char * expression = genExpression ( exp );
    if ( findElement(nome_array) != NULL )
        fprintf ( f_ptr, "%s[] = { %s }", nome_array, expression );
    else
        fprintf ( f_ptr, "%s %s[] = { %s }", tipo, nome_array, expression );
}


/** Procedura che scrive nella traduzione la dichiarazione di una variabile, l'assengazione di
 * valori a variabili o ad elementi di un array.
 * Argomenti:
 * 	f_ptr: puntatore al file di traduzione
 * 	op_index: indice che indica l'operatore di assegnazione da scrivere tra quelli predefiniti
 * 	left_var: nome della variabile o dell'elemento dell'array parte sinistra dell'assegnazione
 * 	tipo: il tipo della variabile che si sta scrivendo
 * 	exp: lista di stringhe contenenti gli elementi dell'espressione
 * 	array: flag booleano che indica se si tratta di un array
 */

void printAssignment( FILE * f_ptr, int op_index, char * left_var, char * tipo, listaStringhe * exp, bool array )
{
    char * expression = genExpression(exp);
    if ( !array ) {
       if ( findElement(left_var) != NULL )
            fprintf( f_ptr, "%s %s %s", left_var, op_name[ op_index ], expression );
        else
            fprintf( f_ptr, "%s %s %s %s", tipo, left_var, op_name[ op_index ], expression );
    } else {
        fprintf( f_ptr, " %s %s", op_name[ op_index ], expression );
    }
}

/** Procedura che scrive nella traduzione l'istruzione condizionale if
 *  Argomenti:
 * 	f_ptr: puntatore al file di traduzione
 * 	exp: lista di stringhe concatenata contenenti gli elementi dell' espressione.
 */
void printIF( FILE* f_ptr, listaStringhe * exp )
{
    char * expression = genExpression(exp);
    fprintf ( f_ptr, "if( %s ) {", expression );
    insertNewLine ( f_ptr );
}

/** Procedura che scrive l'istruzione condizionale else if nel file di traduzione
 *  Argomenti:
 * 	f_ptr: puntatore al file di traduzione
 * 	exp: lista di stringhe concatenata contenente gli elementi dell' espressione
 */
void printIfElse( FILE* f_ptr, listaStringhe *Exp )
{
    char *expression = genExpression ( Exp );
    fprintf ( f_ptr, " else if( %s ) {", expression );
    insertNewLine ( f_ptr );
}

/** Procedura che genera l'istruzione while
 *  Argomenti:
 * 	f_ptr: puntatore al file di traduzione
 * 	exp: lista di stringhe concatenata contenente gli elementi dell' espressione
 */
void printWhile( FILE* f_ptr, listaStringhe *exp )
{
    char *expression = genExpression ( exp );
    fprintf ( f_ptr, "while( %s ) {", expression );
    insertNewLine(f_ptr);
}

/** Procedura che genera l'istruzione per il costrutto switch
 *  Argomenti:
 * 	f_ptr: puntatore al file di traduzione
 * 	exp: lista di stringhe concatenata contenente gli elementi dell' espressione
 */
void printSwitch( FILE * f_ptr, listaStringhe * exp )
{
    char *expression = genExpression ( exp );
    fprintf ( f_ptr, "switch( %s ) {", expression );
    insertNewLine(f_ptr);
}

/** Funzione che realizza la funzione builtin echo di PHP, traducendola con una opportuna printf C
 *  Argomenti:
 * 	f_ptr: il puntatore al file di traduzione
 * 	espressioni: una lista di stringhe di supporto contenente gli elementi delle espressioni
 * 	frasi: una lista di stringhe contenenti gli elementi della frase
 */
void printEcho( FILE * f_ptr, listaStringhe * espressioni, listaStringhe * frasi )
{
    char * frase = genExpression ( frasi );    
    char * espressione = genEchoExpression ( espressioni );
    
    int lung_espr = 0; 
    if(espressione)
      lung_espr = strlen(espressione);
    int lung_frase = 0;
    if(frase)
      lung_frase = strlen(frase);

    if ( lung_frase > 0 && lung_espr > 0 )
        fprintf ( f_ptr, "printf(\"%s\",%s);", frase, espressione );
    else if (lung_frase > 0 )
        fprintf ( f_ptr, "printf(\"%s\");", frase );
    else
        fprintf ( f_ptr, "printf(%s);", espressione );
    insertNewLine ( f_ptr );
    liberaStrutture();
    espressione = NULL;
}

/** Procedura che appende un newline al file in uscita oppure un
 *  backslash se nel contesto di una funzione
 */
void insertNewLine( FILE * f_ptr )
{
    if ( lastFunction != NULL )
        fprintf ( f_ptr, "\t\t\\\n" );
    else
        fprintf ( f_ptr, "\n" );
}

/** Procedura che inserisce tabulazioni nel file di uscita della traduzione 
 *  Argomenti:
 * 	f_ptr: puntatore al file nel quale stampare il simbolo
 * 	ntab: numero tab da scrivere
 */
void printTab ( FILE *f_ptr, int ntab )
{
    int i;
    for ( i = 0; i < ntab; i++ )
        fprintf ( f_ptr, "\t" );
}

/** Procedura per la gestione del file di log. Avvia la scrittura sul file "parselog.log"
 * e redirezione lo standard output e lo standard error verso il file di log, salvando
 * i riferimenti originali per il ripristino successivo.
 */
void startLog()
{
    if ( logging == true )
    {
        if ( ( log_file = fopen ( "parselog.log", "w" ) ) == NULL )
            stampaMsg ( "\n[INFO_ERROR]: Fallito avvio scrittura del file di log\n", "red" );
        const char * timestamp = "Log ultima esecuzione di p2c";
        fprintf ( log_file, "\n****************** %s *****************\n", timestamp );
        stampaMsg ( "\nINFO: log abilitato in scrittura nel file parselog.log\n", "green" );
        tmpStdout = stdout; //salvataggio riferimento allo stdout
        stdout = log_file;  //redirect dello standard output al file di log
        tmpStderr = stderr; //salvataggio riferimento allo stderr
        stderr = log_file;  //redirect dello standard errore al file di log
    }
}

/** Procedura per la gestione del file di log. Termina la scrittura del file
 * e ripristina lo standard output e lo standard error
 */
void stopLog()
{
    if ( logging == true )
    {
        const char * timestamp = "Termine log di p2c";
        fprintf ( log_file, "\n****************** %s *****************\n", timestamp );
        fflush ( log_file );
        fclose ( log_file );
        stderr = tmpStderr; //ripristino riferimento allo stderr
        stdout = tmpStdout; //ripristino riferimento allo stdout
    }
}

/** Funzione che converte un intero in una stringa con dimensione opportuna */
char * itoa ( int val )
{
    int i = 1, count = val;
    while ( count > 10 )
    {
        count /= 10;
        i++;
    }
    char * ret = ( char * ) malloc ( sizeof ( char ) *i+1 );
    sprintf ( ret,"%d",val );
    ret[i+1] = '\0';
    return ret;
}

