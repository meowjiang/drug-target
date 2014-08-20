#!/usr/bin/perl
use strict;
use warnings;
#---------------------------------------------------------------------------------------------------------------------------------------------
# Purpose	: Automated work from prepared destination files to shortestpath output and to shortestpath analyzer 
# Input		: source (STDBsource), destfile directory, String proteinlink_maxdistXX file, output dir for network files
# Output	: four input files; shortestpath output files; shortestpath analysis files
# Author	: Hansaim Lim
# Date		: 19 Aug, 2014
#---------------------------------------------------------------------------------------------------------------------------------------------
die "Usage: $0 <source.txt> <directory for dest files> <String-UniProt-distance file> <foldername: ./networks_XXupmaxXX>\n" unless @ARGV == 4;
my $source = shift @ARGV;
my $destdir = shift @ARGV;
my $string = shift @ARGV;
my $network_upper_dir = shift @ARGV;

chomp($network_upper_dir);
unless ($network_upper_dir =~ m/\/$/){
	$network_upper_dir .= "/";	#add the end slash for directory if not entered by the user
}

#-------------------------------------Creation of the input files (network files; node, edge, source, dest) started-------------------------------------
my %sources = ();
open(SRC, "<$source") or die "Could not open file $source: $!\n";
while(<SRC>){
        my $gene = $_;
        chomp($gene);
        $sources{$gene} = 1;    #switches
}
close(SRC);

opendir my $dir, $destdir or die "Could not open directory $destdir: $!\n";
my @destfiles = readdir $dir;
for my $dest ( @destfiles ){
	next if $dest =~ m/^\.+$/;
	my $outfile_edge_temp = $dest;
	my ($network_lower_dir, $sourceoutput, $destoutput, $tempfile1, $tempfile2, $edgeoutput, $nodeoutput);
	OUTFILE1: {
        $outfile_edge_temp = "./.edgetemp.txt";
        $tempfile1 = "./.spathtemp1.txt";
        $tempfile2 = "./.spathtemp2.txt";
	}
	OUTFILE2:{
		$dest =~ m/dest(.*)(\.txt|tsv|dat)$/;
		$network_lower_dir = $network_upper_dir . $1;
		$edgeoutput = "./" .$network_lower_dir. "/edge" . $1 . $2;
		$nodeoutput = "./" . $network_lower_dir. "/node" . $1 . $2;
		$sourceoutput = "./" .$network_lower_dir. "/source" . $1. $2;
		$destoutput = "./" . $network_lower_dir. "/dest" . $1 . $2;
	}
	unless(-e $network_lower_dir or mkdir $network_lower_dir){
		die "Unable to create $network_lower_dir\n";
	}
	my $dest_with_path = $destdir . $dest;
	open(DEST, "<$dest_with_path") or die "Could not open file $dest: $!\n";
	my %destinations = ();
	while(<DEST>){
		my $gene = $_;
		chomp($gene);
		$destinations{$gene} = 1;       #switches
	}
	close(DEST);
	open(STRING, "<$string") or die "Could not open file $string: $!\n";
	open(OUTFILE, ">$outfile_edge_temp") or die "Could not open file $outfile_edge_temp: $!\n";
	my $line = 1;   #to skip first line
	STRING: while(<STRING>){
		if ($line == 1){
			$line++;
			next STRING;
		}
		my $line_intact = $_;   #the whole line
		my @words = split(/\t/, $_);
		my $gene1 = shift @words;
		my $gene2 = shift @words;

		if ($sources{$gene1}) { $sources{$gene1} = "found"; }
		if ($sources{$gene2}) { $sources{$gene2} = "found"; }
		if ($destinations{$gene1}) { $destinations{$gene1} = "found"; }
		if ($destinations{$gene2}) { $destinations{$gene2} = "found"; }
		if ($sources{$gene1} || $sources{$gene2} || $destinations{$gene1} || $destinations{$gene2}){
			print OUTFILE $line_intact;
		}
	}
	close(OUTFILE);
	close(STRING);
	open(SOURCE, ">$sourceoutput") or die "Could not open file $sourceoutput: $!\n";
	foreach my $source ( keys %sources ){
		if ($sources{$source} eq "found"){
			print SOURCE $source, "\n";
		}
	}
	close(SOURCE);
	open(DEST, ">$destoutput") or die "Could not open file $destoutput: $!\n";
	foreach my $dest ( keys %destinations ){
		if ($destinations{$dest} eq "found"){
			print DEST $dest, "\n";
		}
	}
	close(DEST);

	# Source and destination files are done at this point
	# Only edge files will be re-opened for the steps below

	my %ppi = (); #A->B = c hash container
	my $skipped = 0;
	my $edgenum = 0;	#to count Number of Edges:
	open my $edge_temp, '<', $outfile_edge_temp  or die "Could not open file $outfile_edge_temp: $!\n";
	open my $temp1, '>', $tempfile1 or die "Could not open file $tempfile1: $!\n";
	EDGE: while(<$edge_temp>){
		my @words = split(/\t/, $_);
		if ($words[0] =~ m/^Number/i){
			next EDGE;
		}
		my $p1 = shift @words;  #protein 1
		my $p2 = shift @words;  #protein 2
		my $d = shift @words;   #distance
		chomp($d);
		unless ($ppi{$p1}{$p2}){ #if the relationship is undefined yet
			unless ($ppi{$p2}{$p1}) {       #if the reverse relationship is undefined as well
				print $temp1 $p1,"\t",$p2,"\t",$d,"\n";
				$ppi{$p1}{$p2} = $d;
				$edgenum++;
				next EDGE;
			}
			#when the reverse is already defined
			$skipped++;
			next EDGE;
		}
	}
	close $edge_temp;
	close $temp1;
	print $edgenum, "edges were found for $dest\n";
	print $skipped, "edges were skipped for $dest\n";

	#--------------------create node file from temporary edge file-----------------------
	my %nodes = ();
	open my $edgetemp, '<', $tempfile1 or die "Could not open file $tempfile1: $!\n";
	while(<$edgetemp>){
		my @words = split(/\t/, $_);
		my $g1 = shift @words;
		my $g2 = shift @words;
		$nodes{$g1} = 1;
		$nodes{$g2} = 1;
	}
	close $edgetemp;

	open my $nodetemp, '>', $nodeoutput or die "Could not open file $nodeoutput: $!\n";
	my $nodenum = keys %nodes;
	print $nodetemp "Number of Nodes: ", $nodenum, "\n";
	foreach my $node ( keys %nodes ){
		print $nodetemp $node, "\t1\n";	#1 is for fold change
	}
	close $nodetemp;
	#--------------------create node file from temporary edge file-----------------------

	#--------------------add the header, Number of Edges: xxxx------------------
	open my $temp2, '<', $tempfile1 or die "Could not open file $tempfile1: $!\n";
	open my $edge_final, '>', $edgeoutput or die "Could not open file $edgeoutput: $!\n";
	print $edge_final "Number of Edges: ", $edgenum, "\n";
	while(<$temp2>){
		print $edge_final $_;
	}
	close $edge_final;
	close $temp2;
	#--------------------add the header, Number of Edges: xxxx------------------
}
closedir $dir;

my $clearcmd = "rm ";
$clearcmd .= "./.edgetemp.txt ./.spathtemp1.txt ./.spathtemp2.txt";
system($clearcmd);	#this command removes the temprary text files
#-------------------------------------Creation of the input files (network files; node, edge, source, dest) completed-------------------------------------
#-------------------------------------Running shortestpath algorithm starts here--------------------------------------------------------------------------

my $suffix_for_spath;	#file suffix for shortestpath algorithm
my $outdir_for_spath;	#output directory for shortestpath algorithm
SUFFIX: {
	$network_upper_dir =~ m/networks_(.*)\/?$/;
	$suffix_for_spath = $1;
}
SLASH: {
	$network_upper_dir .= "/" unless $network_upper_dir =~ m/\/$/;
}
OUTDIR_SPATH: {
	$network_upper_dir =~ m/networks_(.*)\/$/;
	$outdir_for_spath = "./spath_" . $1 . "/"; 
}

opendir my $dir1, $network_upper_dir or die "Cannot open directory $network_upper_dir: $!\n";
my @lowerdirs = readdir $dir1;
closedir $dir1;

LOWERDIR: foreach my $lowerdir ( @lowerdirs ){
	next LOWERDIR if $lowerdir =~ m/^\.+$/;	#skip current and previous dir (. and ..)
	my $currentdir = $network_upper_dir . $lowerdir."/";
	my ($node, $edge, $source, $dest, $outfile_shortestpath);
#---------------------------for one drug-----run shortestpath and analyze the output---------------------------------------------------------
	opendir my $dir_drug, $currentdir or die "Cannot open directory $currentdir: $!\n";
	my @files = readdir $dir_drug;
	foreach my $file ( @files ){
		next if $file =~ m/^\.+$/;
		$node = $currentdir.$file if $file =~ m/^node_/;
		$edge = $currentdir.$file if $file =~ m/^edge_/;
		$source = $currentdir.$file if $file =~ m/^source_/;
		$dest = $currentdir.$file if $file =~ m/^dest_/;
		
		if ($file =~ m/^source_(.*)(\.txt|tsv|dat)$/){	#shortestpath output filename (with path)
			$file =~ m/^source_(.*)(\.txt|tsv|dat)$/;
			$outfile_shortestpath = $outdir_for_spath . "spath_" . $1 . $suffix_for_spath . ".dat";
		}
	}
	closedir $dir_drug;
	my $spathcmd = 'shortestpath';
	$spathcmd .= " -n $node";
	$spathcmd .= " -e $edge";
	$spathcmd .= " -s $source";
	$spathcmd .= " -d $dest";
	$spathcmd .= " >> $outfile_shortestpath";
	system($spathcmd);	#this command produces shortestpath output
}
#---------------------------for one drug-----run shortestpath and analyze the output---------------------------------------------------------
#-------------------------------------Running shortestpath algorithm completed--------------------------------------------------------------------------
#-------------------------------------Analyzing shortestpath output starts here-------------------------------------------------------------------------
my $spath_dir = $outdir_for_spath;
my $spath_analysis_outdir;
my ($pathwayproperties, $pathwaydisconnect);
SPATHANALYSIS: {
	$network_upper_dir =~ m/networks_(.*)$/;
	$spath_analysis_outdir = "./spathanalysis_" . $1;
}
opendir my $dir_spath, $spath_dir or die "Could not open directory $spath_dir: $!\n";
my @spathfiles = readdir $dir_spath;
closedir $dir_spath;

for my $spathfile ( @spathfiles ){
        next if $spathfile =~ m/^\.+$/; #skip currentdir and upper dir
        OUTPUTFILE: {
                $spathfile =~ m/spath_(.*)\.(txt|tsv|dat)$/;
                $pathwayproperties = $spath_analysis_outdir . $1 . "_property." . $2;
                $pathwaydisconnect = $spath_analysis_outdir . $1 . "_disconnect." . $2;
                $spathfile = $spath_dir.$spathfile;
        }


        open my $spathfileinput, '<', $spathfile or die "Could not open file $spathfile: $!\n";
        open my $spath_property, '>', $pathwayproperties or die "Could not open file $pathwayproperties: $!\n";
        open my $spath_disconnect, '>', $pathwaydisconnect or die "Could not open file $pathwaydisconnect: $!\n";
        print $spath_property "source\tdest\tedges\tcum_dist\tavg_dist_per_edge";
        print $spath_disconnect "source\tdestinations_disconnected_to";
        my $current_source_disc = '';   #current source for disconnected pathways

        SPATH_LINE1: while(<$spathfileinput>){
                my $line_intact = $_;
                next SPATH_LINE1 if $line_intact =~ m/^the\snumber\sof/i;
                next SPATH_LINE1 if $line_intact =~ m/^0\.\..*0$/;
                next SPATH_LINE1 if $line_intact =~ m/^\->1e\+07/i;

                if ($line_intact =~ m/^No\spath\sfrom/i){
                        #organize and output for disconnected pathways
                        $line_intact =~ m/^No\spath\sfrom\s(.+)\sto\s(.+)$/;
                        my $source_disc = $1;
                        my $dest_disc = $2;
                        if ($source_disc eq $current_source_disc) {
                                #no need to change the line of output
                                print $spath_disconnect "\t", $dest_disc;
                        } else {
                                $current_source_disc = $source_disc;    #update current source of disconnection
                                print $spath_disconnect "\n";
                                print $spath_disconnect $source_disc, "\t", $dest_disc;
                        }
                        next SPATH_LINE1;
                }
                my @words = split(/\.\./, $_);
                my $last_index = scalar(@words) - 1;    #equals to pathway size (number of nodes in the pathway)
                my $dest_index = $last_index - 1;       #index for destination; equal to the number of edges
                chomp($words[$last_index]);
                my $cum_dist = $words[$last_index];
                DISTANCE: {
                        $cum_dist =~ m/\->(.+)$/;
                        $cum_dist = $1;
                }
                my $avg_dist_per_edge = $cum_dist / $dest_index;
                print $spath_property "\n", $words[0], "\t", $words[$dest_index], "\t", $dest_index, "\t", $cum_dist, "\t", $avg_dist_per_edge;
        }

        close $spath_disconnect;
        close $spath_property;
        close $spathfileinput;
}
#-------------------------------------Analyzing shortestpath output completed---------------------------------------------------------------------------

exit;
