# frozen_string_literal: true

module Helpers
  module Assertions
    def assert_hash_equals(exp, act, msg = nil)
      msg = message(msg, '') { diff exp, act }

      assert(matches_hash?(exp, act, { exact: true }), msg)
    end

    def assert_array_equals(exp, act, msg = nil)
      msg = message(msg, '') { diff exp, act }

      assert(matches_array?(exp, act, { exact: true }), msg)
    end
  end
end
