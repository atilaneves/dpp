Feature: Passing macros on the command-line
  As a D programmer
  I want to pass preprocessor macros on the command-line
  So I can select compile-time switches in #included headers

  Scenario: Empty definition
    Given a file named "foo.h" with:
      """
      #ifdef FOO
          struct Foo { int i; };
      #else
          struct Bar { int j; };
      #endif
      """
    And a file named "foo.dpp" with:
      """
      #include "foo.h"
      void main() {
          Foo f;
          f.i = 42;
      }
      """

  Then I successfully run `d++ --keep-pre-cpp-files --keep-d-files --define FOO foo.dpp`


  Scenario: Definition with value
    Given a file named "foo.h" with:
      """
      #if FOO == 42
          struct Foo { int i; };
      #else
          struct Bar { int j; };
      #endif
      """
    And a file named "foo.dpp" with:
      """
      #include "foo.h"
      void main() {
          Foo f;
          f.i = 42;
      }
      """

  Then I successfully run `d++ --keep-pre-cpp-files --keep-d-files --define FOO=42 foo.dpp`
