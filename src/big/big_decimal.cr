require "big_int"

# A `BigDecimal` represents arbitrary precision decimals.
#
# It is internally represented by a pair of `BigInt` and `UInt64`: value and scale.
# Value contains the actual value, and scale tells the decimal point place.
# e.g. value=1234, scale=2 => 12.34
#
# The general idea and some of the arithmetic algorithms were adapted from
# the MIT/APACHE -licensed https://github.com/akubera/bigdecimal-rs

class InvalidBigDecimalException < Exception
end

struct BigDecimal
  ZERO                       = BigInt.new(0)
  TEN                        = BigInt.new(10)
  DEFAULT_MAX_DIV_ITERATIONS = 100_u64

  include Comparable(Number)
  include Comparable(BigDecimal)

  private property value : BigInt
  private property scale : UInt64
  getter value, scale

  # Creates a new `BigDecimal` from a `String`.
  #
  # Allows only valid number strings with an optional negative sign.
  def initialize(str : String)
    # disallow every non-valid string
    if str !~ /^-?[0-9]+(\.[0-9]+)?$/
      raise InvalidBigDecimalException.new("Invalid BigDecimal: #{str}")
    end

    if str.includes?('.')
      v1, v2 = str.split('.')
      @value = "#{v1}#{v2}".to_big_i
      @scale = v2.size.to_u64
    else
      @value = str.to_big_i
      @scale = 0_u64
    end
  end

  # Creates an new `BigDecimal` from `Int`.
  def initialize(num : Int)
    initialize(num.to_big_i, 0)
  end

  # Creating a `BigDecimal` from `Float` is not supported due to precision loss risks. This call fails at compile time.
  def initialize(num : Float)
    {% raise "Initializing from Float is risky due to loss of precision -- use Int, String or BigRational" %}
    initialize num.to_s # to appease the compiler
  end

  # Creates a new `BigDecimal` from `BigInt`/`UInt64`, which matches the internal representation
  def initialize(@value : BigInt, @scale : UInt64)
  end

  def initialize(value : Int, scale : Int)
    initialize(value.to_big_i, scale.to_u64)
  end

  def initialize(value : BigInt)
    initialize(value, 0u64)
  end

  def initialize
    initialize(0)
  end

  # Returns *num*. Useful for generic code that does `T.new(...)` with `T`
  # being a `Number`.
  def self.new(num : BigDecimal)
    num
  end

  def +(other : BigDecimal) : BigDecimal
    if @scale > other.scale
      scaled = other.scale_to(self)
      BigDecimal.new(@value + scaled.value, @scale)
    elsif @scale < other.scale
      scaled = scale_to(other)
      BigDecimal.new(scaled.value + other.value, other.scale)
    else
      BigDecimal.new(@value + other.value, @scale)
    end
  end

  def -(other : BigDecimal) : BigDecimal
    if @scale > other.scale
      scaled = other.scale_to(self)
      BigDecimal.new(@value - scaled.value, @scale)
    elsif @scale < other.scale
      scaled = scale_to(other)
      BigDecimal.new(scaled.value - other.value, other.scale)
    else
      BigDecimal.new(@value - other.value, @scale)
    end
  end

  def *(other : BigDecimal) : BigDecimal
    BigDecimal.new(@value * other.value, @scale + other.scale)
  end

  def /(other : BigDecimal) : BigDecimal
    div other
  end

  # Divides self with another `BigDecimal`, with a optionally configurable max_div_iterations, which
  # defines a maximum number of iterations in case the division is not exact.
  #
  # ```
  # BigDecimal(1).div(BigDecimal(2)) => BigDecimal(@value=5, @scale=2)
  # BigDecimal(1).div(BigDecimal(3), 5) => BigDecimal(@value=33333, @scale=5)
  # ```
  def div(other : BigDecimal, max_div_iterations = DEFAULT_MAX_DIV_ITERATIONS) : BigDecimal
    check_division_by_zero other

    scale = @scale - other.scale
    numerator, denominator = @value, other.@value

    quotient, remainder = numerator.divmod(denominator)
    if remainder == ZERO
      return BigDecimal.new(normalize_quotient(other, quotient), scale)
    end

    remainder = remainder * TEN

    i = 0
    while remainder != ZERO && i < max_div_iterations
      inner_quotient, inner_remainder = remainder.divmod(denominator)
      quotient = quotient * TEN + inner_quotient
      remainder = inner_remainder * TEN
      i += 1
    end

    BigDecimal.new(normalize_quotient(other, quotient), scale + i)
  end

  def <=>(other : BigDecimal) : Int32
    if @scale > other.scale
      @value <=> other.scale_to(self).value
    elsif @scale < other.scale
      scale_to(other).value <=> other.value
    else
      @value <=> other.value
    end
  end

  def <=>(other : Int)
    @value <=> other
  end

  def ==(other : BigDecimal) : Bool
    if @scale > other.scale
      scaled = other.value * power_ten_to(@scale - other.scale)
      @value == scaled
    elsif @scale < other.scale
      scaled = @value * power_ten_to(other.scale - @scale)
      scaled == other.value
    else
      @value == other.value
    end
  end

  # Scales a `BigDecimal` to another `BigDecimal`, so they can be
  # computed easier.
  def scale_to(new_scale : BigDecimal) : BigDecimal
    new_scale = new_scale.scale

    if @value == 0
      BigDecimal.new(0.to_big_i, new_scale)
    elsif @scale > new_scale
      scale_diff = @scale - new_scale.to_big_i
      BigDecimal.new(@value / power_ten_to(scale_diff), new_scale)
    elsif @scale < new_scale
      scale_diff = new_scale - @scale.to_big_i
      BigDecimal.new(@value * power_ten_to(scale_diff), new_scale)
    else
      self
    end
  end

  def to_s(io : IO)
    s = @value.to_s

    if @scale == 0
      io << s
      return
    end

    if @scale == s.size
      io << "0." << s
    elsif @scale > s.size
      io << "0."
      (@scale - s.size).times do
        io << '0'
      end
      io << s
    else
      offset = s.size - @scale
      io << s[0...offset] << '.' << s[offset..-1]
    end
  end

  def to_big_d
    self
  end

  def clone
    self
  end

  private def check_division_by_zero(bd : BigDecimal)
    raise DivisionByZero.new if bd.value == 0
  end

  private def power_ten_to(x : Int) : Int
    TEN ** x
  end

  # Returns the quotient as absolutely negative if self and other have different signs,
  # otherwise returns the quotient.
  private def normalize_quotient(other : BigDecimal, quotient : BigInt) : BigInt
    if (@value < 0 && other.value > 0) || (other.value < 0 && @value > 0)
      -quotient.abs
    else
      quotient
    end
  end
end

struct Int
  include Comparable(BigDecimal)

  # Convert `Int` to `BigDecimal`
  def to_big_d
    BigDecimal.new(self)
  end

  def <=>(other : BigDecimal)
    self <=> other.value
  end
end

class String
  include Comparable(BigDecimal)

  # Convert `String` to `BigDecimal`
  def to_big_d
    BigDecimal.new(self)
  end
end

struct Float
  # Casting from `Float` is not supported due to precision loss risks. This call fails at compile time.
  def to_big_d
    {% raise "Initializing from Float is risky due to loss of precision -- convert rather from Int or String" %}
  end
end
