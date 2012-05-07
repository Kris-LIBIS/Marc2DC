# coding: utf-8

class DcElement

  attr_accessor :parts
  attr_accessor :prefix
  attr_accessor :join
  attr_accessor :postfix

  def initialize(*parts)
    @parts = []
    self[*parts]
  end

  def [](*parts)
    options = parts.last.is_a?(Hash) ? parts.pop : {}
    parts.each {|x| add x}
    x = options.delete(:parts)
    add x if x
    if options[:fix]
      if options[:fix].size == 2
        @prefix, @postfix = options[:fix].split('')
      else
        @prefix, @postfix = options[:fix].split('|')
      end
    end
    @join = options[:join] if options[:join]
    @prefix = options[:prefix] if options[:prefix]
    @postfix = options[:postfix] if options[:postfix]
  end

  def self.from(*h)
    DcElement.new(*h)
  end

  def to_s
    @parts.compact!
    result = @parts.join(@join)
    unless result.empty?
      result = (@prefix || '') + result + (@postfix || '')
    end
    result
  end

  def add(part)
    case part
      when Hash
        @parts << DcElement::from(part)
      when Array
        part.each { |x| add x }
      else
        @parts << part
    end
  end

end