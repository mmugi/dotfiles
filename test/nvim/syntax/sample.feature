# language: en
# Syntax highlight sample for checking colorschemes (legacy Cucumber syntax).

@bakery
Feature: Count the rolls

  Background:
    Given the oven is warm

  @smoke
  Scenario: Trays are full
    Given 3 trays with "plain" rolls
    When the baker counts them
    Then the total is 36

  @regression
  Scenario Outline: Price by flavor
    Given a "<flavor>" roll
    When the price is checked
    Then it costs <price>

    @seasonal
    Examples:
      | flavor | price |
      | matcha | 154   |

  @slow
  Rule: Closed shops sell nothing
