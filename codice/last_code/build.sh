#! /bin/bash

if [ -f "parser.y" ]; then
  echo "parser.y trovato"

  if [ -f "scanner.l" ]; then
    echo "scanner.l trovato"

    if [ -f "symbolTable.h" ]; then
      echo "symbolTable.h trovato"

      if [ -f "inclusioni.h" ]; then
	echo "symbolTable.h trovato"
	echo ""
	echo "Avvio della Compilazione"
# 	mkdir -p output
# 	cd output
# 	rm -f *.h *.y *.l
# 	cp ../symbolTable.h .
# 	cp ../inclusioni.h .
# 	cp ../scanner.l .
# 	cp ../parser.y .
		
	bison -v -d parser.y -o parser.c
	flex -o scanner.c scanner.l
	gcc -O0 -g0 -c parser.c
	gcc -O0 -g0 -c scanner.c
	gcc -O0 -g0 -o p2c parser.o scanner.o -lm
	echo "Script terminato"
      else
	echo "Errore, file inclusioni.h non trovato"
      fi

    else
      echo "Errore, file symbolTable.h non trovato"
    fi

  else
    echo "Errore, file scanner.l non trovato"
  fi

else
  echo "Errore, file parser.y non trovato"
fi