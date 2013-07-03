#!/usr/bin/perl
use strict;
use warnings;
use LWP::Simple;
use HTML::FormatText;
use Digest::SHA;

my $DEBUG = 0;

my $counter = 0;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $date = ($year+1900).(sprintf("%02d",$mon+1)).(sprintf("%02d",$mday))."-".(sprintf("%02d",$hour)).":".(sprintf("%02d",$min)).":".(sprintf("%02d",$sec));

my $textfilename = "<SOMEPATH>/text/".$date."-epso-AD.txt";
my $htmlcontent = get("http://europa.eu/epso/apply/jobs/temp/index_en.htm") or die "Error while retrieving page: $!\n";
my $textcontent = HTML::FormatText->format_string($htmlcontent);
my @textarray = split("\n",$textcontent);

my $hashstorefile = "<SOMEPATH>/text/hashes.txt";
my @hashstore = ();

if (-e $hashstorefile) {
    open(FILE,$hashstorefile) or die("Cannot open HASH file for reading: $!\n");
} 
else {
    open(FILE,">".$hashstorefile) or die("Cannot create HASH file: $!\n");
    close(FILE);
    open(FILE,$hashstorefile) or die("Cannot open created HASH file for reading: $!\n");
}

my $hashstorecounter = 0;

while ($hashstore[$hashstorecounter] = <FILE>) {
    chomp($hashstore[$hashstorecounter]);
    $hashstorecounter++;
}

close(FILE);

my $skipfirst = 0;
my @temparray = ();

## Variables for creation of a hash over one set of text

my @hashtemp = ();      # Actual text-record; re-used 
my $hashcounter = 0;
my $newhash = ();       # New hash value over the actual temporary text-record

my $agency = "";

while (defined $textarray[$counter]){
    $textarray[$counter] =~ s/^\s+//;
    if($textarray[$counter] =~ m/^\(/) {
        $agency = $textarray[$counter];
    }
    if($textarray[$counter] =~ m/^Temporary/){
        if(!$skipfirst){
            $skipfirst++;
        }
        else {
            my $tempcounter = $counter;
            while ($textarray[$tempcounter] !~ m/Grade/) {
                $tempcounter++;
            }
            if($textarray[$tempcounter] =~ m/AD/){
                push(@temparray,$agency);
                push(@hashtemp,$agency);
                push(@temparray,$textarray[$counter]);
                push(@hashtemp,$textarray[$counter]);
                $counter++;
                while ($textarray[$counter] ne ""){
                    push(@temparray,$textarray[$counter]);
                    push(@hashtemp,$textarray[$counter]);
                    $counter++;
                }
                $newhash = Digest::SHA->sha256_hex(@hashtemp);
                if (&comparehash($newhash)) { 
                    push(@temparray,"NEW!!!!!");
                }
                push(@temparray,"");
                @hashtemp = ();
                $hashcounter++;
            }
        }
    }
    $counter++;
}

open (FILE, ">>".$textfilename) or die "Error while opening file for Text storage: $!\n";                                                                                                                                                  
binmode(FILE, ":utf8");                                                                                                                                                                                                                    

$counter = 0;

while (defined $temparray[$counter]){                                                                                                                                                                                                      
    $temparray[$counter] =~ s/^\s+//;                                                                                                                                                                                                  
    print FILE $temparray[$counter]."\n";                                                                                                                                                                                              
    $counter++;                                                                                                                                                                                                                        
}                                                                                                                                                                                                                                          

close(FILE);

sub comparehash {

# compare the calculated hash sum of the actual text array with $counter++; # all previous hashes from the hash-file

    my $localcounter = 0; 
    my $localstring = $_[0];
    while ($hashstore[$localcounter]) {
        if ($hashstore[$localcounter] eq $localstring) {
        return undef;
        }
    $localcounter++;
    }
    open (FILE, ">>".$hashstorefile) or die "Error while opening file for Text storage: $!\n";
    binmode(FILE, ":utf8");
    print FILE $_[0]."\n";
    close(FILE);
    $hashstore[$localcounter] = $localstring;
    return 1;
}

exit 0;