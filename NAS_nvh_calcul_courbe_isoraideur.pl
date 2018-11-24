=pod
=head1 Description

  Script de calcul et trace de courbes d'isoraideurs 

=head1 AUTEUR

 E. Cabrol

=head1 DERNIERES MISES A JOUR

 15/02/2016	Conversion VML=>SVG
 29/04/2014	Ajout sortie amplitude (au clic)
 01/03/2012	Ajout trace courbes
 02/02/2012	Ajout ecriture fichier resultat
 26/01/2012	Correction cas sans subcase dans l'input
 13/01/2012	Ajout pas frequentiel
 12/01/2012	Ajout choix fichier calcul
 15/12/2011	Ajout choix fichier resultats
 25/07/2011	Creation

=cut

use strict;
use warnings;

my %corresp = (
	6000003=>"BRC",
	6000009=>"A gauche",
	6000010=>"A droit",
	6000011=>"B gauche",
	6000012=>"B droit",
	8000001=>"GMV",
	8000003=>"RAS"
	);
my $accel;
my @directions = qw(X Y Z);


my @results = <*.pch>;
push (@results,<*.f07>);

for (0..$#results) {
	print "\t",$_+1,") ",$results[$_],"\n";
}
print "\n Which results file do you select ?\n";
my $ind1 = <STDIN>;
chomp $ind1;
if (length $ind1 <1) {&slow_die("A file must be selected");}

my $fichier = $results[$ind1-1];

my @inputs = <*.nas>;
push (@inputs,<*.inp>);
push (@inputs,<*.dat>);

for (0..$#inputs) {
	print "\t",$_+1,") ",$inputs[$_],"\n";
}
print "\n Which corresponding input file do you select ?\n";
my $ind2 = <STDIN>;
chomp $ind2;
if (length $ind2 <1) {&slow_die("A file must be selected");}


my $input = $inputs[$ind2-1];
if (! -e $input) {slow_die("File $input can not be found\n");}
open RES,"<",$fichier or slow_die("File $fichier can not be read\n");
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

print "Frequency range ?\n";
print "(default = 90-360)\n";
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



print "Curves identifier ?\n";
chomp (my $id_courbes = <STDIN>);

open OUT,">>","resultat_inertance.txt";
print OUT "Results file : ",$fichier,"\n";
my $date = localtime;
print OUT $date,"\n";
print
print "\nDynamic stiffnesses (isoraideurs) (10^7 N/m) in the range $frequence_min - $frequence_max Hz\n";
print OUT "\nDynamic stiffnesses (isoraideurs) (10^7 N/m) in the range $frequence_min - $frequence_max Hz\n";
print "(increment = $pas_freq Hz)\n\n";
#~ sleep(3);
foreach my $point (@noeuds) {
	my $affich;
	if (defined $corresp{$point}) {$affich = $corresp{$point};}
	else {$affich = $point;}
	print "\n\t*** Point ",$affich," ***\n\n";
	print OUT "\n\t*** Point ",$affich," ***\n\n";
	for my $composante (1..3) {
		my @freqs;
		my @values;
		#~ print "frequence_min = ",$frequence_min,"\n";
		#~ print "min = ",$accel->{$point}->{$composante}->[$frequence_min],"\n";
		if (defined $accel->{$point}->{$composante}->[$frequence_min]) {
			print "\tEn ",($directions[$composante-1])," : ";
			print OUT "\tEn ",($directions[$composante-1])," : ";
			my $tmp = 0;
			for (my $freq=$frequence_min;$freq<=$frequence_max;$freq+=$pas_freq) {
				if (defined $accel->{$point}->{$composante}->[$freq]) {
					$tmp += 20*log10(($accel->{$point}->{$composante}->[$freq])/1000);
					push(@freqs,$freq);
					push(@values,20*log10(($accel->{$point}->{$composante}->[$freq])/1000));
				}
			}
			my $nom_courbe = "courbe_inertance_".$affich."_".$directions[$composante-1]."_".$id_courbes.".html";
			#~ creation_courbe_VML($nom_courbe,\@freqs,\@values);
			creation_courbe_SVG($nom_courbe,\@freqs,\@values);
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

print "\n\nDynamic stiffnesses (isoraideurs) have been written \n in the file resultat_inertance.txt\n";
print "(Caution : the last results are at the end of this file...)\n";
print "\n\n***END***\n";


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
		if ((/^\s*DLOAD\s*=\s*(\d+)\s*/)and ($withSubcase==0)) {$dload = $1;}
		# et s'il y en a
		if (/^\s*SUBCASE\s+$numero\s*/) {$traite = 1;$withSubcase=1;}
		if ((/^\s*SUBCASE/)and(! /\s+$numero\s*/)){$traite = 0;$withSubcase=1;}
		if (($traite)and(/^\s*DLOAD\s*=\s*(\d+)\s*/)) {$dload = $1;}
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


sub creation_courbe_SVG {
	
	#~ MAJ 15/02/2016
	
	my $rapport = $_[0];		# nom du rapport
	my @X = @{$_[1]};		# liste des valeurs X
	my @Y = @{$_[2]};		# liste des valeurs Y
	
	my ($axe_X,$axe_Y);
	my ($dim_X,$dim_Y)=(800,400);		# Carré
	my $orig_X = 100;
	my $orig_Y = $dim_Y + 100;			# Positionnement "Y" (from top) initial
	
	# Entete
	open RAPPORT,">",$rapport;
	print RAPPORT <<EOF;
<!DOCTYPE HTML> 
<html> 
<head>
</head>
<style type="text/css">
body {
	margin: 0px 0px 0px 0px;
}

#infobulle{
	position: absolute;	
	visibility : hidden;
	font-family: Verdana, Arial;
	font-size: 0.7em;
}
</style>


<body>
EOF
	
	# Recherche des min max
	my ($min_X,$max_X) = &min_max_fromList(\@X);
	my ($tmp_min,$tmp_max) = &min_max_fromList(\@Y);
	
	# Arrondi a la dizaine ...
	my $min_Y = (int($tmp_min/10)-1)*10.;
	my $max_Y = (int($tmp_max/10)+1)*10.;
	
	#~ Début du bloc SVG
	print RAPPORT '<svg height="'.$dim_Y.'" width="'.$dim_X.'">',"\n";
	
	# Trace des axes
	print RAPPORT '<line x1="'.$orig_X.'" y1="'.$orig_Y.'" x2="'.($orig_X+$dim_X).'" y2="'.$orig_Y.'" style="stroke:black;stroke-width:2" />',"\n";
	print RAPPORT '<line x1="'.$orig_X.'" y1="'.$orig_Y.'" x2="'.$orig_X.'" y2="'.($orig_Y-$dim_Y).'" style="stroke:black;stroke-width:2"  />',"\n";
	


	# Trace de la courbe
	print RAPPORT '<polyline points="';
	for my $pt (0..$#X) {
		my $pos_X = $orig_X + $dim_X*($X[$pt]-$min_X)/($max_X-$min_X);
		my $pos_Y = $orig_Y - $dim_Y*($Y[$pt]-$min_Y)/($max_Y-$min_Y);
		printf RAPPORT "%.3f,%.3f",$pos_X,$pos_Y;
		if ($pt != $#X) {print RAPPORT " ";}
	}

	#~ fin de la polyline avec appel au javascript
	print RAPPORT '" onclick=affiche()  style="fill:none;stroke:black;stroke-width:1" />',"\n";

	# Trace du quadrillage horizontal
	for (my $yline=$min_Y+5;$yline<$max_Y;$yline+=5) {
		my $ycord = $orig_Y - $dim_Y*($yline-$min_Y)/($max_Y-$min_Y);
		print RAPPORT '<line stroke-dasharray="1,5" x1="'.$orig_X.'" y1="'.$ycord.'" x2="'.($orig_X+$dim_X).'" y2="'.$ycord.'" style="stroke:black;stroke-width:1" />',"\n";
	}
	
	# Trace du quadrillage vertical
	for (my $xline=$min_X+10;$xline<$max_X;$xline+=10) {
		my $xcord = $orig_X + $dim_X*($xline-$min_X)/($max_X-$min_X);
		print RAPPORT '<line stroke-dasharray="1,5" x1="'.$xcord.'" y1="'.$orig_Y.'" x2="'.$xcord.'" y2="'.($orig_Y-$dim_Y).'" style="stroke:black;stroke-width:1" />',"\n";
	}

	# Traitement des abscisses

	my $top_minAbs = $orig_Y + 20;
	my $left_minAbs = $orig_X -10;
	my $iX=0;
	my $freq_step = int(($max_X-$min_X)/100+0.5)*10;
	my $xPix_step = $freq_step/($max_X-$min_X)*$dim_X;

	for (my $tmp_X=$min_X ; $tmp_X<=$max_X ; $tmp_X+=$freq_step ) {
		printf RAPPORT '<text x="'.($left_minAbs+$iX++*$xPix_step).'" y="'.$top_minAbs.'">%.0f</text>'."\n",$tmp_X;
	}
	print RAPPORT '<text x="'.($orig_X+$dim_X+20).'" y="'.$top_minAbs.'">Hz</text>'."\n";

	# Traitement des ordonnées

	my $top_minOrd = $orig_Y +5 ;
	my $left_minOrd = $orig_X - 40 ;
	my $iY=0;
	my $ampl_step = int(($max_Y-$min_Y)/100+0.5)*10;
	my $yPix_step = $ampl_step/($max_Y-$min_Y)*$dim_Y;

	for (my $tmp_Y=$min_Y ; $tmp_Y<=$max_Y ; $tmp_Y+=$ampl_step ) {
		printf RAPPORT '<text x="'.$left_minOrd.'" y="'.($top_minOrd-$iY++*$yPix_step).'">%.0f</text>'."\n",$tmp_Y;
	}
	print RAPPORT '<text x="'.($orig_X+2).'" y="'.($top_minOrd-($iY-1)*$yPix_step).'">dB</text>'."\n"; 	# Pour l'unité
	
	#~ Fin du bloc SVG
	print RAPPORT '</svg>',"\n";
	
	# Puis le script
	
	print RAPPORT <<EOF;

<script type="text/javascript">


function affiche(){

	posx = event.x;
	posy = event.y;
	frequence = parseInt((posx - $orig_X)/$dim_X*($max_X-$min_X) + $min_X);
	amplitude = parseInt(($orig_Y -(posy))/$dim_Y*($max_Y-($min_Y)) + ($min_Y));
	bubble = document.getElementById("infobulle");
	bubble.style.left = posx;
	bubble.style.top = posy - 20;
	bubble.style.visibility = "visible";
	bubble.style.display = "block";
	bubble.innerHTML = "freq = "+frequence+" Hz<br  />ampl =  "+amplitude+" dB"; 
	
}

</script>
<div id="infobulle">Frequence</div>
</body>
</html>
EOF
	close RAPPORT;
	return(1);
}



sub min_max_fromList {
	
	my @liste = @{$_[0]}; # dereferencement de la variable passee en argument
	
	my ($min,$max);

	for my $val (@liste) {
			if (! defined $min) {$min=$val;}
			if (! defined $max) {$max=$val;}
			if ($val>$max) {$max=$val;}
			if ($val<$min) {$min=$val;}
	}
	return($min,$max);

}
