class FlameNode
  attr_reader :name, :start, :duration, :children, :library

  def initialize(name, start, duration, library)
    @name = name
    @start = start
    @duration = duration
    @library = library
    @children = []
  end

  def stop
    @start + @duration
  end

  def add(stack, duration)
    # Add a nil element at the end, or else siblings with the same name, separated by a gap, will be merged into each other
    add_helper(stack + [nil], duration)
  end

  def self.from_samples(samples, &time_normalizer)
    root = FlameNode.new('<root>', 0, 0, nil)
    samples.each do |sample|
      sample_duration = block_given? ? time_normalizer.call(sample.time) : sample.time
      root.add(sample.stack, sample_duration)
    end
    root
  end

  def add_helper(stack, duration)
    @duration += duration
    return if stack.length == 0
    s = stack[0]
    if s.is_a?(Array)
      lib = s[0]
      name = s[1]
    else
      lib = nil
      name = s
    end
    if @children.count == 0 || (@children.last.name != name || @children.last.library != lib)
      @children.append(FlameNode.new(name, @children.last&.stop || @start, 0, lib))
    end
    next_stack = stack.drop(1)
    @children.last.add_helper(next_stack, duration)
  end

  def to_h
    {
      :name => @name,
      :start => @start,
      :duration => @duration,
      :library => @library,
      # Remove nil placeholders
      :children => @children.select { |child| child.name != nil }.map(&:to_h),
    }
  end
end