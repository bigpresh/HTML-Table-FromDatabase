package HTML::Table::FromDatabase;

use HTML::Table;
use 5.005000;
use strict;
use base qw(HTML::Table);

our $VERSION = '0.01';

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
    my $self = HTML::Table->new(@_);
    
    
    my $sth = $flags{-sth};
    if (!$sth || !ref $sth || !$sth->isa('DBI::st')) {
        warn "HTML::Table::FromDatabase->new requires the -sth argument,"
            ." which must be a valid DBI statement handle.";
        return;
    }
    
    # Find the names;
    my @columns = @{ $sth->{NAME} };
    
    $self->addSectionRow('thead', 0, @columns);
    $self->setSectionRowHead('thead', 0, 1);
    
    # Add all the rows:
    while (my @data = $sth->fetchrow_array) {
        $self->addRow(@data);
    }
    
    # All done, re-bless into our class and return
    bless $self, $class;
    return $self;
};

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

