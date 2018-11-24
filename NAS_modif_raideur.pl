=pod
=head1 Description

  Modification des termes de raideur dans un fichier Nastran

=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   en rajoutant C:\Perl\bin\perl.exe en DEBUT de ligne 
   4. On peut alors traiter n'importe quel fichier f06 par un clic droit / Envoyer Vers
   5.
   
=head1 Documentation
   
   Voir le fichier word du même nom

=head1 Auteur

 E. Cabrol (DEA-SCG6)

=head1 Dernieres mises a jour

 06/07/2015	Creation

=cut


@liste_pids = qw(600207 600208 600205 600206);

#~ Do not modify anything below

my $file = $ARGV[0];

print "Coefficient ?\n";
$coef = <STDIN>;
chomp $coef;

print "Termes de raideur à modifier ?\n";
print "(TRANS/ROT/BOTH)\n";
$ans=<STDIN>;
$output = $file;
$tmp=$coef;
if ($tmp =~ /\./) {$tmp =~ s/\./p/;} # pour faire jouli quand le coef est "non-entier"
if ($ans=~/TRANS/) {$ddl1 = 3; $ddl2 = 5;$output =~ s/\.bdf/_Kt_coef$tmp\.bdf/;}
if ($ans=~/ROT/) {$ddl1 = 6; $ddl2 = 8;$output =~ s/\.bdf/_Kr_coef$tmp\.bdf/;}
if ($ans=~/BOTH/) {$ddl1 = 3; $ddl2 = 8;$output =~ s/\.bdf/_Ktr_coef$tmp\.bdf/;}


open FIC,"<",$file;
open OUT,">",$output;
while (<FIC>) {
	#~ Si carte PBUSH
	if (/^PBUSH/) {
		#~ On splitte la ligne
		@cards = NAS_split_line($_);
		
		$match=0;
		#~ Pour chaque pid à remplacer
		foreach $pid (@liste_pids) {
			#~ Si ca matche
			if ($pid == $cards[1]) { 
				$match=1;
				#~ On multiplie les raideurs des ddls a traiter
				for ($j=$ddl1;$j<=$ddl2;$j++) {
					$cards[$j] = sprintf "%3.2E",$cards[$j]*$coef;
					$cards[$j] =~ s/E\+0/E\+/;
				}
				#~ On concatene puis on ecrit
				$line = join "",@cards;
				print OUT $line,"\n";
			}
		}
		#~ Si la pid ne faisait pas partie de celles à traiter on recopie
		if ($match==0) {print  OUT;}
	}
	#~ Si on n'a pas de PBUSH on recopie
	else {print OUT};
}
close FIC;
close OUT;
print "Press any key to close this window\n";
<STDIN>;	
	

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
