# frozen_string_literal: true

module JSONAPI
  # Cache which memoizes the given block.
  #
  # It's "naive" because it clears the least-recently-inserted cache entry
  # rather than the least-recently-used. This makes lookups faster but cache
  # misses more frequent after cleanups. Therefore you the best time to use
  # this cache is when you expect only a small number of unique lookup keys, so
  # that the cache never has to clear.
  #
  # Also, it's not thread safe (although jsonapi-resources is careful to only
  # use it in a thread safe way).
  class NaiveCache
    def initialize(cap = 10000, &calculator)
      @cap = cap
      @data = {}
      @calculator = calculator
    end

    def get(key)
      found = true
      value = @data.fetch(key) { found = false }
      return value if found

      value = @calculator.call(key)
      @data[key] = value
      @data.shift if @data.length > @cap
      return value
    end
  end
end
