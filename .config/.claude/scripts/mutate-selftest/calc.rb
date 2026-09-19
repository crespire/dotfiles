# frozen_string_literal: true

# Smoke target for the mutation runner. Not application code.
class Calc
  def self.clamp(value, limit)
    return limit if value > limit

    value
  end

  def self.label(value)
    value.positive? ? "up" : "down"
  end

  def self.unpinned(value)
    value.abs
  end
end
