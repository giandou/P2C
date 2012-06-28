<?php
 function fattoriale($n){
  $a = $n;
  $m = $n;
  for($m=$n;$m>2;$m--){
    $a = $a * ($m-1);
  }

  echo "Il fattoriale di $n è $a\n";
  
 }

 fattoriale(5);
  
