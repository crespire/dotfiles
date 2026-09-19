# Smoke table for the mutation runner itself. Targets tmp/mutants/smoke/calc.rb, not app code.
{
  specs: %w[tmp/mutants/smoke/calc_spec.rb],
  timeout: 120,
  mutants: [
    {id: "M01", label: "clamp comparison flipped",
     failure_mode: "values below the limit get clamped to the limit",
     file: "tmp/mutants/smoke/calc.rb",
     from: "return limit if value > limit",
     to: "return limit if value < limit"},

    {id: "M02", label: "label always reports up",
     failure_mode: "a negative value is described as positive",
     file: "tmp/mutants/smoke/calc.rb",
     from: "value.positive? ? \"up\" : \"down\"",
     to: "\"up\""},

    {id: "M03", label: "abs swapped for its alias",
     failure_mode: "nothing — magnitude is an alias of abs",
     equivalent: "Numeric#magnitude is an alias of Numeric#abs, so no caller can observe the change.",
     file: "tmp/mutants/smoke/calc.rb",
     from: "value.abs",
     to: "value.magnitude"},

    {id: "M04", label: "deliberately unparseable",
     failure_mode: "nothing — this mutant exists to prove a load failure is not read as a result",
     file: "tmp/mutants/smoke/calc.rb",
     from: "def self.label(value)",
     to: "def self.label(value"}
  ]
}
