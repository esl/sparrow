%{
    configs: [
      %{
        name: "default",
        files: %{
          included: ["lib/"],
          excluded: [~r"/_build/", ~r"/deps/", "test/"]
        },
        requires: [],
        strict: true,
        checks: [
          {Credo.Check.Consistency.ExceptionNames},
          {Credo.Check.Consistency.LineEndings},
          {Credo.Check.Consistency.SpaceAroundOperators},
          {Credo.Check.Consistency.SpaceInParentheses},
          {Credo.Check.Consistency.TabsOrSpaces},
          {Credo.Check.Design.DuplicatedCode, excluded_macros: [:setup, :test]},
          {Credo.Check.Design.TagTODO, exit_status: 0},
          {Credo.Check.Design.TagFIXME},
          {Credo.Check.Design.AliasUsage, false},
          {Credo.Check.Readability.FunctionNames},
          {Credo.Check.Readability.LargeNumbers},
          {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 90},
          {Credo.Check.Readability.ModuleAttributeNames},
          {Credo.Check.Readability.ModuleDoc},
          {Credo.Check.Readability.ModuleNames},
          {Credo.Check.Readability.ParenthesesInCondition},
          {Credo.Check.Readability.PredicateFunctionNames},
          {Credo.Check.Readability.TrailingBlankLine},
          {Credo.Check.Readability.TrailingWhiteSpace},
          {Credo.Check.Readability.VariableNames},

          {Credo.Check.Refactor.ABCSize, max_size: 34},
          {Credo.Check.Refactor.CondStatements},
          {Credo.Check.Refactor.FunctionArity},
          {Credo.Check.Refactor.MatchInCondition},
          {Credo.Check.Refactor.PipeChainStart},
          {Credo.Check.Refactor.CyclomaticComplexity},
          {Credo.Check.Refactor.NegatedConditionsInUnless},
          {Credo.Check.Refactor.NegatedConditionsWithElse},
          {Credo.Check.Refactor.Nesting},
          {Credo.Check.Refactor.UnlessWithElse},

          {Credo.Check.Warning.IExPry},
          {Credo.Check.Warning.IoInspect},
          {Credo.Check.Warning.OperationOnSameValues},
          {Credo.Check.Warning.BoolOperationOnSameValues},
          {Credo.Check.Warning.UnusedEnumOperation},
          {Credo.Check.Warning.UnusedKeywordOperation},
          {Credo.Check.Warning.UnusedListOperation},
          {Credo.Check.Warning.UnusedStringOperation},
          {Credo.Check.Warning.UnusedTupleOperation},
          {Credo.Check.Warning.OperationWithConstantResult},

          {Credo.Check.Design.DuplicatedCode, excluded_macros: [:setup, :test]},
        ]
      }
    ]
  }
