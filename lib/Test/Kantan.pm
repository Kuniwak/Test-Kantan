package Test::Kantan;
use 5.010_001;
use strict;
use warnings;

our $VERSION = "0.24";

use parent qw(Exporter);

use Try::Tiny;

use Test::Kantan::State;
use Test::Kantan::Builder;
use Test::Kantan::Caller;
use Test::Kantan::Suite;
use Test::Kantan::Functions;

our @EXPORT = (
    qw(Feature Scenario Given When Then),
    qw(subtest done_testing setup teardown),
    qw(describe context it),
    qw(before_each after_each),
    @Test::Kantan::Functions::EXPORT
);

if (Test::Builder->can('new')) {
    # Replace some Test::Builder methods with mine.

    no warnings 'redefine';

    sub Test::Builder::ok {
        my ($self, $ok, $msg) = @_;
        Test::Kantan->builder->ok(
            value => $ok,
            message => $msg,
            caller => Test::Kantan::Caller->new(
                $Test::Builder::Level
            ),
        );
    }

    sub Test::Builder::subtest {
        my $self = shift;
        goto \&Test::Kantan::subtest;
    }

    sub Test::Builder::diag {
        my ($self, $message) = @_;

        Test::Kantan->builder->diag(
            message => $message,
            cutoff  => 1024,
            caller  => Test::Kantan::Caller->new($Test::Builder::Level),
        );
    }

    sub Test::Builder::note {
        my ($self, $message) = @_;

        Test::Kantan->builder->diag(
            message => $message,
            cutoff  => 1024,
            caller  => Test::Kantan::Caller->new($Test::Builder::Level),
        );
    }
}

our $BUILDER;
sub builder {
    if (not defined $BUILDER) {
        $BUILDER = Test::Kantan::Builder->new();
    }
    return $BUILDER;
}

# -------------------------------------------------------------------------
# DSL functions

our $CURRENT = our $ROOT = Test::Kantan::Suite->new(root => 1, title => 'Root');
our $FINISHED;
our $RAN_TEST;

sub setup(&) {
    my ($code) = @_;
    $CURRENT->add_trigger('setup' => $code);
}
sub before_each { goto \&setup }

sub teardown(&) {
    my ($code) = @_;
    $CURRENT->add_trigger('teardown' => $code);
}
sub after_each { goto \&teardown }

sub _step {
    my ($tag, $title, $code) = @_;

    my $last_state = $CURRENT->{last_state};
    $CURRENT->{last_state} = $tag;
    if ($last_state && $last_state eq $tag) {
        $tag = 'And';
    }

    my $guard = builder->reporter->suite(sprintf("%5s %s", $tag, $title));
    if ($code) {
        try {
            $code->();
        } catch {
            builder->exception(message => $_);
        };
    }
}

sub Given { _step('Given', @_) }
sub When  { _step('When', @_) }
sub Then  { _step('Then', @_) }

sub _suite {
    my ($tag, $title, $code) = @_;

    my $suite = Test::Kantan::Suite->new(
        title   => $title,
        parent  => $CURRENT,
    );
    {
        local $CURRENT = $suite;
        builder->subtest(
            title => defined($tag) ? "${tag} ${title}" : $title,
            code  => $code,
            suite => $suite,
        );
    }
    $RAN_TEST++;
}

sub Feature  { _suite( 'Feature', @_) }
sub Scenario { _suite('Scenario', @_) }

# Test::More compat
sub subtest  { _suite(     undef, @_) }

# BDD compat
sub describe { _suite(     undef, @_) }
sub context  { _suite(     undef, @_) }
sub it       { _suite(     undef, @_) }

sub done_testing {
    $FINISHED++;

    builder->reporter->finalize();

    # Test::Pretty was loaded
    if (Test::Pretty->can('_subtest')) {
        # Do not run Test::Pretty's finalization
        $Test::Pretty::NO_ENDING=1;
    }
}

END {
    if ($RAN_TEST) {
        unless ($FINISHED) {
            done_testing()
        }
    }
}


1;
__END__

=encoding utf-8

=head1 NAME

Test::Kantan - simple, flexible, fun "Testing framework"

=head1 SYNOPSIS

  use Test::Kantan;

  describe 'String', sub {
    describe 'index', sub {
      it 'should return -1 when the value is not matched', sub {
        expect(index("abc", 'x'))->to_be(-1);
        expect(index("abc", 'a'))->to_be(0);
      };
    };
  };

=head1 DESCRIPTION

Test::Kantan is a behavior-driven development framework for testing Perl 5 code.
It has a clean, obvious syntax so that you can easily write tests.

=head1 Interfaces

There is 3 types for describing test cases.

=head2 BDD style

RSpec/Jasmine like BDD style function names are available.

  describe 'String', sub {
    before_each { ... };
    describe 'index', sub {
      it 'should return -1 when the value is not matched', sub {
        expect(index("abc", 'x'))->to_be(-1);
        expect(index("abc", 'a'))->to_be(0);
      };
    };
  };

  done_testing;

=head2 Given-When-Then style

There is the Given-When-Then style functions.
It's really useful for describing real complex problems.

  Scenario 'String', sub {
    setup { ... };

    Feature 'Get the index from the code', sub {
      Given 'the string';
      my $str = 'abc';

      When 'get the index for "a"';
      my $i = index($str, 'a');

      Then 'the return value is 0';
      expect($i)->to_be(0);
    };
  };

  done_testing;

=head2 Plain old Test::More style

  subtest 'String', sub {
    setup { ... };

    subtest 'index', sub {
      expect(index("abc", 'x'))->to_be(-1);
      expect(index("abc", 'a'))->to_be(0);
    };
  };

  done_testing;

=head1 Assertions

Here is 2 type assertions.

=head2 C<ok()>

    ok { 1 };

There is the C<ok> function. It takes one code block. The code returns true value if the test case was passed, false otherwise.

C<ok()> returns the value what returned by the code.

=head2 C<expect()>

    expect($x)->to_be_true;

Here is the C<expect> function like RSpec/Jasmine. For more details, please look L<Test::Kantan::Expect>.

=head1 Utility functions

=head2 C< diag($message) >

You can show the diagnostic message with C< diag() > function.
Diagnostic message would not print if whole test cases in the subtest were passed.

It means, you can call diag() without worries about the messages is a obstacle.

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=cut
