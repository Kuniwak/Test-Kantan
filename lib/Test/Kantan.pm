package Test::Kantan;
use 5.010_001;
use strict;
use warnings;

our $VERSION = "0.26";

use parent qw(Exporter);

use Try::Tiny;

use Test::Kantan::State;
use Test::Kantan::Builder;
use Test::Kantan::Caller;
use Test::Kantan::Suite;
use Test::Kantan::Expect;

use Test::Deep::NoTest qw(ignore);
use Module::Spy 0.03 qw(spy_on);

our @EXPORT = (
    qw(Feature Scenario Given When Then),
    qw(subtest done_testing setup teardown),
    qw(describe context it),
    qw(before_each after_each),
    qw(expect ok diag ignore spy_on),
);

my $HAS_DEVEL_CODEOBSERVER = !$ENV{KANTAN_NOOBSERVER} && eval "use Devel::CodeObserver 0.11; 1;";

if (Test::Builder->can('new')) {
    # Replace some Test::Builder methods with mine.

    no warnings 'redefine';

    *Test::Builder::ok = sub {
        my ($self, $ok, $msg) = @_;
        Test::Kantan->builder->ok(
            value => $ok,
            message => $msg,
            caller => Test::Kantan::Caller->new(
                $Test::Builder::Level
            ),
        );
    };

    *Test::Builder::subtest = sub {
        my $self = shift;
        goto \&Test::Kantan::subtest;
    };

    *Test::Builder::diag = sub {
        my ($self, $message) = @_;

        Test::Kantan->builder->diag(
            message => $message,
            cutoff  => 1024,
            caller  => Test::Kantan::Caller->new($Test::Builder::Level),
        );
    };

    *Test::Builder::note = sub {
        my ($self, $message) = @_;

        Test::Kantan->builder->diag(
            message => $message,
            cutoff  => 1024,
            caller  => Test::Kantan::Caller->new($Test::Builder::Level),
        );
    };

    *Test::Builder::done_testing = sub {
        my ($self, $message) = @_;

        Test::Kantan->builder->done_testing()
    };
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

sub expect {
    my $stuff = shift;
    Test::Kantan::Expect->new(
        stuff   => $stuff,
        builder => Test::Kantan->builder
    );
}

sub ok(&) {
    my $code = shift;

    if ($HAS_DEVEL_CODEOBSERVER) {
        state $observer = Devel::CodeObserver->new();
        my ($retval, $result) = $observer->call($code);

        my $builder = Test::Kantan->builder;
        $builder->ok(
            value       => $retval,
            caller      => Test::Kantan::Caller->new(0),
        );
        for my $pair (@{$result->dump_pairs}) {
            my ($code, $dump) = @$pair;

            $builder->diag(
                message => sprintf("%s => %s", $code, $dump),
                caller  => Test::Kantan::Caller->new(0),
                cutoff  => $builder->reporter->cutoff,
            );
        }
        return !!$retval;
    } else {
        my $retval = $code->();
        my $builder = Test::Kantan->builder;
        $builder->ok(
            value       => $retval,
            caller      => Test::Kantan::Caller->new(0),
        );
    }
}

sub diag {
    my ($msg, $cutoff) = @_;

    Test::Kantan->builder->diag(
        message => $msg,
        cutoff  => $cutoff,
        caller  => Test::Kantan::Caller->new(0),
    );
}

sub done_testing {
    builder->done_testing
}

END {
    if ($RAN_TEST) {
        unless (builder->finished) {
            die "You need to call `done_testing` before exit";
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

=head1 ENVIRONMENT VARIABLES

=over 4

=item KANTAN_REPORTER

You can specify the reporter class by KANTAN_REPORTER environment variable.

    KANTAN_REPORTER=TAP perl -Ilib t/01_simple.t

=item KANTAN_CUTOFF

Kantan cut the diagnostic message by 80 bytes by default.
If you want to change this value, you can set by KANTAN_CUTOFF.

    KANTAN_CUTOFF=10000 perl -Ilib t/01_simple.t

=back

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=cut
