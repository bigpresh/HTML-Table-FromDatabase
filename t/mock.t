#!/usr/bin/perl

# $Id$
# Put HTML::Table::FromDatabase through its paces, using Test::MockObject
# to provide a fake statement handle which provides known data.

use strict;
use Test::More;
use HTML::Table::FromDatabase;

eval "use Test::MockObject";
plan skip_all => "Test::MockObject required for mock testing"
    if $@;

# OK, we've got Test::MockObject, so we can go ahead:
plan tests => 10;

# Easy test: get a mock statement handle, and check we can make a table:
my $mock = mocked_sth();
my $table = HTML::Table::FromDatabase->new( -sth => $mock );
ok($table, 'Seemed to get a table back');
isa_ok($table, 'HTML::Table', 'We got something that ISA HTML::Table');
my $html = $table->getTable;
like($html, qr{<th>Col1</th>}, 'Table contains one of the known column names');
like($html, qr{<td>R1C1</td>}, 'Table contains a known field value');

# now, test transformations:
$mock = mocked_sth();
$table = HTML::Table::FromDatabase->new(
    -sth => $mock,
    -callbacks => [
        {
            column => qr/Col[12]/,
            transform => sub { "RE_T" },
        },
        {
            column => 'Col3',
            transform => sub { "Plain_T" },
        },
        {
            value => 'R2C4',
            transform => sub { $_ = shift; s/R\dC\d/value_T/; $_ },
        },
    ],
);
$html = $table->getTable;
warn $html;
like($html, qr{<td>RE_T</td><td>RE_T</td>},
    'Callback regexp-matching column transformed OK');
like($html, qr{<td>Plain_T</td>},
    'Callback plain-matching column transformed OK');
like($html, qr{<td>value_T</td>}, 'Callback matching cell value transform OK');


# We can only test HTML stripping if HTML::Strip is available.
SKIP: {
    eval { require "HTML::Strip"; };
    skip "HTML::Strip not installed", 2 if $@;
    
    # check that HTML is stripped/encoded properly
    $mock = mocked_sth();
    $table = HTML::Table::FromDatabase->new(-sth => $mock, -html => 'strip');
    $html = $table->getTable;
    like(  $html, qr{<td>HTML</td>}, 'HTML stripped correctly');
    unlike($html, qr{evilscript},    'Scripts removed correctly');
}

# Check that HTML is encoded properly:
$mock = mocked_sth();
$table = HTML::Table::FromDatabase->new(-sth => $mock, -html => 'escape');
$html = $table->getTable;
like($html, qr{<td>&lt;p&gt;HTML&lt;/p&gt;</td>}, 'HTML encoded correctly');


# Returns a make-believe statement handle, which should behave just like
# a real one would, returning known data to test against.
sub mocked_sth {
    # Create a make-believe statement handle:
    my $mock = Test::MockObject->new();
    $mock->set_isa('DBI::st');

    # Make it behave as we'd expect:
    $mock->{NAME} = [ qw(Col1 Col2 Col3 Col4) ];
    
    #$mock->mock('fetchrow_hashref', sub { pop @{ shift->{_test_rows} } });
    $mock->set_series('fetchrow_hashref', 
        { Col1 => 'R1C1', Col2 => 'R1C2', Col3 => 'R1C3', Col4 => 'R1C4' },
        { Col1 => 'R2C1', Col2 => 'R2C2', Col3 => 'R2C3', Col4 => 'R2C4' },
        { Col1 => 'R3C1', Col2 => 'R3C2', Col3 => 'R3C3', Col4 => 'R3C4' },
        {
            Col1 => '<p>HTML</p>',
            Col2 => '<div align="center">R3C2</div>',
            Col3 => '<script>evilscript</script>',
            Col4 => 'R3C4',
        },
    );
}