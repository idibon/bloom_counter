module Idibloom
  class Counter
    def initialize(args={})
      @size = args[:size] || (1<<20)
      @counter = args[:counter] || default_counter
      @expected = args[:expected]
      if @expected and not args[:hashes]
        @hash_count = (@size * Math.log(2) / @expected.to_f).ceil
      else
        @hash_count = args[:hashes] || 4
      end
      @counter_size = counter_size
      @filter = "\x00" * (@size * @counter_size)
    end

    def increment(key, step=1)
      hashes(key).each do |hash|
        @filter[byte_range(hash)] = [incr(hash, step)].pack(@counter)
      end
    end

    def decrement(key, step=1)
      hashes(key).each do |hash|
        @filter[byte_range(hash)] = [decr(hash, step)].pack(@counter)
      end
    end

    def [](key)
      hashes(key).map {|h| count(h)}.min
    end

    def save(f)
      f.write(@filter)
    end

    def p_collision
      return nil if not @expected
      (1.0 - Math.exp(-@hash_count * @expected / @size.to_f)) ** @hash_count
    end

    def to_a
      @filter.unpack(@counter + "*")
    end

    def self.load(f, args={})
      obj = self.new args
      obj.filter = f.read()
      obj
    end

    protected

    def default_counter
      "N" # 32 bit unsigned big-endian int
    end

    def counter_size
      [0].pack(@counter).length
    end

    def filter=(bytes)
      @filter = bytes
      @size = bytes.length / counter_size
    end

    def byte_range(hash)
      (hash * @counter_size) ... ((hash + 1) * @counter_size)
    end

    def count(hash)
      @filter[byte_range(hash)].unpack(@counter)[0]
    end

    def hashes(key)
      (0...@hash_count).map {|n| (key + n.to_s).hash % @size}
    end

    def max_count
      1 << (@counter_size * 8)
    end

    def incr(hash, step)
      n = count(hash) + step.abs
      n > max_count ? max_count : n
    end

    def decr(hash, step)
      n = count(hash) - step.abs
      n = n < 0 ? 0 : n
    end
  end

  class ApproximateCounter < Counter
    def [](key)
      m = hashes(key).map {|h| count(h)}.min
      (1 << m) >> 1
    end

    protected

    def default_counter
      "C"
    end

    def incr(hash, step)
      n = count(hash)
      n += 1 while rand(1 << n) < step.abs
      n
    end

    def decr(hash, step)
      n = count(hash)
      n -= 1 while n > 0 and rand(1 << n) < step.abs
      n
    end
  end
end
