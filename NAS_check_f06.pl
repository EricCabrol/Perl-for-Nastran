=pod
=head1 Description

  Analyse fichier .f06 
  
=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo ... avec le bon IPN !)
   
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   en rajoutant C:\Perl\bin\perl.exe en DEBUT de ligne 
   
   4.On peut alors traiter n'importe quel fichier de resultat Nastran par un clic droit / Envoyer Vers

=head1 Auteur

 E. Cabrol (DEA-SCS6)

=head1 Dernieres mises a jour

 17/03/2015	Modifs mineures
 18/04/2014	Mises à jour diverses (restriction du choix a la selection d'un f06)
 31/03/2014	Modification gestion modes de corps rigide
 14/11/2013	Creation

=cut

use strict;
use warnings;
use File::Basename;
use File::Spec;

#~ Parametrage utilisateur
my $nb_freq_a_extraire = 5;
our $seuil_freq_mode_solide = 1.;

#~ Initialisation
my $nb_modes_solides;
my @freqs;
my @failed_nodes;
my @liste_extension = qw(.f04 .f06 .f07 .ESTIMATE);

#~ Creation fichier sortie avec le meme prefixe (et suffixe _POSTCHECK.txt)

my $selection = $ARGV[0];
if ($selection !~ /\.f06$/) {&slow_die("Ce n'est pas un fichier f06");}

my $fichier_sortie=$selection;
$fichier_sortie =~ s/\.f06$/_POSTCHECK.txt/;

#Pour compatibilite avec evolutions a venir (!)
my $nas_output;
$nas_output->{"f06"}=$selection;


#~ my $isNasOutput = 0;
#~ foreach my $extension (@liste_extension) {
	#~ my $repl = $selection;
	#~ $repl =~ s/\..+$/\.${extension}/;
	#~ if (-e $repl) {
		#~ $nas_output->{$extension}=$repl;
		#~ $isNasOutput=1;
		#~ $fichier_sortie =~ s/\.${extension}$/_POSTCHECK.txt/;
	#~ }
#~ }

print "Analyse du calcul ",basename($selection),"\n\n";


# Recuperation du fichier input correspondant

my $main_file = &get_main_file($selection);

# DEBUT DES VERIFICATIONS


open OUT,">",$fichier_sortie;

my $name = basename($selection);
print OUT "Analyse du fichier ",$name,"\n";
my @date = localtime(time);
printf OUT "date : %02d/%02d/%d\n\n",$date[3],$date[4]+1,$date[5]+1900;

# Recherche du message FATAL

&check_fatal_Nastran($nas_output->{"f06"});

#~ Recherche et affichage des singularites

@failed_nodes = &check_singularities_Nastran($nas_output->{"f06"});
if ($#failed_nodes>0) {print OUT "Liste des noeuds singuliers :\n\t";print OUT join "\t",@failed_nodes;print OUT "\n\n";}

#~ Recherche et affichage de la masse

my $mass = &get_mass_Nastran($nas_output->{"f06"});
if (defined $mass) {
	printf  "\n%s%.3f kg\n","Masse totale du modele = ",$mass*1000;
	printf  OUT "\n%s%.3f kg\n","Masse totale du modele = ",$mass*1000;
}

#~ Recherche du nb de noeuds dans le ASET

my @aset_nodes = &get_ASET_nodes($main_file);

#~ SECTION EN COMMENTAIRE CAR TROP DE FAUX WARNINGS
#~ Recherche du nb de massless nodes
#~ my $nb_massless_nodes = &get_massless_nodes($nas_output->{"f06"});
#~ Ce nb devrait etre identique au nb de noeuds de condensation
#~ if (($#aset_nodes >0) and  (defined $nb_massless_nodes)) {
	#~ if ($#aset_nodes+1 != $nb_massless_nodes) {
		#~ print "WARNING : nb of massless nodes differs from nb of ASET nodes\n";
		#~ print OUT "WARNING : nb of massless nodes differs from nb of ASET nodes\n";
		#~ print OUT "\t nb of massless nodes = ",$nb_massless_nodes,"\n";
		#~ print OUT "\t nb of ASET nodes = ",$#aset_nodes+1,"\n";
	#~ }
#~ }


# Recherche et affichage des n premieres frequences propres

($nb_modes_solides,@freqs) = &get_frequencies_Nastran($nas_output->{"f06"},$nb_freq_a_extraire);
my $nb_modes_calcules = $#freqs+1;
my $max = &get_max_number_of_modes($nas_output->{"f06"});

print "\n",$nb_modes_calcules," modes ont ete calcules";
print OUT "\n",$nb_modes_calcules," modes ont ete calcules";

if (defined $max) {
	print " (sur un total possible de ",$max,")\n";
	print OUT " (sur un total possible de ",$max,")\n";
}
else {
	print "\n";
	print OUT "\n";
}
	
#~ Warning si different de 0 ou de 6

if (($nb_modes_solides !=0)and($nb_modes_solides !=6)) {	
	print "WARNING: il y a $nb_modes_solides modes de corps rigide\n\n";
	print OUT "WARNING: il y a $nb_modes_solides modes de corps rigide\n\n";
}

#~ Affichage des premiers modes flexibles

my $nb_to_print = &min($nb_modes_calcules-$nb_modes_solides,$nb_freq_a_extraire);

print "\nListe des premiers modes flexibles : \n\n";
print OUT "\nListe des premiers modes flexibles : \n\n";
for my $cur ($nb_modes_solides..$nb_modes_solides+$nb_to_print-1) {
	printf "\tmode %02d : %.2f Hz\n",$cur+1,$freqs[$cur];	# +1 pour l'affichage ...
	printf OUT "\tmode %02d : %.2f Hz\n",$cur+1,$freqs[$cur];
}	

# Recherche et affichage des masses modales effectives

my ($returnFS,$fracsum) = &get_fracsum($nas_output->{"f06"});

if ($returnFS) {
	print OUT "\nLes fractions de masses modales ont ete trouvees dans le fichier f06\n";
	print OUT "(correspondant a la requete MEFFMASS(FRACSUM) dans le Case Control)\n";
	if ($fracsum->{'1'}->{'Y'}+0 > $fracsum->{'1'}->{'Z'}+0) {
		printf "\n%s%.2f%s\n","Le 1e mode (freq = ",$fracsum->{'1'}->{'freq'},"Hz) est vraisemblablement un mode horizontal";
		printf OUT "%s%.2f%s\n","Le 1e mode (freq = ",$fracsum->{'1'}->{'freq'},"Hz) est vraisemblablement un mode horizontal";
	}
	else {
		printf "\n%s%.2f%s\n","Le 1e mode (freq = ",$fracsum->{'1'}->{'freq'},"Hz) est vraisemblablement un mode vertical";
		printf OUT "%s%.2f%s\n","Le 1e mode (freq = ",$fracsum->{'1'}->{'freq'},"Hz) est vraisemblablement un mode vertical";
	}
	printf "\t%s%.1f%s%.1f%s\n","fraction Y = ",$fracsum->{'1'}->{'Y'}*100,"\%\t-\tZ = ",$fracsum->{'1'}->{'Z'}*100,"%";
	printf OUT "\t%s%.1f%s%.1f%s\n","fraction Y = ",$fracsum->{'1'}->{'Y'}*100,"\%\t-\tZ = ",$fracsum->{'1'}->{'Z'}*100,"%";
	
}
# FIN

close OUT;
print "\n\n\nEcriture du fichier \n",basename($fichier_sortie),"\n\n";
print "************** FIN DU SCRIPT ****************\n";
print "(Appuyez sur une touche pour fermer la fenetre)\n";
my $end=<STDIN>;



#~ ********************* FONCTIONS *******************

sub get_main_file {

	my $fichier = shift; 	# nom du fichier a traiter 

	my $job_file = $fichier;
	my $nas_file = $fichier;
	my $inp_file = $fichier;
	my ($name,$path) = fileparse($fichier);
	my @input_files;

	$job_file =~ s/\..+$/\.job/;
	$nas_file =~ s/\..+$/\.nas/;
	$inp_file =~ s/\..+$/\.inp/;

	if (-e $job_file) {
		open JOB,"<",$job_file;
		while (<JOB>) {
			if (/LISTE_FIC_ENTREE/) {
				chomp;
				s/LISTE_FIC_ENTREE=//;
				@input_files=split(':',$_);
			}
		}
		close JOB;
		return(File::Spec->catfile($path,$input_files[0]));
	}
	else {
		if (-e $nas_file) {return($nas_file);}
		if (-e $inp_file) {return($inp_file);}
	}


}
	
#~ **************************************************
sub decompose_nastran_line {
	
	my $line = shift;
	my @fields;
	
	chomp($line);
	if ($line=~ /,/) {
		$line =~ s/^\s*,//;
		#~ $line =~ s/,\s*$//;
		@fields=split(/,/,$line);
	}
	else {
		my $length = length $line;
		for (my $i=0;$i<$length;$i+=8) {
			my $cur_field=substr($line,$i,8);
			if (($cur_field !~ /\+/) and ($cur_field !~ /,/) and ($cur_field !~ /^\s+$/) ) {
				push(@fields,$cur_field);
			}
		}
	}
	return (@fields);
}

	
#~ **************************************************
		
		
sub get_frequencies_Nastran {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	my $nb_freq = shift;	# nombre de frequences a retourner
	
	my @values;
	my $nb_sous_seuil=0;
	my $traite;
	my $id;
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	while (<FIC>) {
		if (/\s+NO\.\s+ORDER\s+MASS\s+STIFFNESS$/) {$traite = 1;next;}	# Detection ligne debut traitement
		if (($traite)&&(/\s+\d+\s+\d+/)) {
			$id=substr($_,0,10)-1;	# numero du mode - on met le premier indice à 0 ...
			my $freq = substr($_,60,20)+0.;	# frequence
			#~ print $freq,"\n";
			if ($freq < $seuil_freq_mode_solide) {$nb_sous_seuil++;}
			#~ else {$values[$id] = $freq;}
			$values[$id] = $freq;
		}
		else {$traite=0;}
		
	}
	close FIC;
	return($nb_sous_seuil,@values);

}

#~ **************************************************

sub get_mass_Nastran {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	
	my $result;
	my $traite;
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	while (<FIC>) {
		if (/X\-C\.G\./) {$traite = 1;next;}	# Detection ligne debut traitement
		if (($traite)&&(/\s+X\s+(\d+\.\d+E[+-]\d{2})\s+/)) {	# Recherche d'une ligne contenant un X puis un nombre en affichage scientifique
			$result = $1;
		}
		else {$traite=0;}
	}
	close FIC;
	return($result);

}

#~ **************************************************

sub check_fatal_Nastran {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	my $failed=0;
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	print "Verification de l'absence de FATAL ERROR : ";
	while (<FIC>) {
		if (/FATAL/) {$failed=1;}
	}
	close FIC;
	if ($failed) {print "******  NOK *******\n";&slow_die("\nLe calcul contient une erreur - FIN DU SCRIPT\n");}
	else {print "OK\n";}
	return;
}

#~ **************************************************

sub get_max_number_of_modes {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	my $max;

	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);

	while (<FIC>) {
		#~ if (/A TOTAL OF \s+(\d+)\s+MODES WERE FOUND/) {
			#~ print "Nombre de modes trouves = ",$1;
		#~ }
		if (/OUT OF A POSSIBLE \s+(\d+)/) {
			$max=$1;
		}
	}
	close FIC;
	return($max);


}

#~ **************************************************

sub get_massless_nodes {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	my $nb;

	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);

	while (<FIC>) {
		if (/MNF MESSAGE:  Found (\d+) massless /) {
			$nb = $1;
		}
	}
	close FIC;
	return($nb);


}

#~ **************************************************

sub get_ASET_nodes {

	my $fichier = shift; 	# nom du fichier a traiter 
	my $traite=0;
	my @fields;

	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);

	while (my $line=<FIC>) {
		if ($line =~ /^ASET1/) {
			do {
				push @fields , &decompose_nastran_line($line);
				$line=<FIC>;
			}
			while (($line =~ /^\+/) or ($line =~ /^,/) or ($line =~ /^\s/));
		}
	}
	shift @fields;
	shift @fields;
	return @fields;
}



#~ **************************************************

sub check_singularities_Nastran {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	my $failed=0;
	my $traite;
	my @ids;
	my %seen=();
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	print "Verification de l'absence de singularites : ";
	while (<FIC>) {
		if (/MATRIX\/FACTOR DIAGONAL RATIO/) {$traite = 1;$failed=1;<FIC>;next}	# Detection ligne debut traitement - on saute une ligne
		if (($traite)&&(/^\s+(\d+)\s+/)) {
			push @ids,$1 unless $seen{$1}++;
		}
		else {$traite=0;}
	}
	close FIC;
	if ($failed) {print " NOK !!!!!\n";}
	else {print " OK\n";}
	return (@ids);
}


#~ **************************************************
sub get_fracsum {
	
	my $fichier = shift; 	# nom du fichier a traiter 
	
	my $traiteTR=0;
	my $traiteROT=0;	#non utilise 
	my $found=0;
	my $fracsumTR={};	# hash pour les fractions de masses modales en translation
	my $fracsumROT={};	# hash pour les fractions de masses modales en rotation - non utilise 
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	while (my $line=<FIC>) {
		if ($line =~ /FOR TRANSLATIONAL DEGREES OF FREEDOM/) {$traiteTR=1;$found=1;<FIC>;<FIC>;<FIC>;<FIC>;next}	# Detection ligne debut traitement - on saute 5 lignes
		if (($traiteTR)&&($line =~/^\s+\d+\s+\d+\.\d+E[+-]\d{2}\s+/)) { 	# Recherche d'une ligne contenant un entier puis un nombre en affichage scientifique
			my @termes=split(/\s+/,$line);
			$fracsumTR->{$termes[1]}->{'freq'} = $termes[2];
			$fracsumTR->{$termes[1]}->{'X'} = $termes[3];
			$fracsumTR->{$termes[1]}->{'Y'} = $termes[5];
			$fracsumTR->{$termes[1]}->{'Z'} = $termes[7];
		}
		else {$traiteTR=0;}
	}
	close FIC;
	return ($found,$fracsumTR);
}


#~ **************************************************

sub min($a1,$a2) {
	my $a1 = shift;
	my $a2 = shift;
	return ($a1 < $a2 ? $a1 : $a2);
}

sub slow_die {
	my $msg = shift;
	print $msg;
	print "\nLe script se termine sur une erreur\n";
	sleep(8);
	die;
}