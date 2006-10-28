package DateTime::Format::Natural::EN;

use strict;
use warnings;

use DateTime;

our $VERSION = '0.07';

sub new {
    my $class = shift;
    return bless {}, $class || ref($class);
}

sub parse_datetime {
    my $self = shift;

    my ($DEBUG, $date_string, %opts);

    if (@_ > 1) {
        %opts        = @_;
    $date_string = $opts{string};
        $DEBUG       = $opts{debug};
    } else {
        ($date_string) = @_;
    }

    no strict 'refs';

    my @tokens = split ' ', $date_string;
    my $buffer = '';

    my ($sec, $min, $hour, $day, $month, $year, $wday, $yday) = localtime;
    $month++; $year += 1900;

    for (my $i = 0; $i < @tokens; $i++) {
        print "$tokens[$i]\n" if $DEBUG;

        my %weekdays = (Monday    => 1,
                        Tuesday   => 2,
                        Wednesday => 3,
                        Thursday  => 4,
                        Friday    => 5,
                        Saturday  => 6,
                        Sunday    => 0);

        my %months = (January   => 1,
                      February  => 2,
                      March     => 3,
                      April     => 4,
                      May       => 5,
                      June      => 6,
                      July      => 7,
                      August    => 8,
                      September => 9,
                      October   => 10,
                      November  => 11,
                      December  => 12);

        my %monthdays = (1  => 31,
                         2  => 28,
                         3  => 31,
                         4  => 30,
                         5  => 31,
                         6  => 30,
                         7  => 31,
                         8  => 31,
                         9  => 30,
                         10 => 31,
                         11 => 30,
                         12 => 31);

        no warnings 'uninitialized';

        if ($tokens[$i+2] =~ /^ago$/i) {
            my @new_tokens = splice(@tokens, $i, 3);
            if ($new_tokens[1] =~ /^hour(?:s)?$/i) {
                $hour -= $new_tokens[0];
            }
            if ($new_tokens[1] =~ /^day(?:s)?$/i) {
                $day -= $new_tokens[0];
            }
            if ($new_tokens[1] =~ /^week(?:s)?$/i) {
                $day -= 7 * $new_tokens[0];
            }
            if ($new_tokens[1] =~ /^month(?:s)?$/i) {
                $month -= $new_tokens[0];
            }
            if ($new_tokens[1] =~ /^year(?:s)?$/i) {
                $year -= $new_tokens[0];
            }
        }

        if ($tokens[$i+3] =~ /^now$/i) {
            my @new_tokens = splice(@tokens, $i, 4);
            if ($new_tokens[1] =~ /^day(?:s)?$/i) {
                if ($new_tokens[2] =~ /^before$/i) {
                    $day -= $new_tokens[0];
                } elsif ($new_tokens[2] =~ /^from$/i) {
                    $day += $new_tokens[0];
                }
            }
            if ($new_tokens[1] =~ /^week(?:s)?$/i) {
                if ($new_tokens[2] =~ /^before$/i) {
                    $day -= 7 * $new_tokens[0];
                } elsif ($new_tokens[2] =~ /^from$/i) {
                    $day += 7 * $new_tokens[0];
                }
            }
            if ($new_tokens[1] =~ /^month(?:s)?$/i) {
                if ($new_tokens[2] =~ /^before$/i) {
                    $month -= $new_tokens[0];
                } elsif ($new_tokens[2] =~ /^from$/i) {
                    $month += $new_tokens[0];
                }
            }
            if ($new_tokens[1] =~ /^year(?:s)?$/i) {
                if ($new_tokens[2] =~ /^before$/i) {
                    $year -= $new_tokens[0];
                } elsif ($new_tokens[2] =~ /^from$/i) {
                    $year += $new_tokens[0];
                }
            }
        }

        if ($tokens[$i] =~ /^(?:morning|afternoon|evening)$/i) {
            my $hour_token;
            if ($tokens[$i-3] =~ /\d/ and $tokens[$i-2] =~ /^in$/i and $tokens[$i-1] =~ /^the$/i) {
                $hour_token = $tokens[$i-3];
            }
            if ($tokens[$i] =~ /^morning$/i) {
                $hour = $hour_token ? $hour_token : '08';
            } elsif ($tokens[$i] =~ /^afternoon$/i) {
                $hour = $hour_token ? $hour_token + 12 : '14';
            } else {
                $hour = $hour_token ? $hour_token + 12 : '20';
            }
            $min = '00';
        }

        if ($tokens[$i] =~ /^at$/i) {
            next;
        } elsif ($tokens[$i] =~ /^(\d{1,2})(:\d{2})?\s?(am|pm)?$/i) {
            my $hour_token = $1; my $min_token = $2;
            my $timeframe = $3;
            $hour = $hour_token; 
            $min_token =~ s!:!!;
            $min  = $min_token || '00';
            if ($timeframe) {
                if ($timeframe =~ /^pm$/i) {
                    $hour_token += 12;
                    $hour = $hour_token;
                    $min  = '00' unless $min_token;
                }
            }
        }

        if ($tokens[$i] =~ /^(\d{1,2})(?:st|nd|rd|th)$/i) {
            $day = $1;
        }

        foreach my $key_month (keys %months) {
            if ($tokens[$i] =~ /$key_month/i) {
                $month = $months{$key_month};
                last;
            }
        }

        if ($tokens[$i] =~ /^\d{4}$/) {
            $year = $tokens[$i];
        }

        if ($tokens[$i-1] !~ /^(?:this|next|last)$/i && $tokens[$i+1] !~ /^(?:this|next|last)$/i) {
            foreach my $key_weekday (keys %weekdays) {
                my $weekday_short = lc(substr($key_weekday,0,3));
                if ($tokens[$i] =~ /$key_weekday/i || $tokens[$i] eq $weekday_short) {
                    my $days_diff = $weekdays{$key_weekday} - $wday;
                    $day += $days_diff;
                    last;
                }
            }
        }

        if ($tokens[$i] =~ /^this$/i) {
            $buffer = 'this';
            next;
        } elsif ($buffer eq 'this') {
            foreach my $key_weekday (keys %weekdays) {
                my $weekday_short = lc(substr($key_weekday,0,3));
                if ($tokens[$i] =~ /$key_weekday/i || $tokens[$i] eq $weekday_short) {
                    my $days_diff = $weekdays{$key_weekday} - $wday;
                    $day += $days_diff; $buffer = '';
                    last;
                }
                if ($tokens[$i] =~ /^week$/i) {
                    my $weekday = ucfirst(lc($tokens[$i-2]));
                    my $days_diff = $weekdays{$weekday} - $wday;
                    $day += $days_diff; $buffer = '';
                    last;
                }
            }
        }

        if ($tokens[$i] =~ /^next$/i) {
            $buffer = 'next';
            next;
        } elsif ($buffer eq 'next') {
            foreach my $key_weekday (keys %weekdays) {
                my $weekday_short = lc(substr($key_weekday,0,3));
                if ($tokens[$i] =~ /$key_weekday/i || $tokens[$i] eq $weekday_short) {
                    my $days_diff = (7 - $wday) + $weekdays{$key_weekday};
                    $day += $days_diff; $buffer = '';   
                    last;
                }
                if ($tokens[$i] =~ /^week$/i) {
                    my $weekday = ucfirst(lc($tokens[$i-2]));
                    my $days_diff = (7 - $wday) + $weekdays{$weekday};
                    $day += $days_diff; $buffer = '';
                    last;
                }
                if ($tokens[$i] =~ /^month$/i) {
                    $month++;
                    last;
                }
                if ($tokens[$i] =~ /^year$/i) {
                    $year++;
                    last;
                }
            }
        }

        if ($tokens[$i] =~ /^last$/i) {
            $buffer = 'last';
            next;
        } elsif ($buffer eq 'last') {
            foreach my $key_weekday (keys %weekdays) {
                my $weekday_short = lc(substr($key_weekday,0,3));
                if ($tokens[$i] =~ /$key_weekday/i || $tokens[$i] eq $weekday_short) {
                    my $days_diff = $wday + (7 - $weekdays{$key_weekday});
                    $day -= $days_diff; $buffer = '';
                    last;
                }
            }
            if ($tokens[$i] =~ /^week$/i) {
                if (exists $weekdays{ucfirst(lc($tokens[$i+1]))}) {
                    my $weekday = ucfirst(lc($tokens[$i+1]));
                    my $days_diff = $wday + (7 - $weekdays{$weekday});
                    $day -= $days_diff; $buffer = '';
                } elsif (exists $weekdays{ucfirst(lc($tokens[$i-2]))}) {
                    my $weekday = ucfirst(lc($tokens[$i-2]));
                    my $days_diff = $wday + (7 - $weekdays{$weekday});
                    $day -= $days_diff; $buffer = '';
                }
            }
            if ($tokens[$i] =~ /^month$/i) {
                $month--;
            }
            if ($tokens[$i] =~ /^year$/i) {
                $year--;
            }
        }

        if ($day > $monthdays{$month}) {
            my $days_next_month = $day - $monthdays{$month};
            $month++; $day = $days_next_month;
        } elsif ($day < 1) {
            # XXX this branch needs some provement 
            my $days_last_month = $monthdays{$month-1} - $day;
            $month--; $day = $days_last_month;
        }

        if ($tokens[$i] =~ /^(?:today|yesterday|tomorrow)$/i) {
            $day-- if $tokens[$i] =~ /^yesterday$/i;
            $day++ if $tokens[$i] =~ /^tomorrow$/i;
        }
    }

    $sec   = "0$sec"   unless length($sec)   == 2;
    $min   = "0$min"   unless length($min)   == 2;
    $hour  = "0$hour"  unless length($hour)  == 2;
    $day   = "0$day"   unless length($day)   == 2;
    $month = "0$month" unless length($month) == 2;

    my $dt = DateTime->new(year   => $year,
                           month  => $month,
                           day    => $day,
                           hour   => $hour,
                           minute => $min,
                           second => $sec);
    return $dt;
}

1;
__END__

=head1 NAME

DateTime::Format::Natural::EN - Create machine readable date/time with natural parsing logic

=head1 SYNOPSIS

 use DateTime::Format::Natural::EN;
 
 $parse = DateTime::Format::Natural::EN->new();
 
 $dt = $parse->parse_datetime($date_string);

=head1 DESCRIPTION

C<DateTime::Format::Natural::EN> consists of a method, C<parse_datetime()>, which takes a 
string with a human readable date/time and creates a machine readable one by applying 
natural parsing logic.

=head1 FUNCTIONS

=head2 parse_datetime

Creates a C<DateTime> object from a human readable date/time string.

 $dt = $parse->parse_datetime($date_string);

 $dt = $parse->parse_datetime(string => $date_string, debug => 1);

The options may contain the keys 'string' and 'debug'.
Former one may consist of the datestring, whereas latter one holds the boolean value for the
debugging option. If debugging is enabled, each token that is analysed will be output to 
stdout with a trailing newline.

Returns a C<DateTime> object.

=head2 format_datetime

Not implemented yet.

=head1 EXAMPLES

Below are some examples of human readable date/time input:

=head2 Simple

 thursday
 november
 friday 13:00
 mon 2:35
 4pm
 6 in the morning
 friday 1pm
 sat 7 in the evening
 yesterday
 today
 tomorrow
 this tuesday
 next month
 this morning
 this second
 yesterday at 4:00
 last friday at 20:00
 last week tuesday
 tomorrow at 6:45pm
 afternoon yesterday
 thursday last week

=head2 Complex

 3 years ago
 5 months before now
 7 hours ago
 7 days from now
 in 3 hours
 1 year ago tomorrow
 3 months ago saturday at 5:00pm

=head1 SEE ALSO

L<DateTime>, L<http://datetime.perl.org/>  

=head1 AUTHOR

Steven Schubiger <schubiger@cpan.org>

=head1 LICENSE

This program is free software; you may redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>	    

=cut
