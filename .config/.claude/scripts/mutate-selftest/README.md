# mutate.rb self-test

Proves the runner still reports all four outcomes. The collection of hand-rolled mutation
drivers this replaced kept losing lessons between rewrites; this is how you catch that.

From the root of any Ruby repo whose `.rspec` loads a plain `spec_helper`:

    mkdir -p tmp/mutants/smoke
    cp ~/.claude/scripts/mutate-selftest/calc*.rb tmp/mutants/smoke/
    cp ~/.claude/scripts/mutate-selftest/table.rb tmp/mutants/
    ruby ~/.claude/scripts/mutate.rb tmp/mutants/table.rb

Expected: M01 killed, M02 SURVIVED, M03 equivalent, M04 INVALID. Then append a spec covering
`Calc.label(-2)` and re-run `--only M02`; it must report `SURVIVED -> killed`.

Afterwards: remove tmp/mutants.
