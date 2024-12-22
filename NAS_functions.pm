package NAS_functions;

# E. Cabrol (DEA-SCG6) Renault
# Last update of this package : 22/07/2015

use Exporter;      		
@ISA = ('Exporter');

# 				SUB NAME					# LAST VERSION
@EXPORT_OK= 'NAS_dload_from_subcase';			
push @EXPORT_OK, 'NAS_data_from_dload';
push @EXPORT_OK, 'NAS_get_dfreq';
push @EXPORT_OK, 'NAS_get_params';				# 16/03/2015
push @EXPORT_OK, 'NAS_split_line';				# 20/07/2015
push @EXPORT_OK, 'NAS_get_input_from_f06';
push @EXPORT_OK, 'NAS_get_freqs_from_f06';		# 16/03/2015
push @EXPORT_OK, 'NAS_get_thickness';			# 16/03/2015
push @EXPORT_OK, 'NAS_get_includes';			# 16/03/2015




# -----------------------------------------------------------------------------------#



=pod
=head1 Description

  Returns the DLOAD called in a subcase

=cut

sub NAS_dload_from_subcase {
	my $fichier = shift;
	my $numero = shift;		#subcase number

	open INP,$fichier or &slow_die("$fichier introuvable");
	my $traite = 0;
	my $dload;
	my $withSubcase=0;
	while (<INP>) {
		# s'il n'y a pas de subcases dans l'input 
		#(il y en a tjs un dans le resultat)
		if ((/^\s*DLOAD\s*=\s*(\d+)$/)and ($withSubcase==0)) {print "toto\n";$dload = $1;}
		# et s'il y en a
		if (/^\s*SUBCASE\s+$numero\s*$/) {$traite = 1;$withSubcase=1;}
		if ((/^\s*SUBCASE/)and(! /\s+$numero\s*$/)){$traite = 0;$withSubcase=1;}
		if (($traite)and(/^\s*DLOAD\s*=\s*(\d+)$/)) {$dload = $1;}
	}
	close(INP);
	return($dload);
}

# -----------------------------------------------------------------------------------#


=pod
=head1 Description

  Returns node number and DOF of a DLOAD card

=cut

sub NAS_data_from_dload {
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

#-----------------------------------------------------------------------------------#

=pod
=head1 Description

  Recupere le pas frequentiel dans un input Nastran

=cut


sub NAS_get_dfreq {
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

# -----------------------------------------------------------------------------------#

=pod
=head1 Description

  Returns a hash with PARAM "keys and values"

=cut

sub NAS_get_params {
	
	#~ 16/03/2015

	my $file = shift;
	my $param = {};
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	while (<FILE>) {
		if (/PARAM/) {
			my @data = NAS_split_line($_);
			$param->{$data[1]}=$data[2];
		}
	}
	close FILE;
	return $param;
	
}

# -----------------------------------------------------------------------------------#

=pod
=head1 Description

  Découpe une ligne Nastran et retourne les champs correspondants
  Fonctionne en champs fixes (8 caractères) ou en champs libres (séparateur virgule)

=cut

sub NAS_split_line {
	
	#~ Version du 20/07/2015
	
	my $line = shift;
	my @fields;
	
	chomp($line);
	
	#~ Si on traite une ligne de commentaire 
	if ($line =~ /^\$/) {return(0);}
	
	#~ Si la ligne est en champs libres
	if ($line=~ /,/) {
		@fields = split (/,/,$line);
		#~ Si ça commence par une virgule, le split donne un champ vide
		if (($fields[0]eq"") or ($fields[0] =~ /\s+/)) {$fields[0]="CONTINUE";}
	}
	
	#~ Si on ne trouve pas de virgule c'est qu'on est en champs fixes
	else {
		my $length = length $line;				# Longueur de ligne
		my $min=($length <= 72 ? $length : 72);	# pour ne pas traiter plus de 72 caractères
		#~ Boucle sur la longueur "utile" de la ligne
		for (my $i=0;$i<$min;$i+=8) {
			my $cur_field=substr($line,$i,8);
			#~ Si la ligne commence par un +, on retourne un mot-clé pour indiquer une continuation line
			if ($cur_field =~ /^\s*\+/) {push(@fields,"CONTINUE");}
			#~ S'il n'y a que des espaces, on retourne un mot-clé pour indiquer un champ vide
			elsif ($cur_field eq " "x8) {push(@fields,"NULL");}
			#~ et sinon on se contente de supprimer les espaces
			else {
				$cur_field =~ s/\s+//g;		#remove spaces
				push(@fields,$cur_field);
			}
		}
	}
	return (@fields);
}

# -----------------------------------------------------------------------------------#

=pod
=head1 Description

  Returns the input file corresponding to the selected f06

=cut

sub NAS_get_input_from_f06 {

	#~ 16/03/2015
	
	my $output_file=shift;
	my $input_file;
	my @extensions = qw(nas dat inp);
	my $nb_found = 0;
	
	if ($output_file =~ /f06$/) {
		foreach my $ext (@extensions) {
			my $tmp = $output_file;
			$tmp =~ s/f06$/${ext}/;
			if (-e $tmp) {
				$input_file=$tmp;
				$nb_found++;
			}
		}
		if ($nb_found>1) {print "Warning : two corresponding input files have been found for $output_file\n\n";}
		return($input_file);
	}
	else {
		slow_die("Please select an f06 file !\n");
	}
}


# -----------------------------------------------------------------------------------#

=pod
=head1 Description

  Returns the frequencies printed in an f06 file

=cut

sub NAS_get_freqs_from_f06 {
#~ 16/03/2015

	my $fichier = shift; 	# fichier a traiter 
	
	my @values;
	my $seuil_freq_mode_solide = 1.;
	my $nb_sous_seuil=0;
	my $traite;
	my $id;
	
	open FIC, $fichier or &slow_die("Ouverture impossible de ".$fichier);
	while (<FIC>) {
		if (/\s+NO\.\s+ORDER\s+MASS\s+STIFFNESS$/) {$traite = 1;next;}	# Detection ligne debut traitement
		if (($traite)&&(/\s+\d+\s+\d+/)) {
			$id=substr($_,0,10)-1;				# numero du mode - on met le premier indice à 0 ...
			my $freq = substr($_,60,20)+0.;			# frequence
			if ($freq < $seuil_freq_mode_solide) {$nb_sous_seuil++;}
			$values[$id] = $freq;
		}
		else {$traite=0;}
		
	}
	close FIC;
	return($nb_sous_seuil,@values);
}

# -----------------------------------------------------------------------------------#

=pod
=head1 Description

  Returns a hash of thicknesses, from a list of Nastran input files

=cut

sub NAS_get_thickness {

	# MAJ 16/03/2015

	my $arg=shift;
	my @inc = @{$arg};
	foreach my $inc (@inc) {
		open INC,"<",$inc or slow_die("Unable to open ".$inc);
		while (<INC>) {
			if (/PSHELL/) {
				@fields=NAS_split_line($_);
				$thickness{$fields[1]+0}=$fields[3];
			}
		}
		close INC;
	}
	return %thickness;
}	

# -----------------------------------------------------------------------------------#


=pod
=head1 Description

  Returns a list of all the includes (_path included_ !), from Nastran main file

=cut


sub NAS_get_includes {
	
	# MAJ 16/03/2015

	my $file=shift;
	my @inc;
	
	my ($name,$path) = fileparse ($file);
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	
	while (<FILE>) {
		#~ if (/INCLUDE/) {		
		if ((/^INCLUDE/)or(/^include/)) {
			chomp;
			my @tmp = split;
			$tmp[1] =~ s/\'//g;
			#~ print $tmp[1];
			push (@inc,File::Spec->catfile($path,$tmp[1]));
		}
	}
	close FILE;
	return @inc;
}

1;