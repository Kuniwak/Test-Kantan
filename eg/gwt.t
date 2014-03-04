use strict;
use warnings;
use utf8;
use Test::Kantan::GWT;

Feature 'Foo', sub {
    Scenario 'Normal', sub {
        Given 'An array';
        my @ary;

        When 'Push one item';
        push @ary, 1;

        Then 'the number of array is 1', sub {
            expect(0+@ary) == 1;
        };
    };
};


done_testing;
