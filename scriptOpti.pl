#!/bin/perl/
#
# Ce script permet de génerer automatiquement les fichiers nécessaires
# à la réalisation d'un calcul de minimisation des transferts vibratoires
# sur une plage de frequences donnée
#
# NB : attention a la numerotation des autres cartes DRESP presentes
# dans le .inp pour eviter les conflits avec les cartes generees par 
# ce script.
#
# Evolutions : 
# - ecriture de l'ensemble des cartes dans un seul fichier inp, sans include
# - quasi-automatisation de la saisie des variables de conception, il
#   n'y a plus qu'à entrer les numéros de pid
#
# (E. Cabrol - Novembre 2006)
#
#
#
# UN PEU DE SAISIE ...
#
print "Nom de l'analyse (nom du fichier input sans extension) ?\n";
$nom = <STDIN>;
$nom =~ s/ /_/g;
chop $nom ;
print "Quel est le nom du fichier contenant le set des noeuds de calcul des transferts ?\n";
$include1 = <STDIN>;
chop $include1 ;
print "Quel est le nom du fichier contenant le bulk data ?\n";
$include2 = <STDIN>;
chop $include2 ;
# On extrait la liste des pids
$sys1=`grep PSHELL $include2 > liste_pids.txt`;
open(tmp,"liste_pids.txt");
# On crée un tableau associatif contenant pids et épaisseurs associées
while (<tmp>) {
	$pid=substr($_,8,8)+0;
	$ep{$pid}=substr($_,24,8)+0;
}
close(tmp);
# On continue les saisies
print "Sur quelle bande de frequence souhaitez-vous faire l'analyse modale ?\n";
print "frequence min :\n";
$fmin = <STDIN>;
chop $fmin ;
print "frequence max :\n";
$fmax = <STDIN>;
chop $fmax ;
print "Quel est le numero du noeud d'excitation ?\n";
$ndExcit = <STDIN> ;
chop $ndExcit;
print "Quelle est la direction d'excitation (1 pour X, 2 pour Y, 3 pour Z ...) ?\n";
$direcExcit = <STDIN>;
chop $direcExcit;
print "Sur quelle bande de frequence souhaitez-vous minimiser les transferts ?\n";
print "frequence min :\n";
$fminTr = <STDIN>;
chop $fminTr ;
print "frequence max :\n";
$fmaxTr = <STDIN>;
chop $fmaxTr ;
print "Nombre de variables de conception ?\n";
$nbVar = <STDIN>;
chop $nbVar ;
print "Entrez, pour chaque variable de conception, le numero de PID\n";
for ($k=0;$k<$nbVar;$k++) {
   $var[$k]=<STDIN>;
   chop $var[$k];
   $tab[$k][0]="P".$var[$k];
   $tab[$k][1]=$var[$k];
   $tab[$k][2]=$ep{$var[$k]}-0.5;
   $tab[$k][3]=$ep{$var[$k]}+0.5;
   $tab[$k][4]=$ep{$var[$k]};
}
#
# PETIT DETOUR POUR CALCULER LE NOMBRE DE NOEUDS PRIS EN COMPTE DANS LE CALCUL
#
open (fic3a,$include1);
$/=undef;
$listeNoeuds = <fic3a>;
$listeNoeuds =~ s/SET \d+ +=//g;
$listeNoeuds =~ s/ //g;
$listeNoeuds =~ s/\n//g;
@listeNoeuds = split(/,/,$listeNoeuds);
print "\n";
print scalar(@listeNoeuds)," noeuds pris en compte\n";
print "Attention, la carte SUPORT est à modifier dans l'input généré, ainsi que\n les contraintes sur la masse\n";
close(fic3a);
#
#
# Nombre de cartes DRESP1 à generer
#
$nb_DRESP1=scalar(@listeNoeuds)*($fmaxTr-$fminTr+2)/2*3;
#
# ON ECRIT L'INPUT ...
#
open (fic1,">".$nom.".inp");
print fic1 ("TIME 100000\n");
print fic1 ("SOL 200\n");
print fic1 ("CEND\n");
print fic1 ("ECHO = NONE\n");
print fic1 ("INCLUDE '".$include1."'\n");
print fic1 ("DLOAD        = 995\n");
print fic1 ("FREQ         = 998\n");
print fic1 ("METHOD       = 1 \n");
print fic1 ("ANALYSIS =  MFREQ\n");
print fic1 ("DESOBJ = ",$nb_DRESP1+1,"\n");
print fic1 ("DESGLB = 999\n");
print fic1 ("\$\n");
print fic1 ("BEGIN BULK\n");
print fic1 ("INCLUDE '".$include2."'\n");
print fic1 ("EIGRL,1,".$fmin.".,".$fmax.".\n");
print fic1 ("RLOAD1,995,996,,,997\n");
print fic1 ("DAREA,996,".$ndExcit.",".$direcExcit.",1.0\n");
print fic1 ("FREQ1,998,".$fminTr.".,2.,",($fmaxTr-$fminTr)/2,"\n");
print fic1 ("TABLED1,997,,,,,,,,+suite\n");
print fic1 ("+suite,1.,1.,800.,1.,ENDT\n");
print fic1 ("SUPORT,346,3,184887,23,183748,123\n");
print fic1 ("USET1,U6,123,".$ndExcit."\n");
print fic1 ("\$\n");
for ($k=0;$k<$nbVar;$k++) {
    print fic1 ("DESVAR,",$k+1,",".$tab[$k][0].",".$tab[$k][4].",".$tab[$k][2].",".$tab[$k][3].",0.5\n");
}
for ($k=0;$k<$nbVar;$k++) {
    print fic1 ("DVPREL1,",$k+1,",PSHELL,".$tab[$k][1].",4,".$tab[$k][2].",".$tab[$k][3].",\n");
    print fic1 (",",$k+1,",1.\n");
}
print fic1 ("DCONSTR,999,888,0.470,0.479\n");
print fic1 ("DRESP1,888,MASSE,WEIGHT,,,,,ALL\n");
print fic1 ("DOPTPRM,P1,2,P2,15\n");
print fic1 ("\$\n");
#
# CREATION DES EQUATIONS
#
print fic1 ("DEQATN    889   MOYENNE\(X1,X2,X3");
$i=4;
$j=0;
while ($i < $nb_DRESP1+1) {
   print fic1 (",","X",$i);
   $j++;
   if ($j==8) {
      print fic1 ("\n        ");
      $j=0;
   }
   $i++;
}
$i=4;
print fic1 ("\)\n        =AVG\(MAX(ABS(X1),ABS(X2),ABS(X3))\n");
while ($i < $nb_DRESP1) {
   print fic1 ("        ,MAX(ABS(X",$i,"),ABS(X",$i+1,"),ABS(X",$i+2,"))");
   if ($i<$nb_DRESP1-2) {
   	print fic1 ("\n");
   }
   $i+=3;
}
print fic1 ("\)*100000.\n");   
#
# CREATION DES CARTES DRESP1
#
$j=0;
foreach $num (@listeNoeuds) {
   foreach (1..($fmaxTr+2-$fminTr)/2) {
      print fic1 ("DRESP1,",$j+1,",x",$num,"f",$_,",FRDISP,,,1,",$fminTr+($_*2-2),".,",$num,"\n");
      print fic1 ("DRESP1,",$j+2,",y",$num,"f",$_,",FRDISP,,,2,",$fminTr+($_*2-2),".,",$num,"\n");
      print fic1 ("DRESP1,",$j+3,",z",$num,"f",$_,",FRDISP,,,3,",$fminTr+($_*2-2),".,",$num,"\n");
      $j+=3;
   }
   print fic1 ("\$\n");
}   
#
# CREATION DES CARTES DRESP2
#
$i=0;
print fic1 ("DRESP2,",$nb_DRESP1+1,",moyenne,889,,\n"); 
print fic1 (",DRESP1");
$i=1;
while ($i<$nb_DRESP1+1) {
  print fic1 (",",$i);
  if ($i==$nb_DRESP1) {last}
  if (($i%7)==0) {
     print fic1 (",\n,");
  }
  $i++;
}
print fic1 ("\n\$\n");
print fic1 ("PARAM,DESPCH,0\n");
print fic1 ("PARAM,NASPRT,0\n");
print fic1 ("PARAM    BAILOUT      -1\n");
print fic1 ("PARAM   MAXRATIO   5E+06\n");
print fic1 ("PARAM     GRDPNT       0\n");
print fic1 ("PARAM     NEWSEQ      -1\n");
print fic1 ("PARAM     PRGPST      NO\n");
print fic1 ("PARAM       MPCX     899\n");
print fic1 ("PARAM      K6ROT     1.0\n");
print fic1 ("PARAM       POST      -2\n");
print fic1 ("PARAM    AUTOSPC     YES\n");
print fic1 ("PARAM          G    0.06\n");
print fic1 ("PARAM      DDRMM      -1\n");
print fic1 ("PARAM   CURVPLOT       1\n");
print fic1 ("PARAM       TINY      0.\n");
print fic1 ("ENDDATA\n");
