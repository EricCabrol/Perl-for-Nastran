# Script decoupage f07
# 
use File::Basename;
use File::Spec;

my $fichier = $ARGV[0];

($name,$path,$suffix) = fileparse($fichier);

open FIC,$fichier;
$compt=0;
while (<FIC>) {
	if (/SUBCASE/) {
		$compt +=1;
		close $comptFic;
		$comptFic=$compt;
		$fic = File::Spec->catfile($path,"sortie_".$compt.".txt");
		open $comptFic,">",$fic;
	}
	
	if (/^\s+\d/) {
		split;
		#~ if ($_[1] >=15) {
			print $comptFic $_[2],"\n";
		#~ }
	}
}
close FIC;
	
	
	