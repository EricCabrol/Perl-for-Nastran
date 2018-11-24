=pod
=head1 Description

  Script de calcul des isoraideurs 

=head1 AUTEUR

 E. Cabrol

=head1 DERNIERES MISES A JOUR

 25/07/2011	Creation
 15/12/2011	Ajout choix fichier resultats
 12/01/2012	Ajout choix fichier calcul
 13/01/2012	Ajout pas frequentiel
 26/01/2012	Correction cas sans subcase dans l'input
 02/02/2012	Ajout ecriture fichier resultat

=cut

use strict;
use warnings;

my %corresp = (
	6000003=>"BRC",
	6000009=>"A gauche",
	6000010=>"A droit",
	6000011=>"B gauche",
	6000012=>"B droit",
	8000001=>"GMV3",
	8000003=>"GMV1"
	);
my $accel;
my @directions = qw(X Y Z);


my @results = <*.pch>;
push (@results,<*.f07>);

for (0..$#results) {
	print "\t",$_+1,") ",$results[$_],"\n";
}
print "\nQuel fichier de resultats utilise-t-on ?\n";
my $ind1 = <STDIN>;
chomp $ind1;

my $fichier = $results[$ind1-1];

my @inputs = <*.nas>;
push (@inputs,<*.inp>);

for (0..$#inputs) {
	print "\t",$_+1,") ",$inputs[$_],"\n";
}
print "\nQuel fichier de calcul utilise-t-on ?\n";
my $ind2 = <STDIN>;
chomp $ind2;

my $input = $inputs[$ind2-1];
if (! -e $input) {slow_die("Fichier $input introuvable\n");}
open RES,"<",$fichier or slow_die("Ouverture impossible du fichier resultat\n");
my ($noeud,$direction);
my $traite=0;
my @noeuds;
my %seen;
while (my $ligne=<RES>) {
	if ($ligne =~ /^\$SUBCASE/) {
		my $subcase=int(substr($ligne,8,8));
		my $dload = &dload_from_subcase($input,$subcase);
		#~ print "dload = ",$dload,"\n";
		($noeud,$direction) = &data_from_dload($input,$dload);
		#~ print "ddl =",$direction,"\n";
		push(@noeuds,$noeud) unless $seen{$noeud}++;
	}
	if (($ligne =~ /^\$ACCE/)and(int(substr($ligne,16,8))==$noeud)) {
		$traite=1;
		#~ print "ligne = ",$ligne,"\n";
		#~ print "on traite\n";
	}
	if (($ligne =~ /^\$ACCE/)and(int(substr($ligne,16,8))!=$noeud)) {
		$traite=0;
	}
	if (($traite)and($ligne =~ /\s+\d+\s+(\d\.\d+E...)\s+(-*\d\.\d+E...)\s+\d+/)) {
		my $freq = sprintf "%.0f",$1;
		my $val = $2;
		$accel->{$noeud}->{$direction}->[$freq] = $val;
	}
}
close RES;

# Plage de frequence pour calcul des isoraideurs

print "Plage de frequence ?\n";
print "(defaut = 90-360)\n";
chomp (my $plage = <STDIN>);
my ($frequence_min,$frequence_max);
if (length $plage <1) {
	$frequence_min = 90;
	$frequence_max = 360;
}
else {
	my @freq = split(/-/,$plage);
	$frequence_min = $freq[0];
	$frequence_max = $freq[1];
}
my $pas_freq = &get_dfreq($input);

open OUT,">>","resultat_inertance.txt";
print OUT "Fichier resultat : ",$fichier,"\n";
my $date = localtime;
print OUT $date,"\n";
print
print "\nCalcul des isoraideurs (10^7 N/m) sur la plage $frequence_min - $frequence_max Hz\n";
print OUT "\nCalcul des isoraideurs (10^7 N/m) sur la plage $frequence_min - $frequence_max Hz\n";
print "(pas = $pas_freq Hz)\n\n";
#~ sleep(3);
foreach my $point (@noeuds) {
	if (defined $corresp{$point}) {
		print "\n\t*** Point ",$corresp{$point}," ***\n\n";
		print OUT "\n\t*** Point ",$corresp{$point}," ***\n\n";
	}
	else {
		print "\n\t*** Noeud ",$point," ***\n\n";
		print OUT "\n\t*** Noeud ",$point," ***\n\n";
	}
	for my $composante (1..3) {
		#~ print "frequence_min = ",$frequence_min,"\n";
		#~ print "min = ",$accel->{$point}->{$composante}->[$frequence_min],"\n";
		if (defined $accel->{$point}->{$composante}->[$frequence_min]) {
			print "\tEn ",($directions[$composante-1])," : ";
			print OUT "\tEn ",($directions[$composante-1])," : ";
			my $tmp = 0;
			for (my $freq=$frequence_min;$freq<=$frequence_max;$freq+=$pas_freq) {
				if (defined $accel->{$point}->{$composante}->[$freq]) {
					$tmp += 20*log10(($accel->{$point}->{$composante}->[$freq])/1000);
				}
			}
			#~ print "tmp = ",$tmp,"\n";
			$tmp = $tmp / ($frequence_max - $frequence_min + 1);
			$tmp = $tmp - contribution_ref($frequence_min,$frequence_max);
			my $isoraideur = 10.**(6.-($tmp/20.));
			printf "%.4f\n",$isoraideur/1.e7;
			printf OUT "%.4f\n",$isoraideur/1.e7;
		}
	}
}

print OUT "\n\n*************************\n\n";
close OUT;

print "\n\nLes isoraideurs ont ete ecrites dans le fichier resultat_inertance.txt\n";
print "(Attention, le dernier calcul traite est en fin de fichier ...)\n";
print "\n\n***FIN DU SCRIPT***\n";


sleep(10);


#-------------------------------------------
#		FONCTIONS
#-------------------------------------------



sub dload_from_subcase {
	my $fichier = shift;
	my $numero = shift;

	open INP,$fichier or &slow_die("$fichier introuvable");
	my $traite = 0;
	my $dload;
	my $withSubcase=0;
	while (<INP>) {
		#~ print $withSubcase;
		# s'il n'y a pas de subcases dans l'input 
		#(il y en a tjs un dans le resultat)
		if ((/^\s*DLOAD\s*=\s*(\d+)\s*$/)and ($withSubcase==0)) {$dload = $1;}
		# et s'il y en a
		if (/^\s*SUBCASE\s+$numero\s*$/) {$traite = 1;$withSubcase=1;}
		if ((/^\s*SUBCASE/)and(! /\s+$numero\s*$/)){$traite = 0;$withSubcase=1;}
		if (($traite)and(/^\s*DLOAD\s*=\s*(\d+)\s*$/)) {$dload = $1;}
	}
	close(INP);
	return($dload);
}

sub data_from_dload {
	my $fichier = shift;
	my $numero = shift;
	my $area;
	my ($noeud,$composante);
	# On cherche les cartes RLOAD ou TLOAD (pour recuperer le numero de DAREA)
	if (! defined $numero) {print "numero dload non defini\n";sleep(5);die;}
	open INP,$fichier or &slow_die("$fichier introuvable");
	while (<INP>) {
		if ((/^\s*[RT]LOAD[12]/)and (/,/)) {
			chomp;
			my @termes = split(/,/);
			if (int($termes[1])==$numero) {$area=$termes[2];}
		}
		if ((/^\s*[RT]LOAD[12]/)and (! /,/)) {
			if (int(substr($_,8,8))==$numero) {$area=int(substr($_,16,8));}
		}
	}
	close INP;
	
	# Puis on cherche la carte DAREA elle-meme
	
	open INP,$fichier or &slow_die("$fichier introuvable");
	while (<INP>) {
		if ((/^\s*DAREA/)and (/,/)) {
			chomp;
			my @termes = split(/,/);
			if (int($termes[1])== $area) {
				$noeud = $termes[2];
				$composante = $termes[3];
			}
		}
		if ((/^\s*DAREA/)and (! /,/)) {
			if (int(substr($_,8,8)) == $area) {
				$noeud = int(substr($_,16,8));
				$composante = int(substr($_,24,8));
			}
		}
	}
	close INP;
	if (defined $noeud and defined $composante) {return($noeud,$composante);}
	if (! defined $noeud) {&slow_die("Noeud non trouve");}
	if (! defined $composante) {&slow_die("Composante non trouvee");}
	
}

sub log10 {
	my $n = shift;
	if ($n<=0) {slow_die("Argument de la fonction log10 negatif !");}
	return log($n)/log(10);
}

sub contribution_ref {
	my $freq1 = shift;
	my $freq2 = shift;
	
	my $Kref = 1e6;
	my $pi = 3.141592654;
	my $somme = 0;
	for ($frequence_min..$frequence_max) {
		my $omega2 = (2*$pi*$_)**2;
		$somme += 20*log10($omega2/$Kref);
	}
	return ($somme/($frequence_max-$frequence_min+1));

}

sub slow_die {
	my $msg = shift;
	print $msg;
	print "\nLe script se termine sur une erreur\n";
	sleep(5);
	die;
}

sub get_dfreq {
	my $fichier = shift;
	my $pas;
	open INP,$fichier or &slow_die("$fichier introuvable");
	while (<INP>) {
		if ((/^\s*FREQ1/)and (/,/)) {my @termes = split(/,/);$pas=$termes[3];}
		if ((/^\s*FREQ1/)and !(/,/)) {$pas=int(substr($_,24,8));}
	}
	return $pas;
	close INP;
}

