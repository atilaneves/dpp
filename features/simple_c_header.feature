Feature: Including a simple C header works
  As a D programmer
  I want to include a C header in my program
  So I can call legacy code

  Scenario: A C header with a struct and a function

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

          auto foo1 = struct_Foo(5);
          auto foo2 = struct_Foo(7);
          assert(addFoos(&foo1, &foo2) == struct_Foo(12));

          foo1 = struct_Foo(args[1].to!int);
          foo2 = struct_Foo(args[2].to!int);

          writeln(`struct_Foo(`, args[1], `) + struct_Foo(`, args[2], `) = `, addFoos(&foo1, &foo2));
      }
      """

    When I successfully run `gcc -o foo.o -c foo.c`
    And I successfully run `include main.dpp main.d`
    And I successfully run `dmd -ofapp main.d foo.o`
    When I successfully run `./app 3 4`
    Then the output should contain:
      """
      struct_Foo(3) + struct_Foo(4) = struct_Foo(7)
      """
