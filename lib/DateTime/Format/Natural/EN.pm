package DateTime::Format::Natural::EN;

use strict;
use warnings;
no strict 'refs';
no warnings 'uninitialized';

use Date::Calc qw(Days_in_Month Decode_Day_of_Week Nth_Weekday_of_Month_Year);
use DateTime;

our $VERSION = '0.09';

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

    my ($sec, $min, $hour, $day, $month, $year, $wday, $yday) = localtime;
    $month++; $year += 1900;

    $self->{sec}   = $sec;
    $self->{min}   = $min;
    $self->{hour}  = $hour;
    $self->{day}   = $day;
    $self->{month} = $month;
    $self->{year}  = $year;
    $self->{wday}  = $wday;
    $self->{yday}  = $yday;

    $date_string =~ tr/,//d;

    if ($date_string =~ m!/!) {
        my @bits = split '\/', $date_string;

        if (scalar @bits == 3) {
            $self->{day}   = $bits[0];
            $self->{month} = $bits[1];
            $self->{year}  = $bits[2];

            return $self->_return_dt_object;
        }
    } else {
        @{$self->{tokens}} = split ' ', $date_string;
    }

    for ($self->{index} = 0; $self->{index} < @{$self->{tokens}}; $self->{index}++) {

        print "$self->{tokens}->[$self->{index}]\n" if $DEBUG;

        $self->_init_data;

        if ($self->{tokens}->[$self->{index}+2] =~ /^ago$/i) {
            $self->_ago;
        }

        if ($self->{tokens}->[$self->{index}+3] =~ /^now$/i) {
            $self->_now;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^(?:morning|afternoon|evening)$/i) {
            $self->_daytime;
        }

        if ($self->{tokens}->[$self->{index}+1] =~ /^(\d{4})$/) {
            $self->{year}  = $1;
        }

        $self->_months();

        if ($self->{tokens}->[$self->{index}] =~ /^at$/i) {
            next;
        } elsif ($self->{tokens}->[$self->{index}] =~ /^(\d{1,2})(:\d{2})?(am|pm)?|(noon|midnight)$/i) {
            my $hour_token    = $1;
            my $min_token     = $2;
            my $timeframe     = $3;
            my $noon_midnight = $4;

            $self->_at($hour_token, $min_token, $timeframe, $noon_midnight);
        }

        if ($self->{tokens}->[$self->{index}] =~ /^(\d{1,2})(?:st|nd|rd|th)? ?$/i) {
            $self->_number($1);
        }

        if ($self->{tokens}->[$self->{index}] =~ /^\d{4}$/) {
            $self->{year} = $self->{tokens}->[$self->{index}];
        }

        if ($self->{tokens}->[$self->{index}] !~ /^(?:this|next|last)$/i
            && $self->{tokens}->[$self->{index}-1] !~ /^(?:this|next|last)$/i
            && $self->{tokens}->[$self->{index}-2] !~ /^(?:this|next|last)$/i
            && $self->{tokens}->[$self->{index}+1] !~ /^(?:this|next|last)$/i) {
            $self->_weekday;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^(?:this|in)$/i) {
            $self->{buffer} = 'this_in';
            next;
        } elsif ($self->{buffer} eq 'this_in') {
            $self->_this_in;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^next$/i) {
            $self->{buffer} = 'next';
            next;
        } elsif ($self->{buffer} eq 'next') {
            $self->_next;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^last$/i) {
            $self->{buffer} = 'last';
            next;
        } elsif ($self->{buffer} eq 'last') {
            $self->_last;
        }

         $self->_monthdays_limit;
         $self->_day;

         return $self->_return_dt_object;
    }
}

sub _init_data {
    my $self = shift;

    my $i = 1;

    %{$self->{weekdays}} = map {  $_ => $i++ } qw(Monday Tuesday Wednesday Thursday
                                                  Friday Saturday Sunday);
    $i = 1;

    %{$self->{months}} = map { $_ => $i++ } qw(January February March April
                                               May June July August September
                                               October November December);
}

sub _return_dt_object {
    my $self = shift;

    $self->{sec}   = "0$self->{sec}"   unless length($self->{sec})   == 2;
    $self->{min}   = "0$self->{min}"   unless length($self->{min})   == 2;
    $self->{hour}  = "0$self->{hour}"  unless length($self->{hour})  == 2;
    $self->{day}   = "0$self->{day}"   unless length($self->{day})   == 2;
    $self->{month} = "0$self->{month}" unless length($self->{month}) == 2;

    my $dt = DateTime->new(year   => $self->{year},
                           month  => $self->{month},
                           day    => $self->{day},
                           hour   => $self->{hour},
                           minute => $self->{min},
                           second => $self->{sec});
    return $dt;
}

sub _ago {
    my $self = shift;

    my @new_tokens = splice(@{$self->{tokens}}, $self->{index}, 3);

    if ($new_tokens[1] =~ /^hour(?:s)?$/i) {
        $self->{hour} -= $new_tokens[0];
    }
    if ($new_tokens[1] =~ /^day(?:s)?$/i) {
        $self->{day} -= $new_tokens[0];
    }
    if ($new_tokens[1] =~ /^week(?:s)?$/i) {
        $self->{day} -= 7 * $new_tokens[0];
    }
    if ($new_tokens[1] =~ /^month(?:s)?$/i) {
        $self->{month} -= $new_tokens[0];
    }
    if ($new_tokens[1] =~ /^year(?:s)?$/i) {
        $self->{year} -= $new_tokens[0];
    }
}

sub _now {
    my $self = shift;

    my @new_tokens = splice(@{$self->{tokens}}, $self->{index}, 4);

    if ($new_tokens[1] =~ /^day(?:s)?$/i) {
        if ($new_tokens[2] =~ /^before$/i) {
            $self->{day} -= $new_tokens[0];
        } elsif ($new_tokens[2] =~ /^from$/i) {
            $self->{day} += $new_tokens[0];
        }
    }
    if ($new_tokens[1] =~ /^week(?:s)?$/i) {
        if ($new_tokens[2] =~ /^before$/i) {
            $self->{day} -= 7 * $new_tokens[0];
        } elsif ($new_tokens[2] =~ /^from$/i) {
            $self->{day} += 7 * $new_tokens[0];
        }
     }
     if ($new_tokens[1] =~ /^month(?:s)?$/i) {
         if ($new_tokens[2] =~ /^before$/i) {
             $self->{month} -= $new_tokens[0];
         } elsif ($new_tokens[2] =~ /^from$/i) {
             $self->{month} += $new_tokens[0];
         }
     }
     if ($new_tokens[1] =~ /^year(?:s)?$/i) {
         if ($new_tokens[2] =~ /^before$/i) {
             $self->{year} -= $new_tokens[0];
         } elsif ($new_tokens[2] =~ /^from$/i) {
             $self->{year} += $new_tokens[0];
         }
     }
}

sub _daytime {
    my $self = shift;

    my $hour_token;

    if ($self->{tokens}->[$self->{index}-3] =~ /\d/ and $self->{tokens}->[$self->{index}-2] =~ /^in$/i 
        and $self->{tokens}->[$self->{index}-1] =~ /^the$/i) {
        $hour_token = $self->{tokens}->[$self->{index}-3];
    }
    if ($self->{tokens}->[$self->{index}] =~ /^morning$/i) {
        $self->{hour} = $hour_token ? $hour_token : '08' - $self->{hours_before};
        undef $self->{hours_before};
    } elsif ($self->{tokens}->[$self->{index}] =~ /^afternoon$/i) {
        $self->{hour} = $hour_token ? $hour_token + 12 : '14' - $self->{hours_before};
        undef $self->{hours_before};
    } else {
        $self->{hour} = $hour_token ? $hour_token + 12 : '20' - $self->{hours_before};
        undef $self->{hours_before};
    }

    $self->{min} = '00';
}

sub _months {
    my $self = shift;

    foreach my $key_month (keys %{$self->{months}}) {
        my $key_month_short = substr($key_month, 0, 3);
        if ($self->{tokens}->[$self->{index}] =~ /$key_month/i
            || $self->{tokens}->[$self->{index}] =~ /$key_month_short/i) {
            $self->{month} = $self->{months}->{$key_month};
            if ($self->{tokens}->[$self->{index}+1] =~ /^(\d{1,2})(?:st|nd|rd|th)? ?$/i) {
                $self->{day} = $1;
            } elsif ($self->{tokens}->[$self->{index}-1] =~ /^(\d{1,2})(?:st|nd|rd|th)? ?$/i) {
                  $self->{day} = $1;
            }
            splice(@{$self->{tokens}}, $self->{index}, 2);
        }
    }
}

sub _number {
    my ($self, $often) = @_;

    return if $self->{tokens}->[$self->{index}+1] eq 'in';

    if ($self->{tokens}->[$self->{index}+1] =~ /month(?:)/i) {
        $self->{month} += $often;
        $self->{month} -= 12 if $self->{month} > 12;
    } elsif ($self->{tokens}->[$self->{index}+1] =~ /hour(?:s)/i) {
        if ($self->{tokens}->[$self->{index}+2] =~ /before/i) {
            $self->{hours_before} = $often;
        } elsif ($self->{tokens}->[$self->{index}+2] =~ /after/i) {
            $self->{hours_after} = $often;
        }
    } else {
        $self->{day} = $often;
    }
}

sub _at {
    my ($self, $hour_token, $min_token, $timeframe, $noon_midnight)  = @_;

    if (!$timeframe && $self->{tokens}->[$self->{index}+1] 
        && $self->{tokens}[$self->{index}+1] =~ /^[ap]m$/i) {
        $timeframe = $self->{tokens}[$self->{index}+1];
        $self->{index}++;
    }

    if ($hour_token) {
        $self->{hour} = $hour_token;
        $min_token =~ s!:!! if defined($min_token);
        $self->{min}  = $min_token || '00';

        if ($timeframe) {
            if ($timeframe =~ /^pm$/i) {
                $hour_token += 12;
                $self->{hour} = $hour_token;
                $self->{min}  = 0 unless $min_token;
            }
        }
    } elsif ($noon_midnight) {
        if ($noon_midnight =~ /noon/i) {
            ($self->{hour}, $self->{min}) = (12,0);
            $self->{hour} -= $self->{hours_before};
            undef $self->{hours_before};
        } elsif ($noon_midnight =~ /midnight/i) {
            ($self->{hour}, $self->{min}) = (0,0);
            $self->{hour} -= $self->{hours_before};
            $self->{day}++;
        }
    }
}

sub _weekday {
    my $self = shift;

    foreach my $key_weekday (keys %{$self->{weekdays}}) {
        my $weekday_short = lc(substr($key_weekday,0,3));

        if ($self->{tokens}->[$self->{index}] =~ /$key_weekday/i || $self->{tokens}->[$self->{index}] eq $weekday_short) {
            $key_weekday = ucfirst(lc($key_weekday));
            my $days_diff = $self->{weekdays}->{$key_weekday} > $self->{wday}
              ? $self->{weekdays}->{$key_weekday} - $self->{wday}
              : $self->{wday} - $self->{weekdays}->{$key_weekday};
            $self->{day} += $days_diff;
            last;
        }
    }
}

sub _this_in {
    my $self = shift;

    foreach my $key_weekday (keys %{$self->{weekdays}}) {
        my $weekday_short = lc(substr($key_weekday,0,3));

        if ($self->{tokens}->[$self->{index}] =~ /$key_weekday/i || $self->{tokens}->[$self->{index}] eq $weekday_short) {
            my $days_diff = $self->{weekdays}->{$key_weekday} - $self->{wday};
            $self->{day} += $days_diff; $self->{buffer} = '';
            last;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^week$/i) {
            my $weekday = ucfirst(lc($self->{tokens}->[$self->{index}-2]));
            my $days_diff = Decode_Day_of_Week($weekday) - $self->{wday};
            $self->{day} += $days_diff; $self->{buffer} = '';
            last;
        }

        foreach my $month (keys %{$self->{months}}) {
            if ($self->{tokens}->[$self->{index}] =~ /$month/i) {

                foreach my $weekday (keys %{$self->{weekdays}}) {
                    if ($self->{tokens}->[$self->{index}-2] =~ /$weekday/i) {

                        my ($often) = $self->{tokens}->[$self->{index}-3] =~ /^(\d{1,2})(?:st|nd|rd|th)?$/i;
                        ($self->{year}, $self->{month}, $self->{day}) =
                        Nth_Weekday_of_Month_Year($self->{year}, $self->{months}->{$month}, $self->{weekdays}->{$weekday}, $often);
                    }
                }
            }
        }
    }
}

sub _next {
    my $self = shift;

    foreach my $key_weekday (keys %{$self->{weekdays}}) {
        my $weekday_short = lc(substr($key_weekday,0,3));

        if ($self->{tokens}->[$self->{index}] =~ /$key_weekday/i || $self->{tokens}->[$self->{index}] eq $weekday_short) {
            my $days_diff = (7 - $self->{wday}) + Decode_Day_of_Week($key_weekday);
            $self->{day} += $days_diff; $self->{buffer} = '';
            last;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^week$/i) {
            my $weekday = ucfirst(lc($self->{tokens}->[$self->{index}-2]));
            my $days_diff = (7 - $self->{wday}) + Decode_Day_of_Week($weekday);
            $self->{day} += $days_diff; $self->{buffer} = '';
            last;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^month$/i) {
            $self->{month}++;
            last;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^year$/i) {
            $self->{year}++;
            last;
        }
    }
}

sub _last {
    my $self = shift;

    foreach my $key_weekday (keys %{$self->{weekdays}}) {
        my $weekday_short = lc(substr($key_weekday,0,3));

        if ($self->{tokens}->[$self->{index}] =~ /$key_weekday/i || $self->{tokens}->[$self->{index}] eq $weekday_short) {
            my $days_diff = $self->{wday} + (7 - $self->{weekdays}->{$key_weekday});
            $self->{day} -= $days_diff; $self->{buffer} = '';
            last;
        }
    }

    if ($self->{tokens}->[$self->{index}] =~ /^week$/i) {

        if (exists $self->{weekdays}->{ucfirst(lc($self->{tokens}->[$self->{index}+1]))}) {
            my $weekday = ucfirst(lc($self->{tokens}->[$self->{index}+1]));
            my $days_diff = $self->{wday} + (7 - $self->{weekdays}->{$weekday});
            $self->{day} -= $days_diff; $self->{buffer} = '';
        } elsif (exists $self->{weekdays}->{ucfirst(lc($self->{tokens}->[$self->{index}-2]))}) {
            my $weekday = ucfirst(lc($self->{tokens}->[$self->{index}-2]));
            my $days_diff = $self->{wday} + (7 - $self->{weekdays}->{$weekday});
            $self->{day} -= $days_diff; $self->{buffer} = '';
        }
    }

    if ($self->{tokens}->[$self->{index}] =~ /^month$/i) {
        $self->{month}--;
    }

    if ($self->{tokens}->[$self->{index}] =~ /^year$/i) {
        $self->{year}--;
    }
}

sub _monthdays_limit {
    my $self = shift;

    my $monthdays = Days_in_Month($self->{year}, $self->{month});

    if ($self->{day} > $monthdays) {
        $self->{month}++; $self->{day} = $self->{day} - $monthdays;
    } elsif ($self->{day} < 1) {
        $monthdays = Days_in_Month($self->{year}, ($self->{month}-1));
        $self->{month}--; $self->{day} = $monthdays - $self->{day};
    }
}

sub _day {
    my $self = shift;

    if ($self->{tokens}->[$self->{index}] =~ /^(?:today|yesterday|tomorrow)$/i) {
        $self->{day}-- if $self->{tokens}->[$self->{index}] =~ /yesterday/i;
        $self->{day}++ if $self->{tokens}->[$self->{index}] =~ /tomorrow/i;

        if ($self->{hours_before}) {
            $self->{hour} = 24 - $self->{hours_before};
            $self->{day}--;
        } elsif ($self->{hours_after}) {
            $self->{hour} = 0 + $self->{hours_after};
        }
    }

    if ($self->{hour} < 0) {
        my ($subtract) = $self->{hour} =~ /\-(.*)/;
        $self->{hour} = 12 - $subtract;
    }
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

=head2 new

Creates a new DateTime::Format::Natural::EN object.

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
 4th day last week
 3rd wednesday in november
 3rd month next year
 7 hours before tomorrow at noon

=head2 Specific Dates

 January 5
 dec 25
 may 27th
 October 2006
 february 14, 2004
 Friday
 jan 3 2010
 3 jan 2000
 27/5/1979
 4:00
 17:00

=head1 SEE ALSO

L<DateTime>, L<Date::Calc>, L<http://datetime.perl.org/>

=head1 AUTHOR

Steven Schubiger <schubiger@cpan.org>

=head1 LICENSE

This program is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
