#!/usr/bin/perl

use strict;
use warnings;

use DateTime::Format::Natural::EN qw(parse_datetime);

while (1) {
    print 'Input date string: ';
    chomp(my $input = <STDIN>);
    my $dt = parse_datetime($input);
    printf("%02s.%02s.%4s %02s:%02s\n", $dt->day, $dt->month, $dt->year, $dt->hour, $dt->min);
}
