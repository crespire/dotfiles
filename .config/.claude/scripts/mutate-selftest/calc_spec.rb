# frozen_string_literal: true

require_relative "calc"

RSpec.describe Calc do
  it "clamps above the limit" do
    expect(Calc.clamp(10, 5)).to eq(5)
  end

  it "passes through below the limit" do
    expect(Calc.clamp(3, 5)).to eq(3)
  end

  it "labels a positive value" do
    expect(Calc.label(2)).to eq("up")
  end
end

# Deliberately absent: an example covering Calc.label(-2), so M02 survives the first run.
# Appending one is step two of the self-test, and must flip M02 to SURVIVED -> killed.
