#!/usr/bin/perl

use strict;
use warnings;
use LWP::Simple;
use HTML::FormatText;
use Digest::SHA;
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use File::Slurp;

my $DEBUG = 0;

my $path = "<SOMEPATH>";

my $counter = 0;

my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time);
my $date =
    ( $year + 1900 )
  . ( sprintf( "%02d", $mon + 1 ) )
  . ( sprintf( "%02d", $mday ) ) . "-"
  . ( sprintf( "%02d", $hour ) ) . ":"
  . ( sprintf( "%02d", $min ) ) . ":"
  . ( sprintf( "%02d", $sec ) );

my $textfileFULL    = "$path/epso/text/$date-epso-AD-FULL.txt";
my $textfileONLYNEW = "$path/epso/text/$date-epso-AD-NEW.txt";
my @emails          = read_file( "$path/epso/email-addresses.txt" );

my $htmlcontent = get("http://europa.eu/epso/apply/jobs/temp/index_en.htm")
  or die "Error while retrieving page: $!\n";

my $textcontent = HTML::FormatText->format_string($htmlcontent);


## CHECK!!!
# Remove any non-ascii character, as Digest::SHA barfs on those
$textcontent =~ s/[[:^ascii:]]/ /g;
## CHECK!!!

my @textarray = split( "\n", $textcontent );

my $hashstorefile = "$path/epso/text/hashes.txt";
my @hashstore     = ();

if ( -e $hashstorefile ) {
    open( FILE, $hashstorefile )
      or die("Cannot open HASH file for reading: $!\n");
}
else {
    open( FILE, ">" , $hashstorefile ) or die("Cannot create HASH file: $!\n");
    close(FILE);
    open( FILE, $hashstorefile )
      or die("Cannot open created HASH file for reading: $!\n");
}

## CHECK!!
my $hashstorecounter = 0;

while ( $hashstore[$hashstorecounter] = <FILE> ) {
    chomp( $hashstore[$hashstorecounter] );
    ++$hashstorecounter;
}
## CHECK!!

close(FILE);

my $skipfirst     = 0;
my @temparrayFULL = ();

## Variables for creation of a hash over one set of text

my @hashtemp = ();    # Actual text-record; re-used
my $newhash;          # New hash value over the actual temporary text-record

my $agency = "";

while ( defined $textarray[$counter] ) {
    $textarray[$counter] =~ s/^\s+//;

## CHECK!!
# Usually a headline for an Agency is of the form "(ENISA)", so we check for /^(
# Sadly EPSO uses brackets at the beginning of other lines as well, so we need to tackle
# each of those cases as well

    if (( $textarray[$counter] =~ m/^\(/ ) 
      && ( $textarray[$counter] !~ m/only\ applicable\ to\ candidates\ whose/ ) 
      && ( $textarray[$counter] !~ m/11\:00/ )) { 
        $agency = $textarray[$counter];
        ++$counter;

# Need special treament for ECB entries, as they are different from the others :-(
# We need to skip the first empty line after the "(ECB)" headline
# otherwise an "empty" entry for ECB is created in the next "if" statement
# (this is not necessary for the other Agencies)

        if ( $agency =~ m/ECB/ ) {
            ++$counter;
        }
    }
    if (( $textarray[$counter] =~ m/^Temporary/ ) || ($agency =~ m/ECB/)) {
        if (( !$skipfirst ) && ($textarray[$counter] =~ m/^Temporary/ )) {
            ++$skipfirst;
        }
        else {
            my $textcounter = $counter;
            my $hashcounter = $counter;

            while ( $textarray[$textcounter] !~ m/Grade/ ) {
                ++$textcounter;
            }
            if (( $textarray[$textcounter] =~ m/AD/ ) 
             || ( $textarray[$textcounter] =~ m/Grade\: L|Grade\: K|Grade\: J|Grade\: I|Grade\: H|Grade\: G|Grade\: F\/G|Grade\: F|Grade\: E\/F/ )) {
                push( @hashtemp, $agency );
                while ( $textarray[$hashcounter] ) {
                    push( @hashtemp, $textarray[$hashcounter] );
                    ++$hashcounter;
                }

                $newhash = Digest::SHA->sha256_hex(@hashtemp);

                if ( &comparehash($newhash) ) {
                    push( @temparrayFULL, "***** NEW *****" );
                }
                $newhash = '';
                push( @temparrayFULL, $agency );
                while ( $textarray[$counter] ) {
                    push( @temparrayFULL, $textarray[$counter] );
                    ++$counter;
                }
                push( @temparrayFULL, "" );
                @hashtemp = ();
            }
        }
    }
    ++$counter;
}
## CHECK!! (Make modular)


open( FILE, ">>" . $textfileFULL )
  or die "Error while opening file for Text storage: $!\n";
binmode( FILE, ":utf8" );

$counter = 0;

while ( defined $temparrayFULL[$counter] ) {
    $temparrayFULL[$counter] =~ s/^\s+//;
    print FILE "$temparrayFULL[$counter]\n";
    ++$counter;
}

close(FILE);

my $emailBODY    = read_file($textfileFULL);

my $emailSUBJECT = "[EU jobs] - AD posts published via EPSO - $date";

$counter = 0;

while ( $emails[$counter] ) {

    chomp( $emails[$counter] );

    my $email = Email::Simple->create(
        header => [
            To      => $emails[$counter],
            From    => '<SOMEADDRESS>',
            Subject => $emailSUBJECT,
        ],
        body => $emailBODY,
    );

    sendmail($email);

    ++$counter;

}

sub comparehash {

# compare the calculated hash sum of the actual text array with $counter++; # all previous hashes from the hash-file

    my $localcounter = 0;
    my $localstring  = $_[0];
    while ( $hashstore[$localcounter] ) {
        if ( $hashstore[$localcounter] eq $localstring ) {
            return undef;
        }
        ++$localcounter;
    }
    open( FILE, ">>" , $hashstorefile )
      or die "Error while opening file for Text storage: $!\n";
    binmode( FILE, ":utf8" );
    print FILE "$localstring\n";
    close(FILE);
    $hashstore[$localcounter] = $localstring;
    return 1;
}

exit 0;
