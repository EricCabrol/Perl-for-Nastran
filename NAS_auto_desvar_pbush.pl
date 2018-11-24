=pod
=head1 Description

  Creation auto des cartes DESVAR et DVPREL pour une SOL 200 "modale".
  Traite les raideurs en translation des cartes PBUSH declarees dans la
  section USER SPECIFIC ci-dessous.

=head1 Usage
   
   1.Sauvegarder le script ainsi que les packages NAS_functions.pm et STD_functions.pm dans le repertoire de son choix
   2.Modifier la ligne use lib ci-dessous afin de pointer sur le repertoire choisi en 1
   3.Créer un raccourci vers le script, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   4.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   pour rajouter C:\Perl\bin\perl.exe en DEBUT de ligne (avec un espace entre le .exe et la suite !)
   5. On peut alors traiter n'importe quel fichier bdf par un clic droit / Envoyer Vers
   
   
=head1 Documentation
   
   TODO

=head1 Auteur

 E. Cabrol (DEA-SCG6)

=head1 Dernieres mises a jour

 21/07/2015	"Nettoyage"
 20/07/2015	Creation

=cut

#~ This use lib commande should be modified to point to the directory in which STD_functions.pm and NAS_functions.pm are located

use lib 'I:\_My_Site\_sharediao\DIESC\caldiv_diesc_las_ef\a071431\Perl';

use File::Basename;
use File::Spec::Functions;
use NAS_functions ('NAS_split_line');
use STD_functions ('slow_die');


#~ USER SPECIFIC (can be modified)

@pids_list = qw(600205 600206 600207 600208); 	# List of PIDs used as design variables
$output_name = "inc_DESVAR_DVPREL.bdf";		# Name of the output file (to be used as a NASTRAN include)
$label_start = 901;						# ID of the first DVPREL1 and DESVAR cards


#~ DO NOT MODIFY ANYTHING BELOW

#~ chit-chat ...
print "This script will create DVPREL1 and DESVAR cards for SOL 200 analysis\n";
print "based on the translation stiffnesses of the following PBUSH :\n\t",join("\n\t",@pids_list);
print "\n\n";
print "If this is not what you expect, please kill this console (Ctrl+C) and edit\n";
print $0,"\n\n";

my $file = $ARGV[0];
($name,$path) = fileparse ($file);
#~ Affecting output file
$output = catfile($path,$output_name);


#~ On recupere les valeurs initiales des raideurs
$found=0;
open FIC,"<",$file;
while (<FIC>) {
	#~ Si carte PBUSH
	if (/^PBUSH/) {
		$found=1;
		#~ On splitte la ligne ...
		@cards = NAS_split_line($_);
		#~ ... et on affecte
		$stiffness->{$cards[1]}->{"X"}=$cards[3];
		$stiffness->{$cards[1]}->{"Y"}=$cards[4];
		$stiffness->{$cards[1]}->{"Z"}=$cards[5];
	}
}
close FIC;
if (! $found) {slow_die("no PBUSH card could be found in \n".basename($file));}

#~ Creation des cartes DESVAR et DVPREL
$label = $label_start;
open OUT,">",$output;
foreach $pid (@pids_list) {
	$cpt=1;
	for ("X","Y","Z") {
		#~ On affecte un label en ne gardant que les 6 derniers entiers du numero de PID
		$tmp = "k".$_.substr($pid,-6);
		print OUT "DESVAR,",$label,",",$tmp,",",$stiffness->{$pid}->{$_},"\n";
		print OUT "DVPREL1,",$label,",PBUSH,",$pid,",K",$cpt++,",,,\n";
		print OUT ",",$label,",1.0\n\$\n";
		$label++;
	}
}
close OUT;

print "File ",basename($output)," has been written\n\n";
print "\n*** END ***\n";
print "(Press any key to close this window)\n";
<STDIN>;	
	

