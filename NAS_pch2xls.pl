=pod

=head1 Description

  Permet de mettre en colonnes les donnees d'un fichier .pch ou .f07 issu de calcul
  d'inertance Nastran afin de simplifier le copier-coller dans Excel
  

=head1 Auteur - Date

  E. Cabrol - 15/12/2011

=cut


@results = <*.pch>;
push (@results,<*.f07>);

$output_file = "tmp.txt";

for (0..$#results) {
	print "\t",$_+1,") ",$results[$_],"\n";
}
print "\nQuel fichier de resultats utilise-t-on ?\n";
$ind = <STDIN>;
chomp $ind;

$fichier = $results[$ind-1];
$col=0;

open FIC,"<",$fichier;
while (<FIC>) {
	if (/SUBCASE/) {$col++;}
	$val = substr($_,48,12);
	if ($val=~ /\d\.\d+E[+-]/) {
		$freq = int(substr($_,28,12));
		push @freqs,$freq;
		$accel->[$freq]->[$col] = $val;
	}
}
close FIC;
open OUT,">",$output_file;
for $f1 (@freqs) {
	print OUT $f1;
	for $c1 (1..$col) {print OUT "\t",$accel->[$f1]->[$c1];}
	print OUT "\n";
}

print "\n\n\nUn fichier $output_file a ete cree\n\n";
