Feature: Preprocessing a .dpp file that includes a simple C++ header
  As a D programmer
  I want to compile a .dpp file including a C++ header in my program
  So I can call legacy code

  Background:
    Given a file named "foo.hpp" with:
      """
      #ifndef FOO_HPP
      #define FOO_HPP
      struct Foo {
          int i;
      };
      struct Foo addFoos(struct Foo* foo1, struct Foo* foo2);
      #endif
      """

    And a file named "foo.cpp" with:
      """
      #include "foo.hpp"
      Foo addFoos(Foo* foo1, Foo* foo2) {
          return { foo1->i + foo2-> i};
      }
      """

    And a file named "main.dpp" with:
      """
      #include "foo.hpp"
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
    When I successfully run `g++ -o foo.o -c foo.cpp`
    And I successfully run `d++ -ofapp main.dpp foo.o`
    When I successfully run `./app 3 4`
    Then the output should contain:
      """
      Foo(3) + Foo(4) = Foo(7)
      """

  Scenario: A C header with a struct and a function and no -of option
    When I successfully run `g++ -o foo.o -c foo.cpp`
    And I successfully run `d++ main.dpp foo.o`
    When I successfully run `./main 3 4`
    Then the output should contain:
      """
      Foo(3) + Foo(4) = Foo(7)
      """
