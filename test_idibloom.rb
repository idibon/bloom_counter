#!/usr/bin/env ruby

require 'test/unit'
require 'idibloom'

class IdibloomCounterTest < Test::Unit::TestCase
  def test_initialize
    counter = Idibloom::Counter.new :expected => 16, :hashes => 8
    assert_equal counter.send(:counter_size), 4
    assert counter.p_collision < 5e-32, "p_collision is < 5e-32"
    assert counter.p_collision > 4e-32, "p_collision is > 4e-32"
    assert_equal counter.send(:byte_range, 12), (48...52)
  end

  def test_increment_decrement
    counter = Idibloom::Counter.new :size => 1024, :expected => 26
    assert counter.p_collision < 7e-9, "p_collision is < 7e-9"
    ("A".."Z").each {|x| assert_equal counter[x], 0 }
    ("A".."Z").each {|x| counter.increment(x, x.ord) }
    ("A".."Z").each {|x| assert_equal counter[x], x.ord }
    ("A".."Z").each {|x| counter.decrement(x, ?Z.ord) }
    ("A".."Z").each {|x| assert_equal counter[x], 0 }
  end
end

class IdibloomApproximateCounterTest < Test::Unit::TestCase
  def test_initialize
    counter = Idibloom::ApproximateCounter.new :expected => 16, :hashes => 8
    assert_equal counter.send(:counter_size), 1
    assert counter.p_collision < 5e-32, "p_collision is < 5e-32"
    assert counter.p_collision > 4e-32, "p_collision is > 4e-32"
    assert_equal counter.send(:byte_range, 12), (12...13)
  end

  def test_increment_decrement
    counter = Idibloom::ApproximateCounter.new :size => 1024, :expected => 26
    assert counter.p_collision < 7e-9, "p_collision is < 7e-9"
    ("A".."Z").each {|x| assert_equal counter[x], 0 }
    ("A".."Z").each {|x| counter.increment(x, x.ord) }
    ("A".."Z").each {|x|
      floor = 1<<(Math.log(x.ord)/Math.log(2)).floor 
      assert counter[x] >= floor, "counter[#{x}] = #{counter[x]} < #{floor}"
    }
    ("A".."Z").each {|x|
      ceil = 1<<(Math.log(x.ord)/Math.log(2)+1).floor 
      assert counter[x] <= ceil, "counter[#{x}] = #{counter[x]} < #{ceil}"
    }
    ("A".."Z").each {|x| counter.decrement(x, ?Z.ord) }
    ("A".."Z").each {|x| assert_equal counter[x], 0 }
  end
end
