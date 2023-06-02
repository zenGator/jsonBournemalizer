#!/usr/bin/perl
# https://github.com/zenGator/jsonBournemalizer
# zG:20230601

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#use and constants here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#ToDo:  implement/uncomment
#use strict;
use warnings;
use Getopt::Std; 		#need for commandline flags
use POSIX;				#need for time

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#declare subroutines here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub usage;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#pre-processing
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# switches followed by a : expect an argument
# see usage() below for explanation of switches
my $commandname=$0=~ s/^.*\///r;  #let's know our own name
my %opt=();
getopts('dhi:o:l:', \%opt) or usage();		

my $debugging=TRUE if $opt{d};
usage () if ( $opt{h} ) ;

#piping /dev/stdin is not an option; piping stdout|stderr (or redirect if specified) is an option
open(my $inFH, '<:encoding(UTF-8)', $opt{i}) or die "Could not open file '$opt{i}' $!";

my $outFH=*STDOUT;
if ($opt{o}) {
    open($outFH, '>:encoding(UTF-8)', $opt{o}) 
        or die "Could not open file '$opt{o}': $!\n";
    }
*STDOUT=$outFH;

my $logFH=*STDERR;
if ($opt{l}) {
    open($logFH, '>:encoding(UTF-8)', $opt{l}) 
        or die "Could not open file '$opt{l}': $!\n";
    }
*STDERR=$logFH;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#declare variables here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
my $lineCount=0;  #primary counter, the line we are currently processing
my %allFields;
my %outBuff;
my $starttime= strftime ("%Y.%m.%dT%H:%M:%SZ", gmtime time);

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#main
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf $logFH "started at %s\n",$starttime if $debugging;	#only do this if desired/requested

#ToDo:  split the raw file into lines using something like this:
#		sed 's/^\[//;s/},{/}\n{/g' (also drops opening [
# 		but would then need to build an array and iterate through
# something like this:
#	while (my $row=<>){
#		chomp $row;
#		@records=split(/},{/,$row);
#		$rc++; 
#		printf "record count: %d\n",$#records+1;
#		printf "%d: %s\n\tfirst: %s, last: %s\n",$lineCount,$row,$records[0], $records[$#records];
#		}
# then for (@records) instead of while (my $row = <$inFH>)

#take a pass through entire file to find all the field names
while (my $row = <$inFH>) {		#get a line
	chomp $row;					#discard trailing newline char
    $lineCount++;  						# increment line counter
	if ($row !~/^{.*}\]?$/){
		printf $outFH "\n\n%d: %s\n\n", $lineCount, $row;	
		die "Doesn't begin/end with curley braces.\n"; 	
		}
#ToDo:  Test first three chars:  we expect [{"
	$row =~ s/^{"(.*)}\]?$/$1/;  #strip the opening quote because the parsing will drop opening quote for each name/field; drop the closing brace (& bracket if this is the last row)
	while ($row) {		#so long as there's data remaining on the row, do this
#printf $logFH "%s\n", $row;
		$row =~ s/^([^"]*)":("[^"]*"|[0-9.]*|\[[^]]*\]|\{[^}]*\}|(true|false|null))(,"|$)//;
#ToDo:  put the pattern into a variable that can be used both here and below
#printf $outFH "1: %s\t 2: %s\n", $1, $2;
		my $newFN=$1;			#$newFN is newly-discovered field name
#printf $outFH "%s\n", $newFN;
		$allFields{$newFN}++;	#increment the value for the key with this field/name
		}		#end processing the record/row/object
	}		#end of the first major while loop

#at this point $allFields is a master list (and template) containing all the names/fields in the objects that make up the Json array
	
	printf $logFH "Fieldname               : Count\n" if $debugging;	#could probably shorten this by using >" "*24< or something
	foreach my $key (sort keys %allFields){		#cycle through all the discovered field names
		printf $logFH "%24s: %s\n",$key,$allFields{$key} if $debugging; #shows occurences of each field across all records, but shown only if desired/requested
		$outBuff{$key}="null";	#outbuff serves as template
#ToDo:  can probably just reuse allFields as template
#		printf $outFH "%s: %s\n",$key,$outBuff{$key}; 	#dbg: template values=null	
		printf $outFH "%s\t",$key;		#generates the header row for the output file
		}
	printf $outFH "\n";		#close off the header

#go back to the top; we won't need to do this after changing to using an in-memory array
seek $inFH, 0, 0;
$lineCount=0;		#need to reset the line counter

while (my $row = <$inFH>) {		#as above, cycle through every line/object/record
	#my %currLine = ();		# don't seem to be using this
    #get a line
	chomp $row;		#drop trailing newline chars
    $lineCount++;  # increment line counter
	$row =~ s/^{"(.*)}\]?$/$1/;  #need to strip the opening quote and final brace/bracket
	while ($row) {		#now processing the row/object/record; loop so long as there's still more to process
		$row =~ s/^([^"]*)":("[^"]*"|[0-9.]*|\[[^]]*\]|\{[^}]*\}|(true|false|null))(,"|$)//;  #ToDo:  the number RE could be more specific, e.g., [-+]?[0-9]+\.?[0-9]*; what's more, Json actually can have exponential notation, so . . . there's that
		my $fieldName=$1;			#popping the fieldname from the above substitution
		my $newVal=$2;			#popping the value from the above
		$outBuff{$fieldName} = $newVal;	#build a hash table for this line
		}									#finished processing this line/record/object
	foreach my $key (sort keys %outBuff){  #need to sort to keep everything aligned
#		printf $outFH "%s: %s\n",$key,$allFields{$key}; 	#dbg
#		printf $outFH "%s: %s\n",$key,$outBuff{$key}; 	#dbg		
		printf $outFH "%s\t",$outBuff{$key};	#write output
		$outBuff{$key}="null";					#set each field to null; should be synched with usage in first loop
		}										#finished writing the output record
	printf $outFH "\n";							#close of the record with a newline
	}									#loop back for another line if available



my $endtime= strftime ("%Y.%m.%dT%H:%M:%SZ", gmtime time);
printf $logFH "ended at %s\n",$endtime if $debugging; 		#only do this if desired/requested
#ToDo:  calculate elapsed time and add to logfile

    
exit 0;

sub usage() {  #provides help
    print "like this: \n\t".$commandname." -i [infile] -o [outfile] [-l [logfile]] [-d]\n";
    print "\nThis will ingest a Json array consisting of multiple objects and produce a tab-separated file where each input object is considered a record, and each name/value pair is considered a field/value.  The entire array will be examined to produce a master record template in which all name/fields are represented.  For any object/record which doesn't contain each name/field found, the output record (line) will include the word 'null' as a placeholder.\n";
	print "\nNB:  Using 'null' is less than ideal since 'null' is one of the valid values in Json, but we're going to live with it for now.  In a future revision, we will use '<NULL>' to indicate the specific name/field was not present in the source Json array.\n";
    print "\nWe expect to see a Json array similar to this:\n";
    print "\n[{\"sing\":\"song\",\"number\":99.9,\"state\":true,\"count\":[1,2,3],\"pets\":{\"cat\":true,\"dog\":\"rover\",\"rat\":null}},{\"ding\":\"dong\",\"numero\":1,\"state\":false,\"alphabet\":[\"a\",\"b\",\"c\"],\"pets\":{\"cat\":false,\"dog\":\"fido\",\"rat\":null}}]\n";
print "\nKey characteristics are: \n\t(1) beginning with [{\"\n\t(2) ending with }]\n\t(3) each object/record being divided by },{\n\t(4) and the general Json syntactical requirements.  Reference https://datatracker.ietf.org/doc/html/rfc8259.\n";
    print "\nThis does NOT accommodate white space surrounding the structural characters ({,},[,],:, & ,).  A future version should allow for such.\n";	
    print "\nThe Json objects will only be parsed at their top level.  That is, any values/fields that are arrays or objects will be preserved in the output in their original form.  Perhaps at some point an effort will be made to create subfields (e.g., \"pets:cat\", \"pets:dog\", and \"pets:rat\" from the above exemplar), but don't hold your breath.\n";
    print "\nThis is intended to normalize fairly-similar records within a Json array.\n";
    exit 1;
    }
