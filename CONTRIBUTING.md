# Contribution Guidelines

This document aims to provide guidelines for merging changesets into the Sparrow master branch.

For the purpose of this document, we classify changesets/pull requests as:

* big: major changes to core code
* non-trivial: significant changes, fixes and improvements - especially changes to the core modules.
* trivial: minor bugfixes, small changes to auxiliary modules, changes to documentation, and patches which change only the test code.

## Writing & Testing Code:

Write type specification and function signatures because they are remarkably helpful when it comes to reading the source.
Use `mix format` for formatting the code.
Test newly added code. Ensure the test coverage is not decreased. When adding a new module `<my_new_module_name>.ex`, remember to add `<my_new_module_name>_test.exs` in the test directory in the corresponding subdirectory.

What makes a good comment?
Write about why something is done a certain way.
E.g. explain a why a decision was made or describe a subtle but tricky case.
We can read a test case or the source, respectively, to see **what** the code does or **how** it does it.
Comments should give us more insight into **why** something was done (the reasoning).

## 1. Preparation

### Branch and code

Always create a branch with a descriptive name from an up-to-date master.
Do your work in the branch, push it to the ESL repository if you have access to it, otherwise to your own repository.

### Run tests

When done, run `mix test` and write tests related to what you've done.

### Check coding style

Use `mix format` for formatting the code.

### Push

Push the changes and create a pull request to master, following the PR description template.
Make sure all Travis tests pass (if only some jobs fail it is advisable to restart them, since they sometimes
fail at random).

## 2. Review

Both trivial and non-trivial PRs have to be reviewed by at least one other person from the core development team.
For big changesets consult the Tech Lead.
The reviewer's remarks should be placed as inline comments on github for future reference.

Then, apply the reviewer's suggestions.
If the changes are limited to documentation or code formatting, remember to prefix commit message with "[skip ci]" so that the tests results are not a concern.

The reviewer should make sure all of their suggestions are applied.
It is the reviewer who actually does the merge, so they take at least half of the responsibility.

## 3. Merging

I. If your PR is not a trivial one, always rebase onto master.

This is important, because someone may have merged something that is not compatible with your changes and it might be difficult to figure out who should fix it and how.
For the same reason, it is recommended to tell your colleagues that you are about to merge something so that they do not merge at the same time.

II. After rebase, push your branch with -f, make sure all tests pass.

III. Tell your reviewer they can proceed.

They hit the green button, and you can both celebrate.
