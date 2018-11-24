#!/bin/perl
#
# E. Cabrol (Medysys) - Octobre 2005
# 
#
print "\nCe script permet de calculer la participation de PSHELLs sp�cifiques\n";
print "par rapport a l'energie de deformation totale des quads et trias,\n";
print "pour UNE fr�quence\n";
print "N�cessite un fichier nomm� liste_pid_nrj.txt avec un num�ro de\n";
print "PID par ligne, indiquant quelles sont les PSHELLs � post-traiter\n";
print "Vous devez ensuite sp�cifier le nom du jeu de donn�es\n";
print "ainsi que celui de l'unv0r contenant les resultats.\n\n";
print "Nom du fichier bulk ?\n";
$ficBlk = <STDIN>;
chop($ficBlk);
open (fic1,"$ficBlk") || die ("Impossible d'ouvrir le jeu de donn�es\n");
print "Nom de l'unv0r ? \n";
$ficResult = <STDIN>;
chop($ficResult);
open (fic2,"$ficResult") || die ("Impossible d'ouvrir le fichier unv0r\n");
close (fic1);
close (fic2);
open (ficGrep,">grep.tmp");
print ficGrep ("CQUAD\nCTRIA");
close (ficGrep);
#
# 
$sys1 = `grep -f grep.tmp $ficBlk > zzz.tmp`; # recup CQUAD et CTRIA
$sys2 = `grep ANSA_PART $ficBlk > liste_part.tmp`; # recup numeros pid
$sys3 = `csplit $ficResult /STRAIN/+12`; # suppression resultats inutiles
#
#
$sys4 = `csplit -f zz xx01 /-1\$/`;
#
open (ficPid,"liste_part.tmp") || die ("Oops");
while (<ficPid>) {
  @chaine=split(/;/,$_);
  $pid=$chaine[5];
  $nom{$pid}=$chaine[7];
}
close(ficPid);
#
open (ficPidSpecif,"liste_pid_nrj.txt")|| die ("Ne pas oublier le fichier de PIDs");
while (<ficPidSpecif>) {
	chop ($_);
	push(@pidCible,$_);
}
#
open (fic3,"zz00");
while ($ligne=<fic3>) {
      $ind = substr($ligne,2,8);
      $ligne=<fic3>;
      $val = substr($ligne,2,11);
      $tot += $val;
      $nrj[$ind]= $val;
}
close (fic3);
print "\n",$tot,"\n";
#
open (fic4,"zzz.tmp");
while ($ligne=<fic4>) {
      $id = substr($ligne,8,8);
      $prop = substr($ligne,16,8)+0;
      $nrjTot{$prop} += $nrj[$id];
}
foreach $u (keys (%nrjTot)) {$nrjTot{$u}=$nrjTot{$u}/$tot*100.}
# On trie les propri�t�s par ordre d'�nergie croissante
@triCle = sort { $nrjTot{$a} <=> $nrjTot{$b} } @pidCible;
foreach $k (@triCle) {
	printf ("%s = %4.2f\%\n",$nom{$k},$nrjTot{$k});
}
close(fic4);
#
#
$sys5 = `rm xx0? zz0?`;
$sys6 = `rm zzz.tmp grep.tmp liste_part.tmp`;
