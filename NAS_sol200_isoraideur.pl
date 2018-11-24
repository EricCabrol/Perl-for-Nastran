=pod

=head1 Description

  Script de generation automatique des cartes DRESP1, DRESP2 et DEQATN 
  pour une analyse de sensibilite d'isoraideur sous Nastran (SOL200)
  

=head1 Syntaxe

  perl nvh_sol200_isoraideur.pl

=head1 Auteur - Date

  E. Cabrol - 03/08/2011

=cut

use strict;
use warnings;
use Cwd;
use File::Spec::Functions;



print "\nNumero de noeud ?\n";
chomp (my $numero_noeud = <STDIN>);
if ($numero_noeud !~ /^\d+$/) {die "ERREUR : Le numero de noeud doit etre un entier !\n";}

print "\nComposante (1, 2, 3) ?\n";
chomp (my $composante = <STDIN>);
my @direction = qw(ND X Y Z);
if ($composante !~ /^[123]$/) {die "ERREUR : Les seules reponses possibles sont 1, 2 ou 3\n";}

print "\nPlage de frequence ?\n";
print "(defaut = 90-360)\n";
chomp (my $plage = <STDIN>);
my ($frequence_min,$frequence_max);
if (length $plage <1) {
	$frequence_min = 90;
	$frequence_max = 360;
}
else {
	if ($plage !~ /-/)  {die "ERREUR : Le separateur doit etre un tiret (-)\n";}
	my @freq = split(/-/,$plage);
	if (($freq[0] !~ /^\d+$/) or ($freq[1] !~ /^\d+$/)) {die "ERREUR : les bornes doivent etre des entiers\n";}
	$frequence_min = $freq[0];
	$frequence_max = $freq[1];
}
	
	

my $home = cwd();
my $nom_fichier_sol200 = "incl_dresp_isoraid_nd".$numero_noeud."_".$direction[$composante].".blk";
my $fichier_sol200 = catfile($home,$nom_fichier_sol200);

open FIC,">",$fichier_sol200 or die "Ecriture du fichier ".$nom_fichier_sol200." impossible\n";

for ($frequence_min .. $frequence_max) {
	print FIC "DRESP1,$_,REP$_,FRACCL,,,$composante,$_.,$numero_noeud\n";
}

print FIC "\$\n";

print FIC "DEQATN  998     INERT(";
my $pos = 22;
# Ecriture des arguments
for (0 .. $frequence_max-$frequence_min) {
	$pos = $pos + 2 + length($_);
	if ($pos >= 70) {print FIC "\n"," "x16;$pos=16;}
	print FIC "X",$_;
	if ($_ != $frequence_max-$frequence_min) {print FIC ",";}
}
print FIC ") =\n";
print FIC " "x16,"(20.*(";
$pos=21;
# puis l'equation
for (0 .. $frequence_max-$frequence_min) {
	$pos = $pos + 14 + length($_);
	if ($pos >= 55) {print FIC "\n"," "x16;$pos=16;}
	print FIC "LOG10(X",$_,"/1000.)";
	if ($_ != $frequence_max-$frequence_min) {print FIC "+";}
}
print FIC ")/",($frequence_max-$frequence_min+1),".)\n";
print FIC " "x16;
printf FIC " -%0.5f;\n",contribution_ref($frequence_min,$frequence_max);
print FIC " "x16,"ISORAID = 10.**(6.-(INERT/20.))\n";



print FIC "DRESP2,999,somme,998,,,,,,\n";
print FIC ",DRESP1,";
my $nr = 0;
for ($frequence_min .. $frequence_max) {
	$nr++;
	if ($nr > 7) {print FIC "\n,,";$nr=1;}
	print FIC $_;
	if ($_ != $frequence_max) {print FIC ",";}
}
close FIC;

print "\n\Les cartes DRESP1, DRESP2 et DEQATN ont ete ecrites dans l\'include\n".$fichier_sol200;
print "\n\n***FIN DU SCRIPT***\n\n";


#-------------------------------------------
#		FONCTIONS
#-------------------------------------------


sub contribution_ref {
	my $freq1 = shift;
	my $freq2 = shift;
	
	my $Kref = 1e6;
	my $pi = 3.141592654;
	my $somme = 0;
	for ($freq1..$freq2) {
		
		my $omega2 = (2*$pi*$_)**2;
		$somme += 20*log10($omega2/$Kref);
	}
	return ($somme/($freq2-$freq1+1));

}
	
	

sub log10 {
	my $n = shift;
	return log($n)/log(10);
}

