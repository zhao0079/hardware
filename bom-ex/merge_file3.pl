#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
my $dir = cwd;
my %count;

my $key = 0;       ## Index where the key (part number) is stored
my $quantity = 4;  ## Index where the quantity is stored

#print "\nEnter 1st File Name :--> \t";   ## Give 1st File Name.
#chomp(my $file1 = <STDIN>);
#print "\nEnter 2st File Name :--> \t";  ## Give 2nd File Name.
#chomp(my $file2 = <STDIN>);  
#print "\nEnter File Name For Creating Report:--> \t";
#chomp(my $s = <STDIN>);


chomp(my $file1 = $ARGV[0]);
chomp(my $file2 = $ARGV[1]);
my $s = $ARGV[2];

unless ($file1 && $file2 && $s) {
  die "Usage: perl scriptname.pl <file1> <file2> <outputfile>\n";
}
open MARGIN, ">", $s or die "Please Close $s File And Run Again: $!";
for ($file1,$file2) {
  open IN, "<", $_ or die "File $_ not found: $!";
  while (<IN>) {
     print MARGIN;
     my @splitline = split(/,/);
     my $ip = $splitline[0];
     if ($count{$ip} eq undef) {
     	$count{$ip} = [@splitline];
     }
     $count{$ip}[4] = $count{$ip}[4] + $splitline[4];
  }
  close IN or die "Can't close input file: $!"; 
}
print MARGIN "\n\n";
foreach my $ip (sort {$count{$a} <=> $count{$b}} keys %count) {
  my $line = join(",",@{$count{$ip}});
  print MARGIN "$line";
  print "$line";
}
close MARGIN;
print "\nFile has Created in $dir/$s\n"; 