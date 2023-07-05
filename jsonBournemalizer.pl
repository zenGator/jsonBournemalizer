#!/usr/bin/perl
# https://github.com/zenGator/jsonBournemalizer
# zG:20230601

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#use and constants here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

use strict;
use warnings;
use Getopt::Std; 		#need for commandline flags; 
						#ToDo: consider Getopt::Long for extended argument-handling
						#ToDo: consider using built-in version/help methods: 
						#	see https://stackoverflow.com/questions/21956620/how-can-one-respond-to-the-help-flag-with-getoptstd
						#	& https://perldoc.perl.org/Getopt::Std
						#ToDo:  add means to print version (or automatically print at end of usage()
use POSIX;				#need for time

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#declare subroutines here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub usage;


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#declare variables here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
my $version="0.5_20230619";
my $lineCount=0;	#primary counter, the line we are currently processing
my $rcdnum=0;		#primary counter, the line/record we are currently processing
my %allFields;
my $starttime= strftime ("%Y.%m.%dT%H:%M:%SZ", gmtime time);
my @records;		#the main array into which we'll stuff the file
my @nullTokens;		#we'll keep track of which records have the null token we use for absent fields
my $nullToken="\"<NULL>\"";		#this is used as the value for any field that is not in a particular record/object
my $parsePattern='^([^"]*)":("[^"]*"|[0-9.]*|\[[^]]*\]|\{[^}]*\}|(true|false|null))(,"|$)'; 	#recognizes name/value pair
				#		json syntax calls for key-value pairs with the key being a string (thus quoted), and the values being:
				#			1 - "string"
				#			2 - number (pos/neg & can use exponential notation)
				#			3 - [array]
				#			4 - {object}
				#			5 - true, false, null (no quotes)
#ToDo:  the number RE could be more specific, e.g., [-+]?[0-9]+\.?[0-9]*; 
#		what's more, Json actually can have exponential notation, so . . . there's that
#ToDo:  add handling of whitespace around Json structural characters


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#pre-processing
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# switches followed by a : expect an argument
# see usage() below for explanation of switches
my $commandname=$0=~ s/^.*\///r;  	#let's know our own name
my ($infile, $outfile); 			#these are for the filenames, specefied either using switches or as positional params
my %opt=();							#used with getopts for flagged arguments
getopts('dhi:o:l:', \%opt) or usage();		

my $debugging=1 if $opt{d};
usage () if ( $opt{h} ) ;

# getopts must pop each flagged argument off the stack, leaving "trailing positional parameters"
# so here we examine what's available and assign as necessary
if ($ARGV[0]) {		#this will set the input file
	$infile = $ARGV[0];
	die "Please don't specify two input files: it's confusing.  Dying" if $opt{i};
	}
else {
	$infile = $opt{i};
	}

if ($ARGV[1]) {		#this will set the output file
	$outfile = $ARGV[1];
	die "Please don't specify two output files: it's confusing.  Dying" if $opt{o};
	}
else {
	$outfile = $opt{o};
	}

#piping /dev/stdin|stdout|stderr (or redirect) is an option
my $inFH=*STDIN;
if ($infile) {
	open($inFH, '<:encoding(UTF-8)', $infile) 
		or die "Could not open file '$infile' $!";
	}

my $outFH=*STDOUT;
if ($outfile) {
    open($outFH, '>:encoding(UTF-8)', $outfile) 
        or die "Could not open file '$outfile': $!\n";
    }
*STDOUT=$outFH;

my $logFH=*STDERR;
if ($opt{l}) {
    open($logFH, '>:encoding(UTF-8)', $opt{l}) 
        or die "Could not open file '$opt{l}': $!\n";
    }
*STDERR=$logFH;


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#main
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf $logFH "started at %s\n",$starttime if $debugging;	#only do this if desired/requested

#prepare file for parsing by removing outermost brackets and breaking objects into lines
while (my $row = <$inFH>) {		#get a line
	chomp $row;					#discard trailing newline char
    $lineCount++;  						#increment line counter
	die "extra data after expected end of Json array" if $lineCount>1; 	#there should only be a single line
	@records=split(/},{/,$row);			#break the array into single-object elements
	
#let's make sure the file begins and ends as expected, with [{"<stuff>"]}
#	die "unexpected beginning:\n$records[0]\n" if $records[0]=~ s/^\[{// != 1;			
#bloomberg hack
die "unexpected beginning:\n$records[0]\n" if $records[0]=~ s/^\[?{// != 1;			
#	die "unexpected ending:\n$records[$#records]\n" if $records[$#records] =~ s/}\]$// != 1; 
#bloomberg hack
die "unexpected ending:\n$records[$#records]\n" if $records[$#records] =~ s/}\]?$// != 1; 
#ToDo:  add flexibility by looking for closure-comma-quote to identify values after identifying name/field
	printf $logFH "record count: %d\n",$#records+1 if $debugging;
	printf $logFH "%d lines\n\nfirst:\n%s\n\nsecond:\n%s\n\nlast:\n%s\n",
		$lineCount,$records[0],$records[1],$records[$#records] if $debugging;
#ToDo:  add verbose switch and make the first, second, & last lines only show if $debugging>1
	}			


for my $record (@records) {			#take a pass through entire file to identify all the field names
	$rcdnum++;
	push(@nullTokens, $rcdnum) if $record =~ /$nullToken/; 			#keep track of any record wherein the nullToken is found
	die "first name should be quoted" if $record =~ s/^"// != 1;	#need to strip the opening quote because the parsing will drop opening quote for each name/field
	my $row=$record;		#need a working copy of the record/row/line/object; only first object needed "permanent" modif'n
	while ($row) {		#so long as there's data remaining on the row, do this
		$row =~ s/$parsePattern//;
		my $newFN=$1;			#$newFN is newly-discovered field name
		$allFields{$newFN}++;	#increment the value for the key with this field/name
		}				#end processing the record/row/object
	}								#end of the first major while loop
	printf $logFH "%d records processed\n",$rcdnum if $debugging;
	printf $logFH "there are %d instances of %s in the input; perhaps you can change those to avoid confusion.\n", $#nullTokens, $nullToken if $#nullTokens>0; 

#at this point $allFields is a master list (and template) containing all the names/fields in the objects that make up the Json array

#ToDo:  add switch to create an index for each record/object; this would be "idx" or "record #" or something, and would be the first output field	
	
	printf $logFH "Found total of %d unique names/fields:\n", (scalar keys %allFields) if $debugging;
	printf $logFH "%24s: Count\n","Fieldname" if $debugging;
	foreach my $key (sort keys %allFields){		#cycle through all the discovered field names
		printf $logFH "%24s: %s\n",$key,$allFields{$key} if $debugging; #shows occurrences of each field across all records
		$allFields{$key}=$nullToken;			#"<NULL>" distinguishes from Json null 
#DONE:  can probably just reuse allFields as template
		printf $outFH "%s\t",$key;		#generates the header row for the output file
		}
	printf $outFH "\n";		#close off the header

$rcdnum=0;		#need to reset

#second pass through all records, extracting values
for my $row (@records) {	#we should be able to just restart, and this time we can act on the rows directly
    #get a line
	chomp $row;			#drop trailing newline chars
    $rcdnum++;  		#increment line counter
#	$row =~ s/^"//;		#this was made "permanent" in the first pass by acting on $record rather than $row 
	while ($row) {		#now processing the row/object/record; loop so long as there's still more to process
		$row =~ s/$parsePattern//;
		my $fieldName=$1;			#popping the fieldname from the above substitution
		my $newVal=$2;				#popping the value from the above
		$allFields{$fieldName} = $newVal;	#build a hash table for this line
		}									#finished processing this line/record/object
	foreach my $key (sort keys %allFields){ 	#need to sort to keep everything aligned
		printf $outFH "%s\t",$allFields{$key};	#write output
		$allFields{$key}=$nullToken;			#set each field to null; should be synched with usage in first loop
		}										#finished writing the output record
	printf $outFH "\n";							#close of the record with a newline
	}									#loop back for another line if available

my $endtime= strftime ("%Y.%m.%dT%H:%M:%SZ", gmtime time);
printf $logFH "ended at %s\n",$endtime if $debugging; 		#only do this if desired/requested
#ToDo:  calculate elapsed time and add to logfile

exit 0;			#end of main; everything went well

#ToDo:  allow custom null value
#NoNeed: add suggestion to usage() re using grep -c "<NULL>" [inputJson] to test
#ToDo:  add switch to show which records have the nullToken

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#subroutines here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub usage() {  #provides help
    print "like this: \n\t".$commandname." -i [infile] -o [outfile] [-l [logfile]] [-d]\n";
    print "\nThis will ingest a Json array consisting of multiple objects and produce a tab-separated file where each input object is considered a record, and each name/value pair is considered a field/value.  The entire array will be examined to produce a master record template in which all name/fields are represented.  For any object/record which doesn't contain each name/field found, the output record (line) will include ".$nullToken." (including the quotes) as a placeholder.\n";
    print "\nWe expect to see a Json array similar to this:\n";
    print "\n[{\"sing\":\"song\",\"number\":99.9,\"state\":true,\"count\":[1,2,3],\"pets\":{\"cat\":true,\"dog\":\"rover\",\"rat\":null}},{\"ding\":\"dong\",\"numero\":1,\"state\":false,\"alphabet\":[\"a\",\"b\",\"c\"],\"pets\":{\"cat\":false,\"dog\":\"fido\",\"rat\":null}}]\n";
	print "\nKey characteristics are: \n\t(1) beginning with [{\"\n\t(2) ending with }]\n\t(3) each object/record being divided by },{\n\t(4) and the general Json syntactical requirements.  Reference https://datatracker.ietf.org/doc/html/rfc8259.\n";
    print "\nThis does NOT accommodate white space surrounding the structural characters ({,},[,],:, & ,).  A future version should allow for such.\n";	
    print "\nThe Json objects will only be parsed at their top level.  That is, any values/fields that are arrays or objects will be preserved in the output in their original form.  Perhaps at some point an effort will be made to create subfields (e.g., \"pets:cat\", \"pets:dog\", and \"pets:rat\" from the above exemplar), but don't hold your breath.\n";
    print "\nThis is intended to normalize fairly-similar objects within a Json array, but allowing for differing sets of names/fields in each object (and in differing order:  no need for names to be alphabetical).  If one were to stream the json objects, the first would need to contain all fields/names that would ever be captured.  And in that case, an awk or sed might be more efficient.  That said, jsonBournemalizer would handle out of order fields pretty easily, so there's a potential use case there.\n";
    exit 1;
    }
