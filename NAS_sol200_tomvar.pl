=pod
=head1 Description

 Prend un f06 de sol 103 en argument et cree un input pour optimisation topometrique
 
=head1 Usage
   
   1.Sauvegarder le script dans le repertoire de son choix 
   2.Créer un raccourci, et le placer dans le dossier SendTo 
   (C:\Users\IPN_PERSO\AppData\Roaming\Microsoft\Windows\SendTo)
   3.Clic droit sur le raccourci / Proprietes / Editer le champ Cible
   en rajoutant C:\Perl\bin\perl.exe en DEBUT de ligne 
   4. On peut alors traiter n'importe quel f06 par un clic droit / Envoyer Vers

=head1 Auteur

 E. Cabrol (DEA-SCS6)

=head1 Dernieres mises a jour

 16/03/2015	Creation

=cut

use File::Spec::Functions;
use File::Basename;

$default_freq_delta = 0.005;

if ($ARGV[0] !~ /\.f06$/) {slow_die("Only extension allowed : f06");}

$f06 = $ARGV[0];

#Get frequencies from f06 
($nb_modes_solides,@freqs) = &f06_get_flex_frequencies($f06);		

#Get the corresponding input file
$sol103_input = NAS_get_input_from_f06($f06);	

#Get includes from input
@includes = &NAS_get_includes($sol103_input);		

#Get thicknesses from all bulk data files
@bdf=@includes;
push(@bdf,$sol103_input);
%thickness = &NAS_get_thickness(\@bdf);


# Specify the name for the sol 200 input that will be written
$sol200_input=$f06;
if ($f06 =~ /_sol103\.f06$/) {$sol200_input =~ s/_sol103\.f06/_sol200\.nas/;}
else {$sol200_input =~ s/\.f06/_sol200\.nas/;}

print "*** SOL 200 automatic generation ***\n\n";

#~ Questions/answers
print scalar(@freqs)," flexible modes have been found in the f06 file\n";
print "How many of them do you want to constrain in the optimization run ?\n";
print "\n";
chomp($nb_freqs_to_constrain = <STDIN>);
print "\n";


print "PIDs to be optimized ?\n";
print "(Enter space-separated labels)\n";
print "\n";
chomp($pid_list= <STDIN>);
@pids = split(/ /,$pid_list);
print "\n";

print "Allowed decrease for these frequencies ?\n";
print "(Exemple : enter 0.01 for 1% decrease)\n";
print "(default = 0.005 - corresponding to 0.5%)\n";
print "\n";
chomp($freq_delta = <STDIN>);
if (length($freq_delta)<1){$freq_delta=$default_freq_delta;}
print "\n";


open sol103,"<",$sol103_input;
open sol200,">",$sol200_input;

while (<sol103>) {
	if (/^SOL 103/) {print sol200 "SOL 200\n";}
	elsif (/^CEND/) {print sol200 "CEND\nANALYSIS=MODES\n";}
	elsif (/^METHOD/) {
		print sol200;
		print sol200 "DESOBJ(MIN) = 10\n";
		print sol200 "DESSUB = 20\n";
		print sol200 "MODTRAK = 30\n";
	}
	elsif(/^EIGR/) {
		print sol200; #Repetition methode
		print sol200 "DRESP1,10,masse,WEIGHT\n"; # reponse masse appelee par DESOBJ
		
		# boucle sur les pids
		$i1=1;
		for $pid (@pids) {	
			print sol200 "TOMVAR,",$i1++,",PSHELL,",$pid,",T,",$thickness{$pid},"\n";
		}
		
		# boucle sur les frequences
		for $i2 (1..$nb_freqs_to_constrain) {
			print sol200 "DRESP1,",10+$i2,",f",$i2+$nb_modes_solides,",FREQ,,,",$i2+$nb_modes_solides,"\n";
		}
		print sol200 "MODTRAK,30,",$nb_modes_solides+1,",",$nb_modes_solides+$nb_freqs_to_constrain,"\n";
		for $i3 (1..$nb_freqs_to_constrain) {
			#~ print  sol200 "DCONSTR,",20+$i3,",",10+$i3,",",$freqs[$i3-1]*(1-$freq_delta),"\n";
			print  sol200 "DCONSTR,",20+$i3,",",10+$i3,",",sprintf("%.1f",$freqs[$i3-1]*(1-$freq_delta)),"\n";
		}
		print sol200 "DCONADD,20,";
		print sol200 join(",",map($_+20,(1..$nb_freqs_to_constrain)));
		print sol200 "\n";
	}

	elsif(/^ENDDATA/) {
		print sol200 "PARAM,DESPCH,1\n";
		print sol200 "PARAM,DESPCH1,1\n";
		print sol200;
	}
	else {print sol200;}
}


close sol103;
close sol200;
print "SOL 200 file has been written\n\n";
print "*** END OF SCRIPT ***\n";
print "(Press Return to close this window)\n";
<STDIN>;
	

#~ ********************* FONCTIONS *******************


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

#~ **************************************************

sub f06_get_flex_frequencies {
	
	my $file = shift; 	# nom du fichier a traiter 
	
	my $freq_rigid_mode = 1.;
	my @values;
	my $nb_below_limit=0;
	my $traite;
	my $id;
	
	open FIC, $file or &slow_die("Ouverture impossible de ".$file);
	while (<FIC>) {
		if (/\s+NO\.\s+ORDER\s+MASS\s+STIFFNESS$/) {$traite = 1;next;}	# Detection ligne debut traitement
		if (($traite)&&(/\s+\d+\s+\d+/)) {
			#~ $id=substr($_,0,10)-1;			# numero du mode - on met le premier indice à 0 ...
			my $freq = substr($_,60,20)+0.;		# frequence
			if ($freq < $freq_rigid_mode) {$nb_below_limit++;}
			else {$values[$id++] = $freq};
		}
		else {$traite=0;}
		
	}
	close FIC;
	return($nb_below_limit,@values);

}

#~ **************************************************

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
	if (scalar(@inc) <1) {print "Warning : no include found !\n\n";}
	return @inc;
}

#~ **************************************************
#~ 16/03/2015
sub NAS_get_input_from_f06 {
	
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


#~ **************************************************


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

#~ **************************************************

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
			if (($cur_field !~ /\+/) and ($cur_field !~ /,/) and ($cur_field !~ /^\s+$/) ) {
				$cur_field =~ s/\s+//;
				push(@fields,$cur_field);
			}
		}
	}
	return (@fields);
}

