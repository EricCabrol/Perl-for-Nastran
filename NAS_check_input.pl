=pod
=head1 Description

  Analyse input Nastran
  
=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo ... avec le bon IPN !)
   
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   en rajoutant C:\Perl\bin\perl.exe en DEBUT de ligne 
   
   4.On peut alors traiter n'importe quel fichier input Nastran par un clic droit / Envoyer Vers

=head1 Auteur

 E. Cabrol (DEA-SCS6)

=head1 Dernieres mises a jour
 
 17/03/2015	Modifs mineures
 08/07/2014	Ajout verif REFC des RBE3
 04/06/2014	Correction get_includes (pour ne pas traiter les lignes commentees)
 23/04/2014	Mises à jour diverses
 18/04/2014	Creation

=cut

use strict;
use warnings;
use File::Basename;
use File::Spec;

#~ Parametrage utilisateur

my @liste_extensions = qw(.nas .inp .dat);

#~ Initialisation

my @includes;
my @files;
my @aset_nodes;
my @aset_refgrid_nodes;
my @failed_RBE3s;

#~ Recuperation fichier a traiter et stockage dans une liste

my $selection = $ARGV[0];
$files[0]=$selection;
my ($name,$path,$suffix) = fileparse($selection);

#~ Verification qu'on traite bien un fichier Nastran

if (! &matches_extension($selection,\@liste_extensions)) {&slow_die("Extension non autorisee");}

#~ Creation fichier sortie avec le meme prefixe (et suffixe _PRECHECK.txt)

my $output_file=$selection;
$output_file =~ s/\.[ind][na][pst]$/_PRECHECK.txt/;

open OUT,">",$output_file;

# DEBUT DES VERIFICATIONS

print OUT "Analysis of the file ",$name,"\n";
my @date = localtime(time);
printf OUT "date : %02d/%02d/%d\n\n",$date[3],$date[4]+1,$date[5]+1900;

#~ Recuperation des noms d'includes

@includes = &get_includes($selection);

# Verification que les includes sont bien presents

if ($#includes>0) {
	print "Checking includes : ";
	push (@files,@includes);
	my $nb_missing_includes=0;
	foreach my $inc (@includes) {
		if (! -e $inc) {
			print "\n\t",basename($inc)," is missing !";
			$nb_missing_includes++;
		}
	}
	if ($nb_missing_includes==0) {print "OK\n";}
}


#~ Verification des cartes pour Adams

print "Verification des cartes pour condensation Adams\n";
print OUT "Verification des cartes pour condensation Adams\n";

my $rCheck = &check_adams($selection);

if (! defined $rCheck->{"mnf"}) {
	print "\tCarte ADAMSMNF absente\n";
	print OUT "\tCarte ADAMSMNF absente\n";
}
if (! defined $rCheck->{"dti"}) {
	print "\tCarte DTI absente\n";
	print OUT "\tCarte DTI absente\n";
}
if (! defined $rCheck->{"stress_plot"}) {
	print "\tCarte STRESS(PLOT) absente\n";
	print OUT "\tCarte STRESS(PLOT) absente\n";
}

#~ Recuperation des parametres

my $rParam = get_params($selection);

if ((! defined $rParam->{"POST"}) or ($rParam->{"POST"} != -2))  {
	print "\tIl faut utiliser PARAM,POST,-2\n";
	print OUT "\tIl faut utiliser PARAM,POST,-2\n";
}
if ((! defined $rParam->{"AUTOQSET"}) or ($rParam->{"AUTOQSET"} !~ /YES/))  {
	print "\tIl faut utiliser PARAM,AUTOQSET,YES\n";
	print OUT "\tIl faut utiliser PARAM,AUTOQSET,YES\n";
}

#~ Verification du champ REFC des RBE3

@failed_RBE3s = &check_RBE3_REFC(\@includes);
if ($#failed_RBE3s >0) {
	print "\nWARNING : REFC fields of some RBE3 elements are probably incorrect\n";
	print "\t(see CHECK file for further details)\n";
	print OUT "\nWARNING : REFC fields of some RBE3 elements are probably incorrect\n";
	print OUT "\t",join("\n\t",@failed_RBE3s),"\n";
	print OUT "\t(Recommended REFC field is 123456)\n";
}

#~ Recherche du nb de noeuds dans le ASET

@aset_nodes = &get_ASET_nodes($selection);

# Verification qu'aucun des ASET nodes n'est REFGRID d'un RBE3

if (scalar(@aset_nodes) >0) {
	
	print scalar(@aset_nodes)," ASET (condensation) nodes have been found\n";
	print OUT scalar(@aset_nodes)," ASET (condensation) nodes have been found\n";
	
	print "\nChecking that ASET nodes are not REFGRIDs : ...\n";
	print OUT "\nChecking that ASET nodes are not REFGRIDs : ...\n";
	
	@aset_refgrid_nodes = &check_ASET_not_REFGRID(\@aset_nodes,\@includes);

	if (scalar(@aset_refgrid_nodes) >0) {
		print "ERROR : some ASET nodes are REFGRIDs for RBE3 => NOT OK !!!\n";
		print OUT "ERROR : some ASET nodes are REFGRIDs for RBE3 => NOT OK !!!\n";
		print "(see detailed list in the CHECK file)\n";
		print OUT "IDs : ",join(" ",@aset_refgrid_nodes),"\n";

	}
	else {
		print  "\t\t => OK\n";
		print OUT "\t\t => OK\n";
	}

}

else {
	print "\nERROR : No condensation nodes have been found\n";
	print OUT "\nERROR : No condensation nodes have been found\n";
}
	
# FIN

close OUT;
print "\n\n\nEcriture du fichier \n",basename($output_file),"\n\n";
print "************** FIN DU SCRIPT ****************\n";
print "(Appuyez sur une touche pour fermer la fenetre)\n";
my $end=<STDIN>;



#~ ********************* FONCTIONS *******************

sub get_includes {
	
	my $file=shift;
	my @inc;
	
	my ($name,$path) = fileparse ($file);
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	
	while (<FILE>) {
		#~ if (/INCLUDE/) {		# Modif 04/06/2014
		if (/^INCLUDE/) {
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

#~ **************************************************

sub matches_extension {
	my $file = $_[0];
	my @list = @{$_[1]};
	my $match=0;
	
	my ($name,$path,$suffix) = fileparse($file,qr/\.[^.]*/);
	
	foreach my $ext (@list) {
		#~ print $ext;
		if ($ext eq $suffix) {$match=1;}
	}
	return $match;
}
	

#~ **************************************************
	
sub check_adams {
	
	my $file=shift;
	my $check = {};
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	while (<FILE>) {
		if (/^ADAMSMNF/) {$check->{"mnf"}=1;}
		if (/^DTI/) {$check->{"dti"}=1;}
		if ((/^STRESS/) and (/PLOT/)) {$check->{"stress_plot"}=1;}
	}
	close FILE;
	return $check;
}


#~ **************************************************
	
sub get_params {
	
	my $file = shift;
	my $param = {};
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	while (<FILE>) {
		if (/PARAM/) {
			my @data = &decompose_nastran_line($_);
			$param->{$data[1]}=$data[2];
		}
	}
	close FILE;
	return $param;
	
}

#~ **************************************************
	
sub check_ASET_not_REFGRID {
	
	my @nodes = @{$_[0]};
	my @files = @{$_[1]};
	my @failed;

	foreach my $file (@files) {
		open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
		while (<FILE>) {
			if (/^RBE3/) {
				my @fields = &decompose_nastran_line($_);
				my $node_number = $fields[2];
				foreach my $node (@nodes) {
					if ($node_number==$node) {
						push (@failed,$node);
					}
				}
			}
		}
	}
	return (@failed);

}

#~ **************************************************
	
sub check_RBE3_REFC {
	
	my @files = @{$_[0]};
	my @failed;

	foreach my $file (@files) {
		open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
		while (<FILE>) {
			if (/^RBE3/) {
				my @fields = &decompose_nastran_line($_);
				my $refc = $fields[3];
				if ($refc !~ /123456/) {
					my $eid = $fields[1];
					push(@failed,$eid);
				}
			}
		}
	}
	return(@failed);
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