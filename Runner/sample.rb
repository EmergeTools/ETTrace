class Sample
  attr_reader :stack
  attr_accessor :time

  def initialize(time, stack)
    @time = time
    @stack = stack
  end

  def create_copy
    Sample.new(@time, @stack)
  end

  def to_s
    # Print out floats that end in ".0" as ints
    time = @time == @time.to_i ? @time.to_i : @time
    # We can't just use time.to_s, since that may print numbers of the form 1.1e-10, which Flamegraph can't handle
    time_str = ('%.15f' % time).sub(/0*$/, '')
    "#{@stack.map { |s| s.is_a?(Array) ? s[1] : s }.join(';')} #{time_str}"
  end
end
