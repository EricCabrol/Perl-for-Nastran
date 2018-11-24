=pod
=head1 Description

 Prend un include Nastran en argument et cree un input pour analyse modale
 
=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   en rajoutant C:\Perl\bin\perl.exe en DEBUT de ligne 
   4. On peut alors traiter n'importe quel include par un clic droit / Envoyer Vers

=head1 Auteur

 E. Cabrol (DEA-SCS6)

=head1 Dernieres mises a jour

 22/04/2015	Corrections bugs
 13/03/2015	Corrections mineures 
 25/11/2014	Creation

=cut

use File::Spec::Functions;
use File::Basename;

$include_name = basename($ARGV[0]);

$edc = 'I:\_My_Site\_sharediao\DIESC\caldiv_diesc_las_ef';
$dir = 'reference_acoustique\02_CALCUL\021_ANALYSE_MODALE';
$template_name = 'template_modal_analysis.nas';

$template_file = catfile($edc,$dir,$template_name);
open TMPL,"<",$template_file or slow_die("Unable to find ",$template_file);

$nas_file = $ARGV[0];
if ($ARGV[0] !~ /\.[bdi][daln][ftkc]/) {slow_die("Only extensions allowed : bdf - blk - dat - inc");}

$nas_file =~ s/\.[bdi][daln][ftkc]/\_sol103.nas/; #On remplace l'extension

open NAS,">",$nas_file;

while (<TMPL>) {
	if (/^INCLUDE/) {print NAS "INCLUDE '$include_name'\n";}
	elsif (/^EIGRL/) {
		print "Frequency range ?\n";
		print "(Default : -1 100)\n";
		$ans = <STDIN>;
		if (length($ans)<2) {@tab =(-1,100);}
		else {
			chomp($ans);
			@tab = split(" ",$ans);
		}
		for (@tab) {if (!/\./) {$_ .= ".";}}	# On ajoute la decimale quand il n'y en a pas
		print NAS "EIGRL,1,",$tab[0],",",$tab[1],"\n";
	}
	else {print NAS $_;}
}
close NAS;
close TMPL;

print "Press Return to close the window\n";
<STDIN>;
	

# -----------------------------------------------------------------------------------#


=pod
=head1 Description

  Remplace die pour permettre une tempo dans les scripts "double-clic" avant la
  fermeture de la console

=cut


sub slow_die {
	my $msg = shift;
	print $msg;
	print "\n\n------ FATAL ERROR ------\n\n";
	sleep(5);
	die;
}