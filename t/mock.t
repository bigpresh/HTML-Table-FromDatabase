#!/usr/bin/perl


use strict;
use Test::More;
use HTML::Table::FromDatabase;

eval "use Test::MockObject";
plan skip_all => "Test::MockObject required for mock testing"
    if $@;

# OK, we've got Test::MockObject, so we can go ahead:
plan tests => 6;

# Easy test: get a mock statement handle, and check we can make a table:
my $mock = mocked_sth();


my $table = HTML::Table::FromDatabase->new( -sth => $mock );

ok($table, 'Seemed to get a table back');
isa_ok($table, 'HTML::Table', 'We got something that ISA HTML::Table');
my $html = $table->getTable;
warn $html;
ok($html =~ m{<th>Col1</th>}, 'Table contains one of the known column names');
ok($html =~ m{<td>R1C1</td>}, 'Table contains a known field value');

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
    ],
);
$html = $table->getTable;
warn $html;
ok($html =~ m{<td>RE_T</td><td>RE_T</td>}, 'Regexp transform OK');
ok($html =~ m{<td>Plain_T</td>}, 'Plain transform OK');



# Returns a make-believe statement handle, which should behave just like
# a real one would, returning known data to test against.
sub mocked_sth {
    # Create a make-believe statement handle:
    my $mock = Test::MockObject->new();
    $mock->set_isa('DBI::st');

    # Make it behave as we'd expect:
    $mock->{NAME} = [ qw(Col1 Col2 Col3) ];
    
    #$mock->mock('fetchrow_hashref', sub { pop @{ shift->{_test_rows} } });
    $mock->set_series('fetchrow_hashref', 
        { Col1 => 'R1C1', Col2 => 'R1C2', Col3 => 'R1C3' },
        { Col1 => 'R2C1', Col2 => 'R2C2', Col3 => 'R2C3' },
        { Col1 => 'R3C1', Col2 => 'R3C2', Col3 => 'R3C3' },
    );
}