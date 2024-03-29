#!/usr/bin/perl

use strict;
use warnings;

use DateTime::Format::Natural::EN;

my $parse = DateTime::Format::Natural::EN->new();

while (1) {
    print 'Input date string: ';
    chomp(my $input = <STDIN>);
    my $dt = $parse->parse_datetime(string => $input, debug => 0);
    printf("%02s.%02s.%4s %02s:%02s\n", $dt->day, $dt->month, $dt->year, $dt->hour, $dt->min);
}
