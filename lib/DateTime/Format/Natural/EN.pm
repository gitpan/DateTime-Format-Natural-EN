package DateTime::Format::Natural::EN;

use strict;
no strict 'refs';
use warnings;
no warnings 'uninitialized';

use base qw(DateTime::Format::Natural::EN::Base);

our $VERSION = '0.12';

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

    unless ($self->{nodatetimeset}) {
        $self->{datetime} = DateTime->now(time_zone => 'local');
    }

    $date_string =~ tr/,//d;

    $self->{date_string} = $date_string;

    if ($date_string =~ m!/!) {
        my @bits = split '\/', $date_string;

        if (scalar @bits == 3) {
            $self->{datetime}->set_day($bits[0]);
            $self->{datetime}->set_month($bits[1]);
            $self->{datetime}->set_year($bits[2]);

            $self->{modified} = 1;

            return $self->_return_dt_object;
        }
    } else {
        @{$self->{tokens}} = split ' ', $date_string;
    }

    my ($dont_proceed1,
        $dont_proceed2,
        $dont_proceed3) = (0,0,0);

    for ($self->{index} = 0; $self->{index} < @{$self->{tokens}}; $self->{index}++) {

        print "$self->{tokens}->[$self->{index}]\n" if $DEBUG;

        $self->_init_data;

        $self->_day;

        if ($self->{tokens}->[$self->{index}] =~ /^second$/i) {
            $self->{modified} = 1;
        }

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
            $self->{datetime}->set_year($1);
        }

        OUTER1: foreach my $match qw(in this) {
            foreach my $i qw(-1 0 1 2) {
                if ($self->{tokens}->[$self->{index}+$i] =~ /$match/i) {
                    $dont_proceed1 = 1;
                    last OUTER1;
                }
            }
        }

       $self->_months unless $dont_proceed1;

       if ($self->{tokens}->[$self->{index}] =~ /^at$/i) {
           next;
       } elsif ($self->{tokens}->[$self->{index}] =~ /^(\d{1,2})(\:\d{2})?(am|pm)?|(noon|midnight)$/i) {
        OUTER2: foreach my $match qw(day in month) {
                foreach my $i qw(-1 0 1 2) {
                    if ($self->{tokens}->[$self->{index}+$i] =~ /^$match$/i) {
                        $dont_proceed2 = 1;
                        last OUTER2;
                    }
                }
            }
            unless ($dont_proceed2) {
                my $hour_token    = $1;
                my $min_token     = $2;
                my $timeframe     = $3;
                my $noon_midnight = $4;
                $self->_at($hour_token, $min_token, $timeframe, $noon_midnight);
            }
        }

        if ($self->{tokens}->[$self->{index}] =~ /^(\d{1,2})(?:st|nd|rd|th)? ?$/i) {
            OUTER3: foreach my $match qw(day week month in) {
                foreach my $i qw(-1 0 1 2) {
                    if ($self->{tokens}->[$self->{index}+$i] =~ /$match/i) {
                       $dont_proceed3 = 1;
                       last OUTER3;
                    }
                }
            }
            OUTER4: foreach my $weekday (keys %{$self->{weekdays}}) {
                if ($self->{tokens}->[$self->{index}+1] =~ /$weekday/i) {
                    $dont_proceed3 = 1;
                    last OUTER4;
                }
            }
            $self->_number($1) unless $dont_proceed3;
        }

        if ($self->{tokens}->[$self->{index}] =~ /^\d{4}$/) {
            $self->{datetime}->set_year($self->{tokens}->[$self->{index}]);
        }

        if ($self->{tokens}->[$self->{index}]      !~ /^(?:this|next|last)$/i
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

    }

    return $self->_return_dt_object;
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

sub _set_modified { $_[0]->{modified} = 1 }

sub _return_dt_object {
    my $self = shift;

    die "$self->{date_string} not valid input, exiting.\n" unless $self->{modified};

    $self->{year}  = $self->{datetime}->year;
    $self->{month} = $self->{datetime}->month;
    $self->{day}   = $self->{datetime}->day_of_month;
    $self->{hour}  = $self->{datetime}->hour;
    $self->{min}   = $self->{datetime}->minute;
    $self->{sec}   = $self->{datetime}->second;

    $self->{sec}   = "0$self->{sec}"   unless length($self->{sec})   == 2;
    $self->{min}   = "0$self->{min}"   unless length($self->{min})   == 2;
    $self->{hour}  = "0$self->{hour}"  unless length($self->{hour})  == 2;
    $self->{day}   = "0$self->{day}"   unless length($self->{day})   == 2;
    $self->{month} = "0$self->{month}" unless length($self->{month}) == 2;

    $self->{modified} = 0;

    my $dt = DateTime->new(year   => $self->{year},
                           month  => $self->{month},
                           day    => $self->{day},
                           hour   => $self->{hour},
                           minute => $self->{min},
                           second => $self->{sec});
    return $dt;
}

sub _set_datetime {
    my ($self, $year, $month, $day, $hour, $min) = @_;

    $self->{datetime} = DateTime->now(time_zone => 'local');

    $self->{nodatetimeset} = 1;

    $self->{datetime}->set_year($year);
    $self->{datetime}->set_month($month);
    $self->{datetime}->set_day($day);
    $self->{datetime}->set_hour($hour);
    $self->{datetime}->set_minute($min);
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
