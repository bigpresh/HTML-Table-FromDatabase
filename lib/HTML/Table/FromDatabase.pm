package HTML::Table::FromDatabase;

use HTML::Table;
use 5.005000;
use strict;
use base qw(HTML::Table);
use vars qw($VERSION);
$VERSION = '0.01';

# $Id$

=head1 NAME

HTML::Table::FromDatabase - subclass of HTML::Table to generate tables
easily from a database query

=head1 SYNOPSIS

 my $sth = $dbh->prepare('select * from my_table')
    or die "Failed to prepare query - " . $dbh->errstr;
 $sth->execute() or die "Failed to execute query - " . $dbh->errstr;

 my $table = HTML::Table::FromDatabase->new( -sth => $sth );
 $table->print;

=head1 DESCRIPTION

Subclasses L<HTML::Table>, providing a quick and easy way to produce HTML
tables from the result of a database query.

I often find myself writing scripts which fetch data from a database and
present it in a HTML table; often resulting in pointlessly repeated code
to take the results and turn them into a table.

HTML::Table itself helps here, but this module makes it even simpler.

Row headings are taken from the field names returned by the query.

All options you pass to the constructor will be passed through to HTML::Table,
so you can use all the usual HTML::Table features.


=head1 INTERFACE

=over 4

=item new

Constructor method - consult L<HTML::Table>'s documentation, the only
difference here is the addition of the required I<-sth> parameter which
should be a DBI statement handle.

=cut

sub new {
    my $class = shift;
    
    my %flags = @_;
    my $sth = delete $flags{-sth};
    
    if (!$sth || !ref $sth || !$sth->isa('DBI::st')) {
        warn "HTML::Table::FromDatabase->new requires the -sth argument,"
            ." which must be a valid DBI statement handle.";
        return;
    }

    my $callbacks = delete $flags{-callbacks};
    if ($callbacks && ref $callbacks ne 'ARRAY') {
        warn "Unrecognised -callbacks parameter; "
            ."expected a arrayref of hashrefs";
        return;
    }
    # Create a HTML::Table object, passing along any other options we were
    # given:
    my $self = HTML::Table->new(%flags);
    
    # Find the names;
    my @columns = @{ $sth->{NAME} };
    
    $self->addSectionRow('thead', 0, @columns);
    $self->setSectionRowHead('thead', 0, 1);
    
    # Add all the rows:
    while (my $row = $sth->fetchrow_hashref) {
        my @fields;
        for my $column (@columns) {
            my $value = $row->{$column};

            # If we have a callbck to perform for this field, do it:
            for my $callback (@$callbacks) {
                # See what we need to match against, and if it matches, call
                # the specified transform callback to potentially change the
                # value.
                if (exists $callback->{column}) {
                    if (_callback_matches($callback->{column}, $column)) {
                        $value = _perform_callback($callback, $column, $value);
                    }
                }
                if (exists $callback->{value}) {
                    if (_callback_matches($callback->{value}, $value)) {
                        $value = _perform_callback($callback, $column, $value);
                    }
                }
            }
            
            # Add this field to the list to deal with:
            push @fields, $value;
        }
        
        $self->addRow(@fields);
    }
    
    # All done, re-bless into our class and return
    bless $self, $class;
    return $self;
};

# Abstract out the different kind of matches (regexp, coderef or straight
# scalar)
sub _callback_matches {
    my ($match, $against) = @_;
    if (ref $match eq 'Regexp') {
        return $against =~ /$match/;
    } elsif (ref $match eq 'CODE') {
        return $match->($against);
    } elsif (ref $match) {
        # A reference to something we don't understand:
        warn "Unrecognised callback match [$match]";
        return;
    } else {
        # Must be a straight scalar
        return $match eq $against;
    }
}

# A callback spec matched, so perform any callback it requests, and apply
# any transformation it described:
sub _perform_callback {
    my ($callback, $column, $value) = @_;

    # Firstly, if there's a callback to perform, we call it (but don't
    # care what it returns):
    if (exists $callback->{callback} and ref $callback->{callback} eq 'CODE')
    {
        $callback->{callback}->($value, $column);
    }

    # Now, look for a transformation we might have to perform:
    if (!exists $callback->{transform}) {
        # We don't have a transform to perform, so just return the value
        # unchanged:
        return $value;
    }
    if (ref $callback->{transform} ne 'CODE') {
        warn "Unrecognised transform action";
        return $value;
    }

    # OK, apply the transformation to the value:
    return $callback->{transform}->($value);
}

1;
__END__;

=back

=head1 AUTHOR

David Precious, E<lt>davidp@preshweb.co.ukE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by David Precious

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

