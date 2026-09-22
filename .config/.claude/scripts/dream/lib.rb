#!/usr/bin/env ruby
# Shared plumbing for the dream scripts: where the vault is, which files are in scope,
# and how to read a file's frontmatter without guessing.
#
# Every script reads scope from territory.json rather than hardcoding it, so a directory or
# an exclusion is defined once and every step agrees on it. A script carrying its own copy of
# the scope rules can walk a path another script skips, and nothing reports the disagreement.

require "json"
require "yaml"
require "date"

# launchd supplies no shell profile, so `ruby` resolves to macOS's 2.6 unless the LaunchAgent
# puts a version manager's shims on PATH. Without this the failure is a NoMethodError on
# `tally` or `filter_map` partway through tagging, in a log nobody reads until morning.
if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.0")
  abort "dream: needs Ruby >= 3.0, got #{RUBY_VERSION} at #{RbConfig.ruby}. " \
        "Check the LaunchAgent's EnvironmentVariables:PATH."
end

# The store is full of em-dashes and the config carries them too. Ruby picks its external
# encoding from the locale, and a scheduled job inherits no locale at all, so every read
# would arrive tagged US-ASCII and raise on the first multi-byte character. Pin it here so
# the harness behaves the same from a shell and from launchd.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module Dream
  # DREAM_TERRITORY points the harness at one config file and skips the local overlay.
  # The selftest sets it to a fixture, so the tests never read or write the real store.
  TERRITORY = ENV["DREAM_TERRITORY"] || File.expand_path("~/.claude/skills/dream/territory.json")
  TERRITORY_LOCAL = ENV["DREAM_TERRITORY"] ? nil : File.expand_path("~/.claude/skills/dream/territory.local.json")

  module_function

  # The committed file carries the shape; the local file carries real paths and stays out of
  # the public dotfiles repository. Local top-level keys replace the base ones outright —
  # `directories` and `exclude` are lists, and merging lists produces a scope nobody declared.
  def territory
    @territory ||= begin
      base = JSON.parse(File.read(TERRITORY))
      base = base.merge(JSON.parse(File.read(TERRITORY_LOCAL))) if TERRITORY_LOCAL && File.exist?(TERRITORY_LOCAL)
      base
    end
  end

  def vault
    @vault ||= File.expand_path(territory.fetch("vault"))
  end


  # A path ending in /** excludes a whole subtree; anything else is an exact path.
  # Deliberately not fnmatch: a glob language nobody can predict at 4am is worse than two rules.
  def excluded?(rel)
    territory.fetch("exclude", []).any? do |entry|
      pat = entry.fetch("path")
      pat.end_with?("/**") ? rel.start_with?(pat.sub(%r{/\*\*\z}, "/")) : rel == pat
    end
  end

  # Every in-scope file as [relative path, mode], where mode is "consolidate" or "tag-only".
  # Mode is what separates memories the skill may rewrite from prose it may only tag.
  # A directory listed but absent contributes nothing, which looks identical to a directory
  # with no markdown in it. Say so, because the usual cause is a typo in the config and the
  # run would otherwise report success over a scope it never read.
  #
  # uniq keeps a file listed once when entries overlap (a directory and its parent). Counted
  # twice, a file inflates every catalog total and validate then reports the catalog wrong.
  def files
    Dir.chdir(vault) do
      seen = {}
      # Longest path first, so the most specific entry decides a nested file's mode. Listing
      # order would otherwise decide it: a `tag-only` directory inside a `consolidate` one
      # would inherit `consolidate` and the user's prose would be open to merging.
      ordered = territory.fetch("directories").sort_by { |d| -d.fetch("path").length }
      ordered.each do |dir|
        path = dir.fetch("path")
        warn "dream: territory lists #{path.inspect}, which does not exist under #{vault}" unless Dir.exist?(path)
        Dir.glob(File.join(path, "**", "*.md"))
           .reject { |rel| excluded?(rel) }
           .each { |rel| seen[rel] ||= dir.fetch("mode") }
      end
      seen.sort.map { |rel, mode| [rel, mode] }
    end
  end

  def read(rel)
    File.read(File.join(vault, rel))
  end

  # => {ok:, lines:, close:, body_at:} — close is the index of the closing "---".
  # ok is false for a file with an opening fence and no closing one; callers must skip those
  # rather than repair them, because anything else guesses at where the frontmatter ends.
  def frontmatter(src)
    lines = src.lines
    return {ok: true, lines: lines, close: nil, body_at: 0} unless lines.first&.rstrip == "---"

    # rstrip, not chomp: a fence with a trailing space is valid to Obsidian, and treating it
    # as unclosed would make the file permanently unreadable to this harness with no repair.
    offset = lines[1..].index { |l| l.rstrip == "---" }
    return {ok: false, lines: lines, close: nil, body_at: nil, reason: :unclosed} if offset.nil?

    close = offset + 1

    # A leading `---` is not proof of frontmatter: a note may open with a horizontal rule, and
    # the next rule then looks exactly like a closing fence. The difference is that real
    # frontmatter is a YAML mapping. Without this test, a writer inserts tags between two
    # lines of the user's prose — the one thing tag-only mode exists to prevent.
    #
    # Content that fails the test is refused rather than guessed at. It is either a rule or
    # frontmatter that is already broken, and the two are indistinguishable from here; writing
    # to the first mangles prose and writing to the second compounds the damage.
    begin
      parsed = YAML.safe_load(lines[1...close].join, permitted_classes: [Date, Time], aliases: true)
    rescue Psych::SyntaxError
      return {ok: false, lines: lines, close: close, body_at: nil, reason: :unparseable}
    end
    unless parsed.nil? || parsed.is_a?(Hash)
      return {ok: false, lines: lines, close: close, body_at: nil, reason: :not_a_mapping}
    end

    {ok: true, lines: lines, close: close, body_at: close + 1}
  end

  # The value of a top-level frontmatter key, or nil. Only scans above the closing fence,
  # so a "tags:" appearing in the body is never mistaken for the real one.
  def fm_line_index(fm, key)
    return nil if fm[:close].nil?
    (1...fm[:close]).find { |i| fm[:lines][i].start_with?("#{key}:") }
  end

  # tags: [a, b, c] => ["a", "b", "c"]
  def parse_tags(line)
    line.to_s.sub(/\Atags:\s*/, "").strip.sub(/\A\[/, "").sub(/\]\z/, "")
        .split(",").map { |t| unquote(t.strip) }.reject(&:empty?)
  end

  def unquote(value)
    value.sub(/\A["']/, "").sub(/["']\z/, "")
  end

  # Locates the tags key and reports which YAML shape it uses, so a writer can put the tags
  # back the way it found them. Obsidian's Properties panel writes the block form and a hand
  # edit often writes the inline form; rewriting one into the other changes a file the user
  # did not ask us to restyle, and reading only one form silently drops the other's values.
  #
  # A block sequence is legal at any indentation, zero included:
  #
  #   tags:          tags:
  #     - alpha      - alpha
  #
  # Requiring indentation reads the second form as an empty list, and a writer then splices
  # over the key and orphans the items into invalid YAML. `duplicate` and `ragged` name the
  # two shapes a writer must refuse rather than guess at.
  #
  # => {style: :inline|:block|:ragged|:duplicate, first:, last:, tags:, indent:} or nil.
  def tag_block(fm)
    return nil if fm[:close].nil?
    keys = (1...fm[:close]).select { |i| fm[:lines][i].start_with?("tags:") }
    return nil if keys.empty?
    first = keys.first
    return {style: :duplicate, first: first, last: first, tags: [], indent: nil} if keys.size > 1

    inline = fm[:lines][first].sub(/\Atags:\s*/, "").rstrip
    unless inline.empty?
      # A flow sequence may wrap across lines. This reads one line, so a list whose `]` is on
      # the next line looks complete, and a writer splices over the opening line and orphans
      # the rest — losing the tags on it and breaking the YAML.
      if inline.start_with?("[") && !inline.include?("]")
        return {style: :unterminated, first: first, last: first, tags: [], indent: nil, suffix: nil}
      end

      # Anything after the closing bracket is a comment or stray text. Carry it so a rewrite
      # puts it back; appending merged tags blindly would push them inside the comment, where
      # they parse away silently and the merge reports success having changed nothing.
      body, _, rest = inline.partition("]")
      suffix = rest.strip.empty? ? nil : rest
      tags = body.sub(/\A\[/, "").split(",").map { |t| unquote(t.strip) }.reject(&:empty?)

      return {style: :inline, first: first, last: first, tags: tags, indent: nil, suffix: suffix}
    end

    seq = read_sequence(fm, first + 1)
    style = seq[:indents].uniq.size > 1 ? :ragged : :block
    {style: style, first: first, last: seq[:last], tags: seq[:tags],
     indent: seq[:indents].first || "  ", suffix: nil}
  end

  # Reads a `- value` sequence from `from`, stopping at the first line that is not one.
  # Both the top-level and the nested reader use it: two copies of this drift, and the copy
  # that drifts is the one that forgets to strip a trailing comment, leaving a tag value
  # of "salesforce # note" that no later script can match or rename.
  #
  # `last` comes back as `from - 1` for an empty sequence, so a caller splicing first..last
  # replaces the key line alone rather than a range that runs backwards.
  def read_sequence(fm, from, upto = fm[:close])
    last = from - 1
    tags = []
    indents = []
    (from...upto).each do |i|
      # chomp first: the indent group must not treat the line's newline as trailing space.
      match = fm[:lines][i].chomp.match(/\A([ \t]*)-[ \t]+(.+?)[ \t]*\z/)
      break if match.nil?
      indents << match[1]
      # Strip a trailing comment the way YAML does. Keeping it makes the tag value
      # "salesforce # note", which no script can then match or repair: apply_tags only
      # unions and rename_tag cannot find the real spelling.
      value = match[2].sub(/\s+#.*\z/, "").strip
      tags << unquote(value)
      last = i
    end
    {tags: tags, last: last, indents: indents}
  end

  # Locates a `tags:` key that lives inside the `metadata:` mapping. Auto-memory rewrites a
  # memory's frontmatter as YAML and absorbs a top-level `tags:` key into that mapping, which
  # is where such a key comes from. Every reader here matches `tags:` at column zero, so the
  # file reports as untagged although it carries the tags a session chose deliberately, and
  # the next run tags it again from scratch over that judgement.
  #
  # Only inside `metadata:`. A `tags:` under some other key is a shape nobody has seen here,
  # and lifting a value out of a mapping that meant something by it is not a repair.
  #
  # => {style: :inline|:block|:ragged|:duplicate|:empty, first:, last:, tags:} or nil.
  def nested_tag_block(fm)
    return nil if fm[:close].nil?
    meta = (1...fm[:close]).find { |i| fm[:lines][i].start_with?("metadata:") }
    return nil if meta.nil?

    # The mapping ends at the next key in column zero. Scanning to the fence instead would
    # reach a `tags:` under some later top-level key, which is not nested at all.
    stop = ((meta + 1)...fm[:close]).find { |i| fm[:lines][i].match?(/\A\S/) } || fm[:close]

    keys = ((meta + 1)...stop).select { |i| fm[:lines][i].match?(/\A[ \t]+tags:/) }
    return nil if keys.empty?
    first = keys.first
    return {style: :duplicate, first: first, last: first, tags: []} if keys.size > 1

    inline = fm[:lines][first].sub(/\A[ \t]+tags:[ \t]*/, "").rstrip
    unless inline.empty?
      if inline.start_with?("[") && !inline.include?("]")
        return {style: :unterminated, first: first, last: first, tags: []}
      end
      body, = inline.partition("]")
      tags = body.sub(/\A\[/, "").split(",").map { |t| unquote(t.strip) }.reject(&:empty?)
      return {style: :inline, first: first, last: first, tags: tags}
    end

    seq = read_sequence(fm, first + 1, stop)
    # A key with nothing under it is not an empty tag list: YAML reads the value as nil, and
    # whatever the writer meant, removing the key is a guess. Refuse rather than hoist `[]`.
    return {style: :empty, first: first, last: first, tags: []} if seq[:tags].empty?

    style = seq[:indents].uniq.size > 1 ? :ragged : :block
    {style: style, first: first, last: seq[:last], tags: seq[:tags]}
  end

  # Renders tags in the given style, as the lines to splice in place of first..last.
  def render_tags(tags, style, indent = "  ", suffix = nil)
    return ["tags: [#{tags.join(', ')}]#{suffix}\n"] if style == :inline
    ["tags:\n"] + tags.map { |t| "#{indent}- #{t}\n" }
  end

  WRITABLE_STYLES = %i[inline block].freeze

  def writable_tags?(block)
    block.nil? || WRITABLE_STYLES.include?(block[:style])
  end

  def tags_for(src)
    fm = frontmatter(src)
    return nil unless fm[:ok]
    tag_block(fm)&.fetch(:tags)
  end
end
