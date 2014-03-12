# NAME

Test::Kantan - simple, flexible, fun "Testing framework"

# SYNOPSIS

    use Test::Kantan;

    describe 'String', sub {
      describe 'index', sub {
        it 'should return -1 when the value is not matched', sub {
          expect(index("abc", 'x'))->to_be(-1);
          expect(index("abc", 'a'))->to_be(0);
        };
      };
    };

# DESCRIPTION

Test::Kantan is a behavior-driven development framework for testing Perl 5 code.
It has a clean, obvious syntax so that you can easily write tests.

# Interfaces

There is 3 types for describing test cases.

## BDD style

RSpec/Jasmine like BDD style function names are available.

    describe 'String', sub {
      before { ... };
      describe 'index', sub {
        it 'should return -1 when the value is not matched', sub {
          expect(index("abc", 'x'))->to_be(-1);
          expect(index("abc", 'a'))->to_be(0);
        };
      };
    };

## Given-When-Then style

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

# Assertions

Here is 2 type assertions.

## `ok()`

    ok { 1 };

There is the `ok` function. It takes one code block. The code returns true value if the test case was passed, false otherwise.

`ok()` returns the value what returned by the code.

## `expect()`

    expect($x)->to_be_true;

Here is the `expect` function like RSpec/Jasmine. For more details, please look [Test::Kantan::Expect](http://search.cpan.org/perldoc?Test::Kantan::Expect).

# Utility functions

## ` diag($message) `

You can show the diagnostic message with ` diag() ` function.
Diagnostic message would not print if whole test cases in the subtest were passed.

It means, you can call diag() without worries about the messages is a obstacle.

# LICENSE

Copyright (C) Tokuhiro Matsuno.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Tokuhiro Matsuno <tokuhirom@gmail.com>
