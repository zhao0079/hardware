#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
my $dir = cwd;
my %count;             ## Order file
my %dbparts;           ## BOM-ex database file
my %prices;            ## Final prices after quantity optimization
my %boards;            ## Multiples of boards

use Dumpvalue;
my $dumper = new Dumpvalue;

my @inputfiles = @ARGV;

########## SETTINGS ############

## BOM-ex part database
my $partsdb = "../pixhawk2/PIXHAWK2-PARTS-DATABASE.csv";

## FILE FORMATS

## Field-delimiter of the BOM-ex database file
my $dbsplitchar = "\t";

## Field-delimiter of the BOM-ex export file
# ALWAYS USE TAB TO AVOID ERRORS!
my $filesplitchar = "\t"; # Recommended
#my $filesplitchar = /,/; # Use is discouraged

## BOM file setup
my $key_col = 0;       ## Index where the key (part number) is stored
my $quantity_col = 4;  ## Index where the quantity is stored

## DATABASE file setup
my $q1col = 5;         ## First quantity column, e.g. 1 or 10
my $q2col = 6;         ## Second quantity column, e.g. 25 or 50
my $q3col = 7;         ## Third quantity column, e.g. 100 or 250

my $p1col = 9;         ## First price column, e.g. $1.00 per piece when ordering 1
my $p2col = 10;        ## Second price column, e.g. $0.80 per piece when ordering 25
my $p3col = 11;        ## Third price column, e.g. $0.40 per piece when ordering 250


## BOM OPTIMIZATION
# This script is capable of optimizing the quantities automatically
# based on the information of the BOM-ex database file.

## Order multiples of the minimum order quantity (MOC) for
#  cheap parts (resistors, capacitors)
my $moc = 10;          # Order 10, 20, 30, etc.
my $moc_price = 0.021; # Order multiples at a cost of $0.021 or less








#print "\nEnter 1st File Name :--> \t";   ## Give 1st File Name.
#chomp(my $file1 = <STDIN>);
#print "\nEnter 2st File Name :--> \t";  ## Give 2nd File Name.
#chomp(my $file2 = <STDIN>);  
#print "\nEnter File Name For Creating Report:--> \t";
#chomp(my $s = <STDIN>);


chomp(my $file1 = $ARGV[0]);
chomp(my $file2 = $ARGV[1]);

my $mday;
my $mon;
my $day;
my $wday;
my $sec;
my $min;
my $hour;
my $year;
my $isdst;
my $yday;

($sec,$min,$hour,$mday,$mon,$year,$wday,
$yday,$isdst)=localtime(time);
my $s = sprintf( "bom-combined-%4d-%02d-%02d_%02dh%02dm.csv",
$year+1900,$mon+1,$mday,$hour,$min);

##y $s = "out.csv"; ##$ARGV[2];

print "\n-----------------------------------\n\n";
print "Merging files:\n\n";

my $output = "";
foreach (@ARGV) {
  $output = "$output\n + $_";
}

print "$output\n\nUsing DATABASE: $partsdb\n\n-----------------------------------\n\n";
print "Please enter desired board / BOM quantities:\n\n";

unless (@ARGV) {
  die "Could not read all files. Usage: perl scriptname.pl <file1> <file2> <filen>\n";
}
open MARGIN, ">", $s or die "Please close $s file and run again: $!";

print "\n";

foreach (@ARGV) {
  open IN, "<", $_ or die "File $_ not found: $!";
  
  ## Request multiple of this file from user
  print "Enter the number of boards for BOM: $_ \n [Number]:\t";
  chomp(my $q = <STDIN>);
  ## Store the requested number of boards
  $boards{$_} = $q;
  
  my $first = 1;
  while (<IN>) {
     ##print MARGIN;
     if ($first eq 1) {
     	$first = 0;
     }
     else {
     my @splitline = split($filesplitchar);
     my $ip = $splitline[0];
     if (!exists $count{$ip}) {
     	$count{$ip} = [@splitline];
     	$count{$ip}[4] = $q * $splitline[4];
     }
     else
     {
     	$count{$ip}[4] = $count{$ip}[4] + $q * $splitline[4];
     }
     }
  }
  close IN or die "Can't close input file: $!"; 
}

## Quantity optimization based on database file
## Load database
open (DB, $partsdb) or die "DATABASE file $_ not found: $!";
  my $first = 1;
while (<DB>) {
     if ($first eq 1) {
     	$first = 0;
     }
     else {
  my @splitline = split($dbsplitchar);
  my $key = $splitline[3];
  if (!exists $dbparts{$key}) {
    $dbparts{$key} = [@splitline];
  }
  ##print "KEY: $key: $dbparts{$key}[5] - $dbparts{$key}[9]\n";
  }
}
close DB or die "Can't close input file: $!";

print "\n\n-----------------------------------\n\n";
print "Auto-adjusting quantities to minimize costs:\n\n";

## Adjust quantities

foreach my $ip (keys %count) {
 ##$dumper->dumpValue(\\%dbparts);

  my $quantity = $count{$ip}[$quantity_col];
  
  ## Replace description
  $count{$ip}[3] = $dbparts{$ip}[4];
  
  ## Check if prices and quantities are numbers
  # /^(\d+\.?\d*|\.\d+)$/
  
  ## First check if it would be cheaper to get a lot of parts (250-500 typically)
  
  if (
  (exists $dbparts{$ip}[$p2col]) && (exists $dbparts{$ip}[$q3col]) && (exists $dbparts{$ip}[$p3col])
  && ($dbparts{$ip}[$p2col] =~ /^(\d+\.?\d*|\.\d+)$/) && ($dbparts{$ip}[$q3col] =~ /^(\d+\.?\d*|\.\d+)$/) && ($dbparts{$ip}[$p3col] =~ /^(\d+\.?\d*|\.\d+)$/)
  && (($quantity * $dbparts{$ip}[$p2col]) >= $dbparts{$ip}[$q3col] * $dbparts{$ip}[$p3col])) {

  	if ($count{$ip}[$quantity_col] < $count{$ip}[$quantity_col]) {
  	  $count{$ip}[$quantity_col] = $dbparts{$ip}[$q3col];
  	  print "$count{$ip}[$key_col]: Replacing quantity of $quantity with cheaper quantity $dbparts{$ip}[$q3col]\n";
  	} else {
  	  print"$count{$ip}[$key_col]: Price is already optimal, not adjusting quantity\n";
  	}
  	$prices{$ip} = $dbparts{$ip}[$p3col];
  }
  ## Then check if it would be cheaper getting some (50-100)
  else {
    if (
    (exists $dbparts{$ip}[$p1col]) && (exists $dbparts{$ip}[$q2col]) && (exists $dbparts{$ip}[$p2col])
    && ($dbparts{$ip}[$p1col] =~ /^(\d+\.?\d*|\.\d+)$/) && ($dbparts{$ip}[$q2col] =~ /^(\d+\.?\d*|\.\d+)$/) && ($dbparts{$ip}[$p2col] =~ /^(\d+\.?\d*|\.\d+)$/)
    && (($quantity * $dbparts{$ip}[$p1col]) >= $dbparts{$ip}[$q2col] * $dbparts{$ip}[$p2col])) {
  	  if ($count{$ip}[$quantity_col] < $dbparts{$ip}[$q2col]) {
  	    $count{$ip}[$quantity_col] = $dbparts{$ip}[$q2col];
  	    print "$count{$ip}[$key_col]: Replacing quantity of $quantity with cheaper quantity $count{$ip}[$quantity_col]\n";
  	  }
  	  $prices{$ip} = $dbparts{$ip}[$p2col];
    }
    ## Then check if we should at least get 10 instead of 1
    else {
      if (exists $dbparts{$ip}[$p1col]) {
      if ($dbparts{$ip}[$p1col] =~ /^(\d+\.?\d*|\.\d+)$/) {
      if (($quantity * $dbparts{$ip}[$p1col]) < $moc_price*$quantity) {
        ## Fill with multiples of moc
        # The operation below is equivalent to ceil(number)
        # it will miserably fail at quantities of around one million
        # or more. But any user ordering one million parts from Digi-Key
        # or Mouser and not directly from the manufacturer is a fail on its own, so this is safe.
        my $newquantity = (int($quantity / $moc + 0.999999999999))*$moc;
  	    $count{$ip}[$quantity_col] = $newquantity;
  	    $prices{$ip} = $dbparts{$ip}[$p1col];
  	    if ($quantity != $newquantity) {
  	      print "$count{$ip}[$key_col]: Replacing quantity of $quantity for \$ $dbparts{$ip}[$p1col]/piece with minimum order quantity of $newquantity\n";
        }
      }
      else {
        $prices{$ip} = $dbparts{$ip}[$p1col];
      }
      } else {
        print "\n\nWARNING: Price column 1 missing - there is no valid price for the part $ip\n\n";
      }
      } else {
        print "\n\nWARNING: Price column 1 does contain an invalid number - there is no valid price for the part $ip\n\n";
      }
    }
  }
}

##$dumper->dumpValue(\\%prices);

print "\n\nFinal order list:\n----------------------------\n\n";

## Compile final combined parts list
## store it to file and output on the console
print MARGIN "\n\n";
foreach my $ip (sort keys %count) { ## {$count{$a}[$key_col] <=> $count{$b}[$key_col]}
  $count{$ip}[$quantity_col+1] = $count{$ip}[$quantity_col] * 5;
  $count{$ip}[$quantity_col+2] = $count{$ip}[$quantity_col] * 10;
  my $line = join(",",@{$count{$ip}});
  print MARGIN "$line";
  print "$line";
}
close MARGIN;

print "\n\nCOST REPORT\n=============================================================\n\n";

my $total_costs = 0;

## Calculate the per-BOM/board price and output it
foreach (@inputfiles) {
  open PR, "<", $_ or die "File \"$_\" not found: $!";
  print "Costs for \"$_\"..\n";
  my $first = 1;
  my $sum = 0;
  my $board = $_;
  
  while (<PR>) {
     ##print MARGIN;
     if ($first eq 1) {
     	$first = 0;
     }
     else {
       # Calculate the price per board
       # using the current quantities
       my @splitline = split($filesplitchar);
       #$dumper->dumpValue(\\@splitline);
       if (exists $splitline[0] && exists $prices{$splitline[0]}) {
         if (exists $splitline[4]) {
           $sum += $splitline[4]*$prices{$splitline[0]};
         }
       } else {
         print "WARNING: No price found for $splitline[0]\n"
       }
     }
  }
    ## Output costs of this board
  print "TOTAL:\t\$ $sum per board\n\n-------------------------------------------------------------\n";
  $total_costs += $sum*$boards{$board};
  
  close PR or die "Can't close input file: $!";
}

print "\n=============================================================\n";
print "Total sum for this order: \$ $total_costs\n=============================================================\n\n";

print "\nOUTPUT file has been created: $dir/$s\n\nPlease use the output file as input to the Digi-Key website.\n"; 