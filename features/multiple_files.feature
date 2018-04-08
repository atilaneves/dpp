Feature: Compiling multiple .dpp files
  As a D programmer
  I want to compile several .dpp files at once
  So I don't have to compile them one at a time

  @wip
  Scenario: 3 .dpp files

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

    And a file named "defs.h" with:
      """
      #define FACTOR 2
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

    And a file named "foo.dpp" with:
      """
      #include "foo.h"
      """

    And a file named "io.dpp" with:
      """
      #include <stdio.h>
      import foo;
      void printFoo(Foo foo) {
          import std.conv: to;
          import std.string: toStringz;
          printf("%s\n", foo.to!string.toStringz);
      }
      """

    And a file named "maths.dpp" with:
      """
      #include "defs.h"
      import foo;
      Foo addFoosMul2(Foo foo1, Foo foo2) {
         auto ret = addFoos(&foo1, &foo2);
         ret.i *= FACTOR;
         return ret;
      }
      """

    And a file named "app.d" with:
      """
      import foo;
      import io;
      import maths;
      import std.conv: to;
      void main(string[] args) {
          auto f1 = Foo(args[1].to!int);
          auto f2 = Foo(args[2].to!int);
          auto r = addFoosMul2(f1, f2);
          printFoo(r);
      }
      """

    When I successfully run `gcc -o c.o -c foo.c`
    And I successfully run `d++ --keep-d-files app.d foo.dpp io.dpp maths.dpp c.o`
    When I successfully run `./app 3 4`
    Then the output should contain:
      """
      Foo(14)
      """
    When I successfully run `./app 5 8`
    Then the output should contain:
      """
      Foo(26)
      """
