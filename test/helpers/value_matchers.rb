# frozen_string_literal: true

module Helpers
  module ValueMatchers
    ### Matchers
    def matches_value?(v1, v2, options = {})
      if v1 == :any
        # any value is acceptable
      elsif v1 == :not_nil
        if v2 == nil
          return false
        end
      elsif v1.kind_of?(Hash)
        unless matches_hash?(v1, v2, options)
          return false
        end
      elsif v1.kind_of?(Array)
        unless matches_array?(v1, v2, options)
          return false
        end
      else
        unless v2 == v1
          return false
        end
      end
      true
    end

    def matches_array?(array1, array2, options = {})
      return false unless array1.kind_of?(Array) && array2.kind_of?(Array)

      if options[:exact]
        unless array1.size == array2.size
          return false
        end
      end

      # order of items shouldn't matter:
      #    ['a', 'b', 'c'], ['b', 'c', 'a'] -> true
      #
      # matched items should only be used once:
      #    ['a', 'b', 'c'], ['a', 'a', 'a'] -> false
      #    ['a', 'a', 'a'], ['a', 'b', 'c'] -> false
      matched = {}
      (0..(array1.size - 1)).each do |i|
        (0..(array2.size - 1)).each do |j|
          if !matched.has_value?(j.to_s) && matches_value?(array1[i], array2[j], options)
            matched[i.to_s] = j.to_s
            break
          end
        end
        unless matched.has_key?(i.to_s)
          return false
        end
      end
      true
    end

    # options => {exact: true} # hashes must match exactly (i.e. have same number of key-value pairs that are all equal)
    def matches_hash?(hash1, hash2, options = {})
      return false unless hash1.kind_of?(Hash) && hash2.kind_of?(Hash)

      if options[:exact]
        unless hash1.size == hash2.size
          return false
        end
      end

      hash1 = hash1.deep_symbolize_keys
      hash2 = hash2.deep_symbolize_keys

      hash1.each do |k1, v1|
        unless hash2.has_key?(k1) && matches_value?(v1, hash2[k1], options)
          return false
        end
      end
      true
    end
  end
end
