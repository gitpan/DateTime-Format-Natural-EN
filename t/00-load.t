#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
	use_ok('DateTime::Format::Natural::EN');
}

diag("Testing DateTime::Format::Natural::EN $DateTime::Format::Natural::EN::VERSION, Perl $], $^X");
