---
name: smells
description: Detect code smells in the current changes and provide feedback.
---

Analyze the current branch changes for code smells based on the Reek catalog (https://github.com/troessner/reek/blob/master/docs/Code-Smells.md).

$ARGUMENTS

When analyzing, check the diff against the base branch and look for the following smell categories in the changed code:

**Attribute**: Writable attributes (`attr_accessor`, `attr_writer`) that expose internal state.

**Class Variable**: Usage of `@@class_variables` which form global state.

**Control Couple**: Methods with boolean parameters (defaulting to `true`/`false`) or parameters used as conditionals to choose execution paths.

**Data Clump**: The same group of parameters appearing together across 3+ methods.

**Duplicate Method Call**: The same method call repeated multiple times within a single method.

**Instance Variable Assumption**: Instance variables used without being set in the constructor or lazily initialized.

**Large Class**: Classes with too many constants (>5), instance variables (>4), or methods (>15).

**Long Parameter List**: Methods or blocks with more than 3 parameters.

**Feature Envy**: A method that references another object more than it references `self`.

**Utility Function**: A public instance method with no dependency on instance state (calls methods on other objects, but never uses `self`'s instance variables or methods). IMPORTANT: Only flag public methods. Private and protected methods are excluded from this smell.

**Module Initialize**: An `initialize` method defined inside a module.

**Nested Iterators**: Blocks nested inside other blocks beyond 1 level deep.

**Missing Safe Method**: A bang method (`foo!`) without a corresponding non-bang method (`foo`).

**Simulated Polymorphism**: Manual dispatch (`respond_to?` checks before calling), nil checks (`.nil?`, `== nil`, `when nil`), or repeated conditionals testing the same value across 3+ methods.

**Subclassed From Core Class**: Inheriting directly from `Hash`, `String`, `Array`, or other core classes instead of using composition.

**Too Many Statements**: Methods with more than 5 statements (excluding `initialize`).

**Uncommunicative Name**: Single-character names, names ending with a number, or camelCase names for methods, modules, parameters, or variables.

**Unused Parameters**: Method parameters that are never referenced in the method body.

**Unused Private Method**: Private instance methods that are never called within the class. Be cautious of false positives from dynamic dispatch (`send`) or framework callbacks.

## Reporting

For each smell found, report:

**Location**: File path and line number(s)
**Smell**: Name of the smell
**Description**: Brief explanation of the issue and why it matters
**Suggestion**: A concrete next step to resolve it, with a code example where helpful

At the end, provide a summary count of smells found grouped by category.

If no smells are detected, say so.
