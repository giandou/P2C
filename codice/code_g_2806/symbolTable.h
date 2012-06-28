/**
 * +-----------------------------------------------------------------------+
 * | P2C -- symbolTable.h                                                  |
 * +-----------------------------------------------------------------------+
 * |                                                                       |
 * |  Autori:  Vito Manghisi                                               |
 * |           Gianluca Grasso                                             |
 * +-----------------------------------------------------------------------+
 * 
 * Sorgente di gestione delle Symbol Tables per il traduttore P2C
 * 
 *
 */

#include <stdio.h> 	/** Per la stampa degli errori semantici */
#include <stdlib.h> 	/** Per allocare memoria */
#include <string.h> 	/** Per manipolare le stringhe nella tabella dei simboli */
#include "inclusioni.h" /** Funzioni e tipi di supporto al processo di traduzione. */


// ********* INIZIO SEZIONE DI DEFINIZIONE DELLE PROCEDURE E FUNZIONI *********

/** Procedura che elimina tutte le ST utilizzate */
void eliminaSymbolTables(){
    HASH_CLEAR(hh,symbolTable); // eliminazione ST globale
    symbolTable = NULL;
    //itera nella tabella delle funzioni per eliminare le tabelle interne
    functionSymbolTableEntry *corrente, *tmp;
    HASH_ITER(hh, functionSymbolTable, corrente, tmp) {
      HASH_CLEAR(hh,corrente->sf);
      free(corrente->sf);
    }
    HASH_CLEAR(hh,functionSymbolTable);
    functionSymbolTable = NULL;
}

/** Procedura dedicata alla stampa a video gli elementi della Symbol Table passata come parametro */
void stampaSymbolTable( symbolTablePointer tabella, const char * nomeTabella ){
    symbolTablePointer s = tabella;    
    unsigned int num_entry;
    num_entry = HASH_COUNT(s);
    if(num_entry){
      stampaMsg("\n#################### INIZIO DELLA SYMBOL TABLE \"","green");
      stampaMsg(nomeTabella,"white"); stampaMsg("\" ####################\n\n","green");
      for ( ; s != NULL; s = s->hh.next ) {
	  printf( "%s element name %s type %s",  s->tipoToken, s->nomeToken, s->type);
	  if(strcmp(s->tipoToken,"array")==0){
	    printf( " dim %i\n", s->dim );
	  }
	  else if(strcmp(s->tipoToken,"variable")==0 || strcmp(s->tipoToken,"constant")==0)
	  {
	    printf(" value %s\n", s->value);
	  }
      }
      stampaMsg("\n####################  FINE DELLA SYMBOL TABLE \"","green");
      stampaMsg(nomeTabella,"white"); stampaMsg("\"  ####################\n\n","green");
    }else{
      stampaMsg("\n[INFO] La Symbol Table \"","green"); stampaMsg(nomeTabella,"white");stampaMsg("\" è vuota\n","green");
    }
}

/** Procedura dedicata alla stampa a video gli elementi della Symbol Table delle funzioni 
 *  Argomenti:
 * 	- inner: intero se diverso da zero la procedura stampa le ST interne
 */
void stampaFunctionSymbolTable(int inner){
    functionSymbolTablePointer s = functionSymbolTable;    
    unsigned int num_entry, symbols;
    num_entry = HASH_COUNT(s);
    if(num_entry){
      stampaMsg("\n#################### SYMBOL TABLE PER LE FUNZIONI ####################\n\n","blue");
      for ( ; s != NULL; s = s->hh.next ) {
	  printf("Nome funzione: %s, numero parametri %d, tipo ritorno %s, scope: %s\n",  s->nomeFunzione, s->numeroParam, s->tipoRitorno, s->scope);
	  symbolTablePointer st = s->sf;
	  symbols = HASH_COUNT(st);	  
	  if(symbols && inner == 0){
	    stampaMsg("\n\t#################### SYMBOL TABLE INTERNA ALLA FUNZIONE \"","azure");
	    stampaMsg(s->nomeFunzione,"white");
	    stampaMsg("\" ####################\n","azure");
	    for ( ; st != NULL; st = st->hh.next ) {
	      if(strcmp(st->tipoToken,"parametro")==0)
		printf( "\n\tTipo token: %s, nome %s",  st->tipoToken, st->nomeToken);
	      else
		printf( "\n\tTipo token %s, nome %s, tipo %s",  st->tipoToken, st->nomeToken, st->type);
	      if(strcmp(st->tipoToken,"array")==0){
		printf( " dim %i", st->dim );
	      }
	      else if(strcmp(st->tipoToken,"variable")==0 || strcmp(st->tipoToken,"constant")==0)
	      {
		printf(" value %s", st->value);
	      }
	    }
	    stampaMsg("\n\n\t##################### FINE S.T. INTERNA ALLA FUNZIONE \"","azure");
	    stampaMsg(s->nomeFunzione,"white");
	    stampaMsg("\"  #####################\n\n","azure");
	  }else
	    stampaMsg("\n[INFO] La Symbol Table dei parametri della funzione è vuota\n","blue");
      }
    stampaMsg("\n################## FINE SYMBOL TABLE PER LE FUNZIONI ##################\n","blue");
    }else
       stampaMsg("\n[INFO] La Symbol Table per le funzioni è vuota\n","blue");
}

/** Funzione che trova e restituisce un elemento della Symbol Table. 
 *  Argomenti:
 * 	nomeToken: il nome del simbolo da cercare
 *  Ritorna l'elemento o NULL. 
 */
symbolTablePointer findElement( char *nomeToken ) {
    symbolTablePointer s = NULL;
    if(lastFunction!= NULL){
      HASH_FIND_STR( functionSymbolTable->sf, nomeToken, s );
    }else{
      HASH_FIND_STR( symbolTable, nomeToken, s );
    }    
    return s;
}

/** Funzione che trova e restituisce un elemento della Symbol Table per le funzioni. 
 *  Argomenti:
 * 	nomeToken: il nome del simbolo da cercare
 *  Ritorna l'elemento o NULL. 
 */
functionSymbolTablePointer findFunctionElement( char *nomeFunzione ) {
    functionSymbolTablePointer s;
    HASH_FIND_STR( functionSymbolTable, nomeFunzione, s );
    return s;
}

/** Funzione che rimuove un elemento dalla Symbol Table. 
 *  Argomenti:
 * 	s_pnt: puntatore all'elemento da rimuovere. 
 */
void deleteElement( symbolTablePointer s_pnt ) {
    HASH_DEL( symbolTable, s_pnt );
    free(s_pnt);
}

/** Funzione che rimuove un elemento dalla Symbol Table per le Funzioni.
 * Argomenti:
 * 	f_pnt: il punatore all'elemento da rimuovere. 
 */
void deleteFunctionElement( functionSymbolTablePointer f_pnt ) {
    HASH_DEL( functionSymbolTable, f_pnt );
    free(f_pnt);
}

/** Procedura che aggiorna il tipo dei parametri di una funzione all'atto della chiamata 
 *  Viene richiamata da una regola della grammatica che scatta al matching di ogni parametro. 
 *  Nel caso di passaggio di variabili ne controlla l'esistenza nella ST ed aggiorna il tipo
 *  del parametro formale della funzione a quello attuale della chiamata.
 */

void functionTypesUpdate(char * lastFunctionCall, char * parametroAttuale, int actualParamNum, int parameterType,int numeroRiga){

    functionSymbolTablePointer f = findFunctionElement( lastFunctionCall );
    
    if ( f ) { //si controlla l'esistenza della funzione nella symbol Table dedicata
      symbolTablePointer sf = f->sf; // puntatore alla ST interna alla funzione
      char * paramName = (char *)malloc(sizeof(char)*(strlen(sf->nomeToken)+strlen(f->nomeFunzione)+7));
      int i = 1;
      while( (sf != NULL) && (i++ < actualParamNum) && (actualParamNum <= f->numeroParam-1)) 
	sf = sf->hh.next; 	//sposta il puntatore nella inner symbol Table iterativamente sul numero di parametri	

      // se è una variabile controlla l'esistenza nella main ST ed aggiorna il valore
      if(parameterType == 0 || parameterType == 1){
	  symbolTablePointer s = findElement(parametroAttuale);  // punt alla ST del main   	  
	  if( s ){ // controllo esistenza nella main ST del parametro attuale
// 	      char * paramName = (char *)malloc(sizeof(char)*(strlen(s->nomeToken)+strlen(f->nomeFunzione)+7));
	      sprintf(paramName,"___%s___%s\0",sf->nomeToken,f->nomeFunzione);	      
	      if( f->tipizzata == false ){ // se i tipi dei parametri non sono stati ancora aggiornati si effettua l'aggiornamento
		sf->type = strdup(s->type);	      
		fprintf(f_ptr,"%s %s = %s; ",sf->type,paramName, parametroAttuale);	      
	      }else{ // altrimenti si controlla la congruenza dei tipi nella chiamata
		if( strcmp(sf->type,s->type)!=0 ){
		  stampaMsg("\n[WARNING] Un parametro attuale della chiamata alla funzione \"","yellow");
		  stampaMsg(lastFunctionCall,"yellow");
		  stampaMsg("\" non è congruente con una precedente chiamata.\n Riga: ","yellow");
		  stampaMsg(itoa(numeroRiga), "yellow");
		  stampaMsg("\n", "yellow");
		  _warning+=1;
		}
		fprintf(f_ptr,"%s = %s; ",paramName, parametroAttuale);     
	      }	    
	  }
	  else{
	    stampaMsg("\n[ERRORE FATALE]: Un parametro nella chiamata alla funzione non è definito!\n","red");
	    stampaMsg("Riga: ","red");
	    stampaMsg(itoa(numeroRiga), "red");
	    stampaMsg("\n", "red");
	    _error+=1;
	  }
      }
      else if(parameterType == 2 || parameterType == 3){ // caso di uno scalare
	  listaStringhe * expr = espressioni, * tipi = listaTipi;	  
	  char * espressione = genExpression(espressioni);
  	  if(tipi)	//sposta il puntatore all'ultimo tipo per ottenerne il valore
  	    while(tipi->next)
  	      tipi = tipi->next;
	      
	     
	    sprintf(paramName,"___%s___%s\0",sf->nomeToken,f->nomeFunzione);
	    
	    if(f->tipizzata == false){
	      // in caso di prima chiamata aggiorno il tipo con il tipo della costante
	      sf->type = strdup(tipi->stringa);	    
	      fprintf(f_ptr,"%s %s = %s; ",sf->type,paramName,espressione);
	    }
	    else{
	      //controllo di congruenza
	      if( strcmp(sf->type,tipi->stringa)!=0 ){
		stampaMsg("\n[WARNING] Un parametro attuale della chiamata alla funzione \"","yellow");
		stampaMsg(lastFunctionCall,"yellow");
		stampaMsg("\" non è congruente con una precedente chiamata.\n Riga: ","yellow");
		stampaMsg(itoa(numeroRiga), "yellow");
		stampaMsg("\n", "yellow");
		_warning+=1;
	      }	      
	      fprintf(f_ptr,"%s = %s;",paramName,espressione);
	      
	    }
// 	    espressioni = NULL;
      }   
      
    insInLista(&frasi,paramName);
    if(actualParamNum < f->numeroParam)
	insInLista(&frasi,",");
    free(paramName);
    if(actualParamNum == (f->numeroParam-1))
      f->tipizzata = true;
      
    }else{
        stampaMsg("\n[ERRORE FATALE]: Chiamata ad una funzione non definita!\n","red");
	stampaMsg("Riga: ","red");
	stampaMsg(itoa(numeroRiga), "red");
	stampaMsg("\n", "red");
	_error+=1;
    }
    
    
  
}

/*
void functionTypesUpdate(char * lastFunctionCall, char * parametroAttuale, int actualParamNum, int constantType,int numeroRiga){

    functionSymbolTablePointer f = findFunctionElement( lastFunctionCall );
    
    if ( f ) { //si controlla l'esistenza della funzione nella symbol Table dedicata
      symbolTablePointer sf = f->sf; // puntatore alla ST interna alla funzione
      
      int i = 1;
      while( (sf != NULL) && (i++ < actualParamNum) && (actualParamNum <= f->numeroParam-1)) 
	sf = sf->hh.next; 	//sposta il puntatore nella inner symbol Table iterativamente sul numero di parametri	
      
      if(constantType == 0){ // se è una variabile controlla l'esistenza nella main ST ed aggiorna il valore

	symbolTablePointer s = findElement(parametroAttuale);  // punt alla ST del main   
	
	if( s ){ // controllo esistenza nella main ST del parametro attuale
	  
// 	  if(sf){ //si controlla l'esistenza della ST interna alla funzione selezionata
	    
	    if( f->tipizzata == false ){ // se i tipi dei parametri non sono stati ancora aggiornati si effettua l'aggiornamento
	      sf->type = strdup(s->type);
	      
	      fprintf(f_ptr,"%s ___%s___%s = %s; ",sf->type,sf->nomeToken,f->nomeFunzione,parametroAttuale);
	      char * paramName = (char *)malloc(sizeof(char)*(strlen(sf->nomeToken)+1));
	      sprintf(paramName,"%s\0",sf->nomeToken);
	      insInLista(&espressioni,paramName);
	      if(actualParamNum < f->numeroParam)
		insInLista(&espressioni,",");
	      free(paramName);
	    }else{ // altrimenti si controlla la congruenza dei tipi nella chiamata
	      if( strcmp(sf->type,s->type)!=0 ){
		stampaMsg("\n[WARNING] Un parametro attuale della chiamata alla funzione \"","yellow");
		stampaMsg(lastFunctionCall,"yellow");
		stampaMsg("\" non è congruente con una precedente chiamata.\n Riga: ","yellow");
		stampaMsg(itoa(numeroRiga), "yellow");
		stampaMsg("\n", "yellow");
		_warning+=1;
	      }
	      fprintf(f_ptr,"___%s___%s = %s; ",sf->nomeToken,f->nomeFunzione,parametroAttuale);
	      char * paramName = (char *)malloc(sizeof(char)*(strlen(sf->nomeToken)+2));
	      sprintf(paramName,"%s\0",sf->nomeToken);
	      insInLista(&espressioni,paramName);
	      if(actualParamNum < f->numeroParam)
		insInLista(&espressioni,",");
	      free(paramName);
	    }	  
// 	  }	
	}
	else{
	  stampaMsg("\n[ERRORE FATALE]: Un parametro nella chiamata alla funzione non è definito!\n","red");
	  stampaMsg("Riga: ","red");
	  stampaMsg(itoa(numeroRiga), "red");
	  stampaMsg("\n", "red");
	}//fine aggiornamento nel caso di una variabile
      }
      else if(constantType==1){ // se è una costante imponi il tipo ad int
	  
	  listaStringhe * expr = espressioni, * tipi = listaTipi;	  
	  if(expr)	//sposta il puntatore all'ultima espressione per ottenere il valore
	    while(expr->next)
	      expr = expr->next;
	  if(tipi)	//sposta il puntatore all'ultimo tipo per ottenere il valore
	    while(tipi->next)
	      tipi = tipi->next;
	    
	  if(f->tipizzata == false){
	    // in caso di prima chiamata aggiorno il tipo con il tipo della costante
	    sf->type = strdup(tipi->stringa);	    
	    fprintf(f_ptr,"%s _%s = %s; ",sf->type,sf->nomeToken,parametroAttuale);
	  }
	  else{
	    //controllo di congruenza
	    if( strcmp(sf->type,tipi->stringa)!=0 ){
	      stampaMsg("\n[WARNING] Un parametro attuale della chiamata alla funzione \"","yellow");
	      stampaMsg(lastFunctionCall,"yellow");
	      stampaMsg("\" non è congruente con una precedente chiamata.\n Riga: ","yellow");
	      stampaMsg(itoa(numeroRiga), "yellow");
	      stampaMsg("\n", "yellow");
	      _warning+=1;
	    }	      
	    fprintf(f_ptr,"_%s = %s; ",sf->nomeToken,parametroAttuale);
	  }
 
	  char * paramName = (char *)malloc(sizeof(char)*(strlen(sf->nomeToken)+2));
	  sprintf(paramName,"_%s\0",sf->nomeToken);
	  expr->stringa = paramName;
	  if(actualParamNum < f->numeroParam )
	    insInLista(&espressioni,",");	
      }
      // aggiorna il flag sulla tipizzazione
      if(actualParamNum == (f->numeroParam-1))
	f->tipizzata = true;
    }else{
        stampaMsg("\n[ERRORE FATALE]: Chiamata ad una funzione non definita!\n","red");
	stampaMsg("Riga: ","red");
	stampaMsg(itoa(numeroRiga), "red");
	stampaMsg("\n", "red");
    }
  
}*/

/** Procedura per l'aggiornamento del tipo di ritorno di una funzione, eseguita
 *  dopo la prima chiamata alla funzione e dopo l'aggiornamento dei parametri 
 */
void updateReturnType(char * lastFunctionCall,int numeroRiga){  
  functionSymbolTablePointer f = findFunctionElement(lastFunctionCall);  
  if( f ){    
    listaStringhe * tipiRitorno = f->tipiExprRitorno;
    symbolTablePointer s = f->sf, punt;    
    if( s ){
      //aggiornamento della lista con i tipi attuali
      while( tipiRitorno != NULL ){
	//recupero nella inner ST
	HASH_FIND_STR( s, tipiRitorno->stringa, punt );
	if(punt){ //esiste
	  tipiRitorno->stringa = punt->type;
	}	
	tipiRitorno = tipiRitorno->next;
      }
    }
    // esecuzione del type checking 
    f->tipoRitorno = typeChecking(f->tipiExprRitorno);
    HASH_FIND_STR( s, f->nomeRitorno, punt );
    punt->type = f->tipoRitorno;
  } 
}

/** Funzione che aggiunge un nuovo elemento nella Symbol Table.
 *  Argomenti:
 * 	nomeToken: nome del simbolo da aggiungere
 * 	tipoToken: tipo di elemento tra "constant", "variable" o "array"
 * 	current_type: tipo tra "int", "float", "char *" o "bool
 * 	current_value: valore assegnato alla variabile, zero per assegnazioni complessa o NULL se array
 * 	dimensione: dimensione dell'array, o zero
 * 	numeroRiga: numero riga nel file sorgente
 */
void addElement( char *nomeToken, char *tipoToken, char *current_type, char *current_value, int
                  dimensione, int numeroRiga ) {
    symbolTablePointer s;
    symbolTablePointer exist = findElement( nomeToken );
    
    // L'elemento viene aggiunto solo se non esiste già nella Symbol Table.
    if ( !exist ) {
        s = malloc( sizeof( symbolTableEntry ) );
        s->nomeToken = nomeToken;
        s->tipoToken = tipoToken;
        s->type = current_type;
        s->value = current_value;
        s->dim = dimensione;
	if(lastFunction!= NULL)	  
	  HASH_ADD_KEYPTR( hh, functionSymbolTable->sf, nomeToken, strlen(nomeToken), s );
	else
	  HASH_ADD_KEYPTR( hh, symbolTable, s->nomeToken, strlen( s->nomeToken ), s );	
        /* controllo di ridefinizione di una costante */
    } else if ( strcmp( exist->tipoToken, "constant" ) == 0 ) {
        printf( "\033[01;31m[ERRORE FATALE] Riga %i: ridefinizione di una costante.\033[00m\n", numeroRiga);
	_error+=1;
    } else {
      // per una variabile si verificare il tipo prima della riassegnazione del valore 
        if ( strcmp( exist->type, current_type ) == 0 ) {
            exist->value = current_value;
        } else {
            printf( "\033[01;31m[ERRORE FATALE] Riga %i: l'assegnazione viola il tipo primitivo della variabile.\033[00m\n", numeroRiga);
	    _error+=1;
        }
    }
}


/** Procedura per l'inserimento di un elemento nella ST delle funzioni */
void addFunctionElement( char *nomeFunzione, char *scope, int numeroRiga ) {
    functionSymbolTablePointer s;
    functionSymbolTablePointer exist = findFunctionElement( nomeFunzione );
    symbolTableEntry sf;

//se non esiste inserisce l'elemento nella Symbol Table funzioni.
    if ( !exist ) {
        s = malloc( sizeof( functionSymbolTableEntry ) );
        s->nomeFunzione = nomeFunzione;
	s->scope = strdup(scope);
	s->numeroParam=0;
	s->tipizzata = false;
	s->chiamata = false;
	s->nomeRitorno = (char *)malloc((strlen(nomeFunzione) + 1)*sizeof(char));
	sprintf(s->nomeRitorno,"___%s",nomeFunzione);	
	//sf = malloc( sizeof( symbolTableEntry ) );
        HASH_ADD_KEYPTR( hh, functionSymbolTable, s->nomeFunzione, strlen( s->nomeFunzione ), s );
	
    }else{      
      stampaMsg("\n[ERRORE FATALE]: Non è possibile ridichiarare una funzione\n","red");
      stampaMsg("Riga: ","red");
      stampaMsg(itoa(numeroRiga), "red");
      stampaMsg("\n", "red");
      _error+=1;
    }
}

void addElementInFunctionSymbolTable(char * nomeFunzione, char * nomeToken, char * tipoToken, char * tipo, char * value , int numeroRiga){
  
    functionSymbolTablePointer s;
    functionSymbolTablePointer exist = findFunctionElement( nomeFunzione );
    
    if ( exist ) {
//stampaMsg("\nTrovata la funzione nella ST funzioni\n","azure");
      symbolTablePointer sf;
      HASH_FIND_STR( exist->sf, nomeToken, sf );
      if ( !sf ) { 
	sf = malloc( sizeof( symbolTableEntry ) );
	sf->nomeToken = nomeToken;
	sf->tipoToken = tipoToken;
	sf->type= tipo;
	sf->value= value;
	sf->dim = 0;
	exist->numeroParam+=1;
	HASH_ADD_KEYPTR( hh, exist->sf, nomeToken, strlen( nomeToken ), sf );
      }
      else{      
	stampaMsg("\n[ERRORE FATALE]: Si sta ridefinendo un parametro già esistente.\n","red");
	stampaMsg("Riga: ","red");
	stampaMsg(itoa(numeroRiga), "red");
	stampaMsg("\n", "red");
	_error+=1;
      }
    }else{      
      stampaMsg("\n[ERRORE FATALE]: Si vuole inserire un parametro in una funzione inesistente.\n","red");
      stampaMsg("Riga: ","red");
      stampaMsg(itoa(numeroRiga), "red");
      stampaMsg("\n", "red");
      _error+=1;
    }
}

/** Procedura per costruire lo statement di ritorno da una funzione
 *  Argomenti:
 * 	numeroRiga: il numero di riga nel file sorgente
 */
void buildReturnStatement(int numeroRiga){
    if(lastFunction){
	functionSymbolTablePointer exist = findFunctionElement( lastFunction );
	if ( exist ) {
	  insInLista(&espressioni,exist->nomeRitorno);	  
	  insInLista(&espressioni,"=");	  
	}
	else{
	  stampaMsg("\n[ERRORE FATALE]: Si vuole inserire un RETURN in una funzione inesistente.\n","red");
	  stampaMsg("Riga: ","red");
	  stampaMsg(itoa(numeroRiga), "red");
	  stampaMsg("\n", "red");
	  _error+=1;
	}
      }
}

/** Procedura la generazione di uno statement di ritorno da una funzione
 *  Argomenti:
 * 	numeroRiga: il numero di riga nel file sorgente
 */
 void printReturnStatement(int numeroRiga){
      if(lastFunction){
	functionSymbolTablePointer exist = findFunctionElement( lastFunction );
	if ( exist ) {
	  printExpression(f_ptr,espressioni);	  
	  insInListaTipiRitorno(); //inserimento variabili coinvolte nell'espressione di ritorno	  
	  fprintf( f_ptr,";" );
	  insertNewLine(f_ptr);  
	  symbolTablePointer s;
	  s = (symbolTablePointer) malloc( sizeof( symbolTableEntry ) );
	  s->nomeToken = strdup(exist->nomeRitorno);
	  s->tipoToken = "variable";
	  s->type = "int";
	  s->value = "0";
	  s->dim = 0;	  
	  HASH_ADD_KEYPTR( hh, symbolTable, exist->nomeRitorno, strlen( exist->nomeRitorno ), s );	  
	}
	else{
	  stampaMsg("\n[ERRORE FATALE]: Si vuole valorizzare un RETURN per una funzione inesistente.\n","red");
	  stampaMsg("Riga: ","red");
	  stampaMsg(itoa(numeroRiga), "red");
	  stampaMsg("\n", "red");
	  _error+=1;
	}
      }
}

/** Procedura la valorizzazione della lista dei tipi di una espressione di ritorno da una funzione
 *  Argomenti:
 * 	numeroRiga: il numero di riga nel file sorgente
 */

void insInListaTipiRitorno(){
  
    listaStringhe *expr = espressioni;
    listaStringhe *tipi = listaTipi;
    
    expr = expr->next;
    expr = expr->next;
    
    symbolTablePointer s;
    functionSymbolTablePointer f;
    f = findFunctionElement(lastFunction);
    int i = 1, j = 1;
    while(expr!=NULL){
      s = findElement(expr->stringa);
      if(s){ // se ho trovato la chiave nella inner ST della funzione
	insInLista(&f->tipiExprRitorno,s->nomeToken);	
      }else
      {
	//memorizzo il tipo dalla lista tipi	
	insInLista(&f->tipiExprRitorno,tipi->stringa);	
      }
      tipi = tipi->next;
      expr = expr->next;  
      if(expr!=NULL)
	 expr = expr->next;
      i += 2;
      j += 1;
    }    
}

/** Funzione utilizzata per il controllo di congruenza tra i tipi delle variabili coinvolte in espressioni 
 * contenenti operatori binari. 
 * Nel caso di tipi non congruenti viene valorizzata la variabile globale "notice" che identifica
 * diversi messaggi di warning, stampati al termine del parsing.
 * 
 * Argomenti: 
 * 	listaTipi: una lista di stringhe contenente i tipi delle varaibili coinvolte in una espressione
 */
char * typeChecking( listaStringhe *listaTipi )
{
    listaStringhe *punt = listaTipi;
    char *tipoRitornato = "int";

    while ( punt != NULL ) {
        if ( strcmp( punt->stringa, "float" ) == 0 ) {
            tipoRitornato = "float";
        }else if( strcmp( punt->stringa, "char *" ) == 0 ) {
            notice = 0;
        }else if ( strcmp(punt->stringa, "bool" ) == 0 ) {
            notice = 1;
        }
        punt = punt->next;
    }
    return tipoRitornato;
}

/** Procedura che controlla se l'operazione di assegnazione di un elemento di un array
 *  sia di tipo congruente al tipo memorizzato nella ST 
 *
 * Argomenti:
 * 	listaTipi: lista di stringhe contenente i tipi associati agli operandi
 * 	contesto: intero indicante il conteso di utilizzo di tale funzione, tra i seguenti:
 * 			1 creazione di un array
 * 			2 assegnazione di un valore per un elemento dell'array
 * 			3 assegnazione multipla
 * 	elemento: l'elemento della ST ritornato dalla funzione checkElement
 * 	numeroRiga: numero riga per la segnalazione di errori. 
 */
void arrayTypeChecking( listaStringhe *listaTipi, short int contesto, symbolTablePointer element, int numeroRiga ) {
    listaStringhe *punt = listaTipi;
    char *tipo;

    switch ( contesto ) {
//Controlla la creazione degli array: omogeneità dei tipi
    case 0:
        if ( listaTipi != NULL )
            tipo = punt->stringa;
        while ( listaTipi != NULL ) {
            if ( strcmp( listaTipi->stringa, tipo ) != 0 )
            {
                printf( "\033[01;31mRiga %i. [ FATALE ] ERRORE SEMANTICO: l'uso di un operando di tipo non omogeneo in un array tipizzato non è corretto nel linguaggio target C.\033[00m\n", numeroRiga );
		_error+=1;
            }
            listaTipi = listaTipi->next;
        }
        break;
    case 1:
        if ( strcmp( element->type, listaTipi->stringa ) != 0 ) {
            printf( "\033[01;31mRiga %i. [ FATALE ] ERRORE SEMANTICO: l'assegnazione viola l'omogeneità degli elementi dell'array \"%s\".\033[00m\n", numeroRiga, element->nomeToken );
	    _error+=1;
        }
        break;
    case 2:
        tipo = element->type;
        while ( listaTipi != NULL ) {
            if ( strcmp( listaTipi->stringa, tipo ) != 0 )
            {
                printf( "\033[01;31mRiga %i. [ FATALE ] ERRORE SEMANTICO: l'assegnazione viola l'omogeneità degli elementi dell'array \"%s\".\033[00m\n", numeroRiga, element->nomeToken );
		_error+=1;
            }
            listaTipi = listaTipi->next;
        }
        break;
    }
}

/** Procedura chiamata in caso di assegnazione di un valore a un elemento di un array
 * per controllare se l'elemento, e il suo indice siano validi. 
 * Controlla l'esistenza nella Symbol Table ed effettua il controllo sull'elemento 
 * relativo all'indice passato come argomento:
 * 	- se è un numero, converte il contenuto della stringa nel corrispondente valore intero;
 * 	- se è una variabile si accerta della sua esistenza e converte il contenuto della stringa 
 * 		nel corrispondente valore intero;
 * 	- controlla la correttezza del valore dell'indice (se minore di zero o
 * 		maggiore della dimensione massima presente nella ST viene lanciato un warning)
 * Argomenti:
 * 	nomeToken: il nome dell'elemento dell'array
 * 	indice: l'indice dell'elemento;
 * 	numeroRiga, il numero riga nel file sorgente
 */
void checkIndex( char *nomeToken, char *indice, int numeroRiga ) {
    int index;
    symbolTablePointer exist = findElement( nomeToken );
    symbolTablePointer exist_index;
//se l'elemento non esiste lancia un errore semantico fatale.
    if ( !exist ) {
        printf( "\033[01;31m\033[01;31m[ERRORE FATALE] Riga %i: variabile \"%s\" non definita.\033[00m\n", numeroRiga, nomeToken );
	_error+=1;
    } else {
        if ( isNumeric( indice ) ) {
            index = atoi( indice );
        } else {
            exist_index = findElement( indice );
            if ( exist_index ) {
                if ( strcmp( exist_index->type, "int" ) != 0 ) {
                    printf( "\033[01;31m[ERRORE FATALE] Riga %i:l'uso di un elemento con indice non intero non è ammissibile.\033[00m\n", numeroRiga);
		    _error+=1;
                }
                index = atoi( exist_index->value );
            } else {
                printf( "\033[01;31m[ERRORE FATALE] Riga %i: variabile \"%s\" non definita.\033[00m\n", numeroRiga, indice );
		_error+=1;
            }
        }
        if ( index < 0 || index >= exist->dim ) {
            notice = 4;
        }
    }
}

/** Funzione che controlla l'esistenza di elementi nella Symbol Talbe. 
 * 
 * Argomenti:
 * 	nomeToken: il nome dell'elemento da ricercare;
 * 	offset: l'indice dell'elemento dell'array;nel file sorgente
 * 	read: per gli array specifica se l'elemento è analizzato in lettura o scrittura 
 * 	numeroRiga: il numero di riga nel file sorgente, per segnalazione errori
 * 
 * Ritorna l'elemento identificato da nomeToken se presente nella Symbol Table.
 */
symbolTablePointer checkElement( char *nomeToken, char *offset, int numeroRiga, bool read )
{
    int index;
    char *tipo;
    char *el_array;

    symbolTablePointer exist = findElement( nomeToken );
    symbolTablePointer exist_index;
    if ( !exist ) { //se l'elemento non esiste segnala un errore semantico fatale
      if(lastFunctionCall!=NULL){
	printf( "\033[01;31m\033[01;31m[ERRORE FATALE] Riga %i:la funzione chiamata \"%s\" non restituisce valori.\033[00m\n", numeroRiga, lastFunctionCall);
      }
      else{
        printf( "\033[01;31m\033[01;31m[ERRORE FATALE] Riga %i: \"%s\" non definita.\033[00m\n", numeroRiga, nomeToken );       
      }
      _error+=1;
    } else {
        if ( ( ( strcmp( exist->tipoToken, "variable" ) == 0 ) || ( strcmp( exist->tipoToken, "constant" ) == 0 ) ) && read ) {
            insInLista( &listaTipi, exist->type );
            insInLista( &espressioni, exist->nomeToken );
        } else { //se è un elemento di un array di sola lettura si aggiunge alle liste 
            if ( read ) { 
                insInLista( &listaTipi, exist->type );
                el_array = nomeToken;
                strcat(el_array, "[");
                strcat(el_array, offset);
                strcat(el_array, "]");
                strcat(el_array, "\0");
                insInLista( &espressioni, el_array );
            }
            if ( isNumeric( offset ) ) {
                index = atoi( offset );
            } else {
                exist_index = findElement( offset );
                if ( exist_index ) {
                    if ( strcmp( exist_index->type, "int" ) != 0 ) {
                        printf( "\033[01;31m[ERRORE FATALE] Riga %i: l'uso di un elemento con offset non intero non è ammissibile.\033[00m\n", numeroRiga);
			 _error+=1;
                    }
                    index = atoi( exist_index->value );
                } else {
                    printf( "\033[01;31m[ERRORE FATALE] Riga %i: variabile \"%s\" non definita.\033[00m\n", numeroRiga, offset );
		    _error+=1;
                }
            }
            if ( index < 0 || index >= exist->dim ) {
                notice = 4;
            }
            if ( contaElementi( listaTipi ) != 0 && !read ) {

                switch ( contaElementi( listaTipi ) ) {
                case 1:
                    arrayTypeChecking( listaTipi, 1, exist, numeroRiga );
                    break;

                default:
                    arrayTypeChecking( listaTipi, 2, exist, numeroRiga );
                    break;
                }
            }
        }
    }
    return exist;
}

/** Funzione che verifica l'esistenza nella ST del token passato come argomento.
 * Se il token è un array allora viene controllato l'offset corrispondente all'elemento da controllare.
 * In base al tipo di variabile vengono valorizzare le liste relative alle espressioni o alle frasi. 
 * 
 * Argomenti: 
 * - nomeToken: il nome della variabile, dell' array o di una costante;
 * - offset: l'indice dell'elemento nell'array, nel caso degli array;
 * - numeroRiga: il numero riga prelevato da Flex. 
 */
void echoCheck( char *nomeToken, char *offset, int numeroRiga )
{
    int index;
    char * tmp = " ) ? \"true\" : \"false\""; //variabile utilizzata per gestire la traduzione della stampa di valori booleani.
    char * el_array;
    symbolTablePointer exist = NULL;
    if(inFunctionDeclaration == true){
      insInLista( &espressioni, nomeToken ); 
    }
    else{
      exist = findElement( nomeToken );
      symbolTablePointer exist_index;
      if ( !exist ) {
	  printf( "\n\033[01;31m[ERRORE FATALE] Riga %i: variabile \"%s\" non definita.\033[00m\n", numeroRiga, nomeToken );
	  _error+=1;
      } else {
	  if ( strcmp( exist->tipoToken, "array" ) == 0 ) {
	      if ( offset == NULL ) {
		  printf( "\033[01;31m\033[01;31m[ERRORE FATALE] Riga %i: offset non definito.\033[00m\n", numeroRiga );
		   _error+=1;
	      }
	      if ( isNumeric( offset ) ) {
		  index = atoi( offset );
	      } else {
		  exist_index = findElement( offset );
		  if ( exist_index ) {
		      if ( strcmp( exist_index->type, "int" ) != 0 ) {
			  printf( "\033[01;31m[ERRORE FATALE] Riga %i: l'uso di un elemento con offset non intero non è ammissibile.\033[00m\n", numeroRiga);
			  _error+=1;
		      }
		      index = atoi( exist_index->value );
		  } else {
		      printf( "\033[01;31m\033[01;31m[ERRORE FATALE] Riga %i: variabile \"%s\" non definita.\033[00m\n", numeroRiga, nomeToken );
		      _error+=1;
		  }
	      }
	      el_array = nomeToken;
	      strcat( el_array, "[" );
	      strcat( el_array, offset );
	      strcat( el_array, "]" );
	      strcat( el_array, "\0" );
	      if ( strcmp( exist->type, "bool" ) == 0 ) {
		  char *c = ( char * )malloc( ( strlen( el_array ) + strlen( tmp ) + 1 ) * sizeof( char ) );
		  strcpy( c, "( " );
		  strcat( c, el_array );
		  strcat( c, tmp );
		  insInLista( &espressioni, c );
		  free( c );
	      } else
		  insInLista( &espressioni, el_array );

	      if ( index < 0 || index >= exist->dim ) {
		  notice = 5;
	      }
	  } else {
	      if ( strcmp( exist->type, "bool" ) == 0 ) {
		  char *c = ( char * )malloc( ( strlen( nomeToken ) + strlen( tmp ) + 1 ) * sizeof( char ) );
		  strcpy( c, "( " );
		  strcat( c, nomeToken );
		  strcat( c, tmp );
		  insInLista( &espressioni, c );
		  free( c );
	      } else
		  insInLista( &espressioni, nomeToken);
	  }
	  if ( strcmp( exist->type, "int" ) == 0 )
	      insInLista( &frasi, "%i" );
	  else if ( strcmp( exist->type, "float" ) == 0 )
	      insInLista( &frasi, "%f" );
	  else
	      insInLista( &frasi, "%s" );
      }
    }
}

/** Funzione che verifica se la stringa passata appartenga o meno ad una costante 
 * predefinita di PHP o se sia una costante definita mediante 'define'.
 * 
 * Argomenti:
 * 	string: la stringa da controllare
 * 	numeroRiga: il numero di riga nel file sorgente.
 * Torna il tipo della costante per effettuare il typeChecking.
 */
char * isConstant( char *string, int numeroRiga )
{
    int i;
    int trov = 0;
    char *current_type = "bool";
    for ( i = 0; i < NUM_CONSTANTS; i++ )
    {
        if ( strcmp( string, const_tab[i].ctM ) == 0 )
            trov = 1;
        if ( strcmp( string, const_tab[i].ctm ) == 0 )
            trov = 1;
    }
    if ( trov == 0 ) {
        symbolTablePointer exist = findElement( string );

        if ( exist && ( strcmp( exist->tipoToken, "constant" ) == 0) ) {
            current_type = exist->type;
            trov = 1;
        }
    }
    return current_type;
}

/** Procedura che scrive nel file di traduzione l'intestazione di una dichiarazione 
 * di funzione.
 * 
 * Argomenti:
 * 	nomeFunzione: il nome della funzione da scrivere
 */
void printDeclarationFunctionHeader(char * nomeFunzione) {
  functionSymbolTablePointer f;
  f = findFunctionElement(nomeFunzione);
  fprintf(f_ptr, "#define %s(",f->nomeFunzione);
  int i=0;
  if(f->numeroParam!=0){
    symbolTablePointer s;
    s = f->sf;
    for ( ; i < f->numeroParam; s = s->hh.next ,i++ ) {
      fprintf(f_ptr,"%s",s->nomeToken);
      if(i != (f->numeroParam - 1) )
	fprintf(f_ptr,",");
    }
    fprintf(f_ptr,", _%s",nomeFunzione);
  }
  else
  {
    fprintf(f_ptr,"_%s",nomeFunzione);
  }  
  fprintf(f_ptr,") {\t\t\\\n");
  addElementInFunctionSymbolTable(nomeFunzione, f->nomeRitorno, "ritorno", "NULL", "0" , 0);
}

/** Procedura per la scrittura sul file di traduzione di una chiamata a funzione.
 * 
 * Argomenti:
 * 	nomeFunzione: il nome della funzione da scrivere
 * 	numeroRiga: il numero della riga nel file sorgente per segnalazione errori
 */
void printFunctionCall(char * nomeFunzione, int numeroRiga){
  functionSymbolTablePointer f;
  f = findFunctionElement(nomeFunzione);
  
  if(f==NULL){
    stampaMsg("\n[ERRORE FATALE]: Riga ","red");
    stampaMsg(itoa(numeroRiga),"yellow");
    stampaMsg(", La funzione ", "red");    
    stampaMsg(nomeFunzione,"yellow");
    stampaMsg(" richiamata non esiste!\n","red");   
     _error+=1;
  }
  else
  {
    if(f->chiamata == false){
      fprintf(f_ptr,"%s %s;",f->tipoRitorno,f->nomeRitorno);
    }
    insertNewLine(f_ptr);
    printTab(f_ptr,ntab);
    fprintf(f_ptr,"%s(",f->nomeFunzione);
    printExpression(f_ptr,frasi);
    liberaStrutture();
    fprintf(f_ptr,"%s",f->nomeRitorno);
    fprintf(f_ptr,");");
//     insertNewLine(f_ptr);
//     printTab(f_ptr,ntab);
  }  
}


/** Procedura di supporto alla scrittura degli statement di pre e post incremento 
 * 
 * Argomenti:
 * 	element: elemento della ST per la variabile che si sta scrivendo
 * 	pnt: puntatore alla lista contenente l'espressione da stampare
 * 	unary_op: stringa contenente l'operatore di incremento o decremento da stampare
 * 	mode: intero indicante il tipo di incremento/decremento
 */
 void aggEspressioneIncremeto(symbolTablePointer element, listaStringhe * pnt, const char * unary_op, int mode){
    
  listaStringhe * lista = pnt;
  while( lista != NULL )
      {
      //printf("\n%s",lista->stringa);
      if(strcmp(lista->stringa,element->nomeToken)==0)
      {
	  char * espr = (char *) malloc(sizeof(char)*(strlen(lista->stringa) + strlen(unary_op) + 1 ));
	  if(mode==0)
	  {
	    strcat(espr, unary_op); 
	    strcat(espr, lista->stringa);
	    strcat(espr, "\0");
	  }
	  else if(mode==1)
	  {
	    strcat(espr, lista->stringa); 
	    strcat(espr, unary_op); 
	    strcat(espr, "\0");
	  }	       
      lista->stringa = espr;
      }
    lista = lista->next;
    }
 }
 
 
  /** Funzione per il controllo di una variabile, costante o elemento di un array.
  *  Gli argomento sono:
  *    - nomeToken, il nome del simbolo da aggiungere;
  *    - offset, l'indice dell'elemento;
  *    - numeroRiga, il numero riga segnalato dalla variabile yylineno di Flex;
  *    - read, specifica se l'elemento è analizzato in lettura o scrittura
  *      ( solo per elementi di un array ). 
  */
void check( char *nomeToken, char *offset, int numeroRiga, bool read )
{
  element = checkElement( nomeToken, offset, numeroRiga, read );
  current_value = element->value;
}