#!/usr/bin/perl
use strict;
use warnings;
use LWP::Simple;
use HTML::FormatText;
use Digest::SHA;

my $DEBUG = 0;

# Where are we, on the live server or on the development system?

my $path = "<SOMEPATH>";

my $counter = 0;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $date = ($year+1900).(sprintf("%02d",$mon+1)).(sprintf("%02d",$mday))."-".(sprintf("%02d",$hour)).":".(sprintf("%02d",$min)).":".(sprintf("%02d",$sec));

my $textfileFULL = $path."/epso/text/".$date."-epso-AD-FULL.txt";
my $textfileONLYNEW = $path."/epso/text/".$date."-epso-AD-NEW.txt";

my $htmlcontent = get("http://europa.eu/epso/apply/jobs/temp/index_en.htm") or die "Error while retrieving page: $!\n";
my $textcontent = HTML::FormatText->format_string($htmlcontent);
my @textarray = split("\n",$textcontent);

my $hashstorefile = $path."/epso/text/hashes.txt";
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
my @temparrayFULL = ();

# TODO: initialize the array for only the new records
# my $temparrayONLYNEW = ();

## Variables for creation of a hash over one set of text

my @hashtemp = ();      # Actual text-record; re-used 
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
            my $textcounter = $counter;
            my $hashcounter = $counter;
            while ($textarray[$textcounter] !~ m/Grade/) {
                $textcounter++;
            }
            if($textarray[$textcounter] =~ m/AD/){
                push(@hashtemp,chomp($agency));
                push(@hashtemp,chomp($textarray[$hashcounter]));
                $hashcounter++;
                while ($textarray[$hashcounter] ne ""){
                    push(@hashtemp,chomp($textarray[$hashcounter]));
                    $hashcounter++;
                }
                $newhash = Digest::SHA->sha256_hex(@hashtemp);
                if (&comparehash($newhash)) { 
                    push(@temparrayFULL,"***** NEW *****");

# TODO: routine to fill the array with text for only new entries
# to be done in this 'if' statement!

                }
                push(@temparrayFULL,$agency);
                while ($textarray[$counter] ne ""){
                    push(@temparrayFULL,$textarray[$counter]);
                    $counter++;
                }
                push(@temparrayFULL,"");
                @hashtemp = ();
            }
        }
    }
    $counter++;
}

open (FILE, ">>".$textfileFULL) or die "Error while opening file for Text storage: $!\n";                                                                                                                                                  
binmode(FILE, ":utf8");                                                                                                                                                                                                                    

$counter = 0;

while (defined $temparrayFULL[$counter]){                                                                                                                                                                                                      
    $temparrayFULL[$counter] =~ s/^\s+//;                                                                                                                                                                                                  
    print FILE $temparrayFULL[$counter]."\n";                                                                                                                                                                                              
    $counter++;                                                                                                                                                                                                                        
}                                                                                                                                                                                                                                          

close(FILE);

# TODO: here the routine to write only new records to another file
# open (FILE, ">>".$textfileONLYNEW) or die "Error while opening file for Text storage: $!\n";                                                                                                                                                  
# binmode(FILE, ":utf8");                                                                                                                                                                                                                    
#
# $counter = 0;
#
# while (defined $temparrayFULL[$counter]){                                                                                                                                                                                                      
#     $temparrayFULL[$counter] =~ s/^\s+//;                                                                                                                                                                                                  
#     print FILE $temparrayFULL[$counter]."\n";                                                                                                                                                                                              
#     $counter++;                                                                                                                                                                                                                        
# }                                                                                                                                                                                                                                          
#
# close(FILE);


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