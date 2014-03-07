use strict;
use warnings;
use utf8;
use Test::Kantan;

Feature 'Foo', sub {
    Scenario 'Normal', sub {
        Given 'An array';
        my @ary;

        When 'Push one item';
        push @ary, 1;

        Then 'the number of array is 1', sub {
            diag "Don't show me";
            expect(0+@ary)->to_be(1);
        };
    };
};

Feature 'Foo', sub {
    Scenario 'Normal', sub {
        Given 'An array';
        my @ary;

        When 'Push one item';
        push @ary, 1;

        Then 'the number of array is 1', sub {
            diag "Show me";
            expect(0+@ary)->to_be(0);
        };
    };
};

done_testing;

