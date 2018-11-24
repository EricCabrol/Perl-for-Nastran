=pod
=head1 Description

  Extraction des coordonnees des noeuds de condensation

=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   pour ajouter C:\Perl\bin\perl.exe en DEBUT de ligne 
   4. On peut alors traiter n'importe quel jeu de donnees nastran par un clic droit / Envoyer Vers

=head1 Auteur

 E. Cabrol (DEA-SCG6)

=head1 Dernieres mises a jour

 05/05/2015	Creation
 
=head1 TODO

 Integrer la fonction de recuperation des ASET nodes
 

=cut

use File::Basename;
use File::Spec::Functions;
#~ use strict;
#~ use warnings;

@condensation_nodes = qw(300001 300005 300006 300018 300020 300041 300042 300050);

#~ Adding symmetric nodes
push(@condensation_nodes,map{$_+100000} @condensation_nodes);

#~ Assigning name of the output file
$out = $ARGV[0];
$out =~ s/\.\w{3}/_NODES.txt/;
open OUT,">",$out;

#~ Scanning main file
scan_file($ARGV[0]);

#~ Retrieving includes
@includes = NAS_get_includes($ARGV[0]);

#~ Scanning includes
foreach $inc (@includes) {
	print "\nScanning include ",basename($inc),"\n";
	scan_file($inc);
}


#~ End
close OUT;
print "\nInformation has been duplicated in \n";
print basename($out),"\n\n";
print "(Press return to close this window)\n";
<STDIN>;
	
	
	
sub scan_file {
	$fic = shift;
	open FIC,"<",$fic;
	$k=0;
	while ($line=<FIC>) {
		if($k++==100000) {print ".\n";$k=0;}
		if ($line =~ /^GRID/) {
			my @fields =NAS_split_line($line);
			@iNode = $fields[1];
			if (($fields[1] =~ /^3/)or($fields[1] =~ /^4/)) {
				if (isInList(\@condensation_nodes,\@iNode)) {
					print join ",",$fields[1],@fields[3..5];
					print OUT join ",",$fields[1],@fields[3..5];
					print "\n";
					print OUT "\n";
				}
			}
		}
	}
	close FIC;
}

sub NAS_get_includes {

#~ 16/03/2015
#~ use File::Basename;
#~ use File::Spec::Functions;
# Calls slow_die
	
	my $file=shift;
	my @inc;
	
	my ($name,$path) = fileparse ($file);
	
	open FILE,"<",$file or &slow_die("Ouverture impossible de ".$file);
	
	while (<FILE>) {
		if ((/^INCLUDE/)or(/^include/)) {
			chomp;
			my @tmp = split;
			$tmp[1] =~ s/\'//g;
			push (@inc,File::Spec->catfile($path,$tmp[1]));
		}
	}
	close FILE;
	#~ if (scalar @inc <1) {print "Warning : no include found !\n\n";}
	return @inc;
}


sub slow_die {
	my $msg = shift;
	print $msg;
	print "\n\n------ FATAL ERROR ------\n\n";
	sleep(5);
	die;
}


sub NAS_split_line {
	
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
			#~ if (($cur_field !~ /\+/) and ($cur_field !~ /,/) and ($cur_field !~ /^\s+$/) ) {
			if (($cur_field !~ /\+/) and ($cur_field !~ /,/) ) {
				$cur_field =~ s/\s+//g;		#remove spaces
				push(@fields,$cur_field);
			}
		}
	}
	return (@fields);
}


sub isInList {
	my @liste = @{$_[0]};
	my @sous_liste = @{$_[1]};
	
	my $ok = 1;
	for my $val1 (@sous_liste) {
		my $match = 0;
		for my $val2 (@liste) {
			if ($val1 eq $val2) {$match=1};
		}
		$ok = $ok * $match;
	}
	
	return ($ok);
}	