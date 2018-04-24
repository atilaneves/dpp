Feature: Compiling a .dpp file that includes a simple C header
  As a D programmer
  I want to compile a .dpp file including a C header in my program
  So I can call legacy code

  Background:
    Given a file named "foo.h" with:
      """
      #ifndef FOO_H
      #define FOO_H
      struct Foo {
          int i;
      };
      struct Foo addFoos(struct Foo* foo1, struct Foo* foo2);
      #endif
      """

    And a file named "foo.c" with:
      """
      #include "foo.h"
      struct Foo addFoos(struct Foo* foo1, struct Foo* foo2) {
          struct Foo foo;
          foo.i = foo1->i + foo2->i;
          return foo;
      }
      """

    And a file named "main.dpp" with:
      """
      #include "foo.h"
      void main(string[] args) {
          import std.stdio;
          import std.conv;

          auto foo1 = Foo(5);
          auto foo2 = Foo(7);
          assert(addFoos(&foo1, &foo2) == Foo(12));

          foo1 = Foo(args[1].to!int);
          foo2 = Foo(args[2].to!int);

          writeln(`Foo(`, args[1], `) + Foo(`, args[2], `) = `, addFoos(&foo1, &foo2));
      }
      """

  Scenario: A C header with a struct and a function

    When I successfully run `gcc -o foo.o -c foo.c`
    And I successfully run `d++ -ofapp main.dpp foo.o`
    When I successfully run `./app 3 4`
    Then the output should contain:
      """
      Foo(3) + Foo(4) = Foo(7)
      """
    And a file named "main.d" should not exist


  Scenario: A C header with a struct and a function and no -of option

    When I successfully run `gcc -o foo.o -c foo.c`
    And I successfully run `d++ main.dpp foo.o`
    When I successfully run `./main 3 4`
    Then the output should contain:
      """
      Foo(3) + Foo(4) = Foo(7)
      """
    And a file named "main.d" should not exist


  Scenario: Only preprocess the file
    When I successfully run `gcc -o foo.o -c foo.c`
    And I successfully run `d++ --preprocess-only main.dpp`
    And I successfully run `dmd -ofapp main.d foo.o`
    When I successfully run `./app 3 4`
    Then the output should contain:
      """
      Foo(3) + Foo(4) = Foo(7)
      """

  Scenario: Compile but don't link
    When I successfully run `d++ -c main.dpp`
    Then a file named "main.o" should exist
