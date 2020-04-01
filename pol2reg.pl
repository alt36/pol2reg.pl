#!/usr/bin/perl

use strict;
use warnings;
use Encode qw(decode encode);
use Data::Dumper;
use Getopt::Long;

local $/;

my $context;

GetOptions ("context|c=s" => \$context);

sub usage {
  print "Usage: $0 --context HKLM|HKCU\n";
  exit 1;
}

if (!$context) {
  usage();
}

if($context eq 'HKLM') {
  $context = 'HKEY_LOCAL_MACHINE';
}elsif($context eq 'HKCU') {
  $context = 'HKEY_CURRENT_USER';
} else {
  usage();
}


my ($sig, $ver, $body)  = unpack('H8 H8 H*', <>);
$sig == "50526567" or die "bad sig (got $sig)";
$ver == "01000000" or die "bad version (got $ver)";

my $reading=0;

my @stream = unpack("a2" x (length($body)/2), $body);
my @instructions = ();
my $count=0;
my $element=0;
my $done=0;
my $pos=0;

while($pos<scalar(@stream))  {
  my $byte=$stream[$pos];
  my $nextbyte=$stream[$pos+1];

  if($byte.$nextbyte eq "5b00") { # [
    if($reading) {
      $instructions[$count][$element] .= $byte.$nextbyte;
    } else {
      $reading=1;
    }
  } elsif($byte.$nextbyte eq "5d00") { # ]
    $count++;
    $element=0;
    $reading=0;
  } elsif($byte.$nextbyte eq "3b00") { # ;
    $element++;
  } else {
    $instructions[$count][$element] .= $byte.$nextbyte;
  }
  if($element == 4) {
    my $size=hex2int32le($instructions[$count][3]);
    # suppose ; is bytes 326,327 and size is 4.
    # then data is 328, 329, 330, 331
    # and pos should be 332 afterwards
    if($size > 0) {
      $instructions[$count][$element] = join('', @stream[$pos+2 .. $pos+$size+1]);
      $pos+=$size+2;
    }
  } else {
    $pos+=2;
  }
}


my $currentKey="";

print "Windows Registry Editor Version 5.00\n";

foreach my $inst (@instructions) {
  my $key = hex2utf16le(stripTerminalNull($inst->[0]));
  my $value = hex2utf16le(stripTerminalNull($inst->[1]));
  my $type = hex2int32le($inst->[2]);
  my $size = hex2int32le($inst->[3]);
  my $data = $inst->[4];

  if($key ne $currentKey) {
    $currentKey=$key;
    print "\n";
    print "[$context\\$key]\n";
  }

  
  if($type == 0) {
    next;
  }
  
  print "\"$value\"=";

  if($type == 1) { # REG_SZ
    $data = hex2utf16le($data);
    print "\"$data\"\n";
  }

  if($type == 2) { # REG_EXPAND_SZ
    $data = hex2utf16le($data);
  }

  if($type == 3) { # REG_BINARY
   print $data."\n"; 
  }

  if($type == 4) { # REG_DWORD
    print "dword:$data\n";
    $data = hex2int32le($data);
  }

  if($type == 5) { # REG_DWORD_BIG_ENDIAN
    $data = hex2int32be($data);
  }

  if($type == 7) { # REG_MULTI_SZ
  }
 
  if($type == 11) { # REG_QWORD
    $data = hex2int64le($data);
  }
}

# strip a terminal UTF-16 null (0000)
sub stripTerminalNull {
  my $a=shift;
  $a =~ s/(.*)0000/$1/ ;
  return $a;
}

# convert hex string to utf-16le
# eg given 480065006c006c006f00, return hello
sub hex2utf16le {
  return decode("UTF-16LE", pack('H*', shift));
}

sub hex2int32le {
  return unpack('L<', pack('H*', shift));
}

sub hex2int32be {
  return unpack('L>', pack('H*', shift));
}

sub hex2int64le {
  return unpack('Q>', pack('H*', shift));
}
