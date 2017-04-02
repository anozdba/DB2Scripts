#!/usr/bin/perl
# --------------------------------------------------------------------
# ltreeaccess.pl
#
# $Id: ltreeaccess.pl,v 1.1 2008/09/25 22:36:42 db2admin Exp db2admin $
#
# Description:
# Script to list the contents of a directory and all subordinate directories (mainly to look for access discrepancies)
#
# Usage:
#   ltreeaccess.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ltreeaccess.pl,v $
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------

$Now = `date`;
chomp $Now;

if (defined($ARGV[0])) {
  $dir = $ARGV[0];
}
else {
  $dir = `pwd`;
  chomp $dir;
}

@levels = split(/\//,$dir);

print "\nDirectory Tree being listed : $dir (ls -ld for each level)\n\n";
$currDir = "";

for ($i = 1; $i <= $#levels  ; $i++ ) {
  $currDir = $currDir . "/" . $levels[$i];
  $ls = `ls -ld $currDir`;
  chomp $ls;
  print "$ls\n";
}

print "\nContents of $dir (ls -al) :\n\n";

if (! open (LSPIPE,"ls -al $dir |"))  {
        die "Can't run du! $!\n";
    }

while (<LSPIPE>) {
  print "$_";
}

sub trim() {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

sub ltrim() {
  my $string = shift;
  $string =~ s/^\s+//;
  return $string;
}

sub rtrim() {
  my $string = shift;
  $string =~ s/\s+$//;
  return $string;
}

