Feature: Generating D translations
  As a D programmer
  I want to only preprocess dpp files
  So I can have a D translation of the #included header files

  Scenario: Empty definition
    Given a file named "foo.h" with:
      """
      int inc(int);
      """
    Given a file named "bar.h" with:
      """
      int add(int, int);
      """
    Given a file named "baz.h" with:
      """
      """
    And a file named "foo.dpp" with:
      """
      #include "foo.h"
      """
    And a file named "bar.dpp" with:
      """
      #include "bar.h"
      """
    And a file named "baz.dpp" with:
      """
      #include "baz.h"
      """

  When I successfully run `d++ --preprocess-only foo.dpp bar.dpp bar.dpp`
  Then a file named "foo.d" should exist
  And a file named "bar.d" should exist
