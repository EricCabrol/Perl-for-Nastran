=pod
=head1 Description

  Analyse d'un fichier f06 avec tri des modes par contribution decroissante en energie pour un groupe donné

=head1 Usage
   
   1.Sauvegarder le script ainsi que les packages NAS_functions.pm et STD_functions.pm dans le repertoire de son choix
   2.Modifier la ligne use lib ci-dessous afin de pointer sur le repertoire choisi en 1
   3.Créer un raccourci vers le script, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   4.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   pour rajouter C:\Perl\bin\perl.exe en DEBUT de ligne (avec un espace entre le .exe et la suite !)
   5. On peut alors traiter n'importe quel fichier f06 par un clic droit / Envoyer Vers
   
=head1 Documentation
   
   Voir le fichier word du même nom

=head1 Auteur

 E. Cabrol (DEA-SCG6)

=head1 Dernieres mises a jour

 07/07/2015	Creation

=cut


#~ This use lib commande should be modified to point to the directory in which STD_functions.pm and NAS_functions.pm are located

use lib 'I:\_My_Site\_sharediao\DIESC\caldiv_diesc_las_ef\a071431\Perl';

#~ Do not modify anything below

use File::Basename;
use STD_functions ('slow_die');
use NAS_functions ('NAS_get_input_from_f06','NAS_get_params');


$nas = NAS_get_input_from_f06($ARGV[0]);

my $check_THRESH = NAS_check_THRESH($nas);
if ($check_THRESH!=0) {
	my $rParam = NAS_get_params($nas);
	if ((! defined $rParam->{"TINY"}) or ($rParam->{"TINY"} != 0.))  {
		print "Warning : the value of PARAM TINY in the Nastran input file may not be appropriate\n";
	}
}



$out = $ARGV[0];
$out =~ s/\.f06/_sorted.txt/;

%seen = ();
%ratio = ();
$ok=0;

open FIC,"<",$ARGV[0];
while (<FIC>) {
	if (/TOTAL ENERGY OF ALL ELEMENTS IN PROBLEM/) {
		$ok=1;
		@fields=split;
		$total=$fields[-1];
		$next=<FIC>;
		@fields2=split(" ",$next);
		$mode=$fields2[1];
		unless ($seen{$mode}) {
			$seen{$mode}=1;
			$subtotal = $fields2[-1];
			#~ printf "mode %d : %.1f\n",$mode,$subtotal/$total*100;
			$ratio{$mode}= sprintf("%.1f",$subtotal/$total*100);
		}
		
	}
}
close FIC;

#~ Affichage des 30 modes avec le ratio le plus élevé
if ($ok) {
	
	open OUT,">",$out;
	print OUT;
	print OUT "mode\tnrj \%\n";
	@sorted_modes = sort {$ratio{$b}<=>$ratio{$a}} keys %ratio;
	for (1..30) {
		print OUT $sorted_modes[$_],"\t",$ratio{$sorted_modes[$_]},"\n";
	}
	close OUT;
	#~ Pour la console ...
	print "mode\tnrj \%\n";
	for (1..10) {
		print  $sorted_modes[$_],"\t",$ratio{$sorted_modes[$_]},"\n";
	}	
	print "\nThese results have been written in the file \n",basename($out),"\n";
}
else {
	slow_die("The line TOTAL ENERGY OF ALL ELEMENTS IN PROBLEM could not be found\n");
}


print "\n*** END ***\n";
print "(Press any key to close this window)";
<STDIN>;	


sub NAS_check_THRESH {
	$file=shift;
	$found = 0;
	
	open FILE,"<",$file;
	while (<FILE>) {
		if (/ESE.+THRESH.*=(.+)\)/) {$found=$1+0;}
	}
	close FILE;
	return $found;	
}
	
		

	




