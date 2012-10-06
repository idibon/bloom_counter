module Idibloom
  class Counter
    def initialize(args={})
      @size = args[:size] || (1<<20)
      @counter = args[:counter] || default_counter
      @expected = args[:expected]
      @counter_size = counter_size
      @filter = "\x00" * (@size * @counter_size)
      set_hash_count args[:hashes]
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
      f = File.open(f, "wb") if f.is_a? String
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
      begin
        f = File.open(f) if f.is_a? String
        obj.send(:set_filter, f.read(), args[:hashes])
      rescue Errno::ENOENT
       raise unless args[:create]
      end
      obj
    end

    protected

    def default_counter
      "N" # 32 bit unsigned big-endian int
    end

    def counter_size
      [0].pack(@counter).length
    end

    def set_hash_count(hash_count)
      if @expected and not hash_count
        @hash_count = (@size * Math.log(2) / @expected.to_f).ceil
      else
        @hash_count = hash_count || 4
      end
    end

    def set_filter (bytes, hash_count=nil)
      @filter = bytes
      @size = bytes.length / counter_size
      set_hash_count(hash_count)
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

  class ExactCounter < Counter
    def initialize(*args)
      super *args
      @keys = {}
      @filter = nil
    end

    def increment(key, step=1)
      @keys[key] ||= 0
      @keys[key] += 1
    end

    def decrement(key, step=1)
      @keys[key] ||= 0
      @keys[key] -= 1
      @keys[key] = 0 if @keys[key] < 0
    end

    def [](key)
      @keys[key]
    end

    def save(f)
      f = File.open(f, "wb") if f.is_a? String
      f.write(JSON.generate @keys)
    end

    def to_a
      @keys.values
    end

    protected

    def set_filter (bytes, hash_count=nil)
      @keys = JSON.parse bytes
    end
  end

  class Weights < Counter
    def default_counter
      "g" # single-precision network-endian float
    end

    def []= (key, val)
      hashes(key).each do |hash|
        @filter[byte_range(hash)] = [val.to_f].pack(@counter)
      end
    end

    def [](key)
      weights = {}
      # what is the most frequent value for this key?
      # count how often each value occurs.
      hashes(key).each do |hash|
        value = @filter[byte_range(hash)].unpack(@counter)
        weights[value] = (weights[value] || 0) + 1
      end
      # sort on the frequencies and return the value that
      # was found most often in the table.
      weights.map{|k,v| [v,k]}.sort[-1][1]
    end
  end
end
