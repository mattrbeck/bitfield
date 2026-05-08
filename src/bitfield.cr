abstract class BitField(T)
  def inspect(io : IO) : Nil
    to_s io
  end

  macro inherited
    {% raise "Cannot create a BitField from a non-integer" unless T <= Int %}

    FIELDS = [] of Tuple(String, Crystal::Macros::Path, Int32, Bool, Bool) # name, type, size, read_only, write_only (types don't actually matter here..)

    macro finished
      build_methods
      def_to_s

      def initialize(@value : T)
        bits = sizeof(T) * 8
        raise "You must describe exactly #{bits} bits (#{SIZE} bits have been described)" unless SIZE == bits
      end

      def_equals_and_hash @value
    end
  end

  macro num(name, size, read_only = false, write_only = false)
    add_field({{name}}, T, {{size}}, {{read_only}}, {{write_only}})
  end

  macro bool(name, read_only = false, write_only = false)
    add_field({{name}}, Bool, 1, {{read_only}}, {{write_only}})
  end

  macro enumeration(name, type, read_only = false, write_only = false)
    {%
      resolved_type = type.resolve
      max_enum_value = 0
      resolved_type.constants.each do |constant|
        constant_value = resolved_type.constant(constant)
        max_enum_value = constant_value if constant_value > max_enum_value
      end
      necessary_bits = 0
      val = 1
      buf = [nil] of NilLiteral # this is a hack to get around the lack of loops in macros
      buf.each do
        if val <= max_enum_value
          necessary_bits += 1
          val *= 2
          buf << nil
        end
      end
    %}
    add_field({{name}}, {{type}}, {{necessary_bits}}, {{read_only}}, {{write_only}})
  end

  # Exists as a general way to add fields to the FIELDS list. Guarantees that
  # the correct number of parameters are passed, at least.
  macro add_field(name, type, size, read_only, write_only)
    {% raise "Cannot mark a field as both read_only and write_only" if read_only && write_only %}
    {% FIELDS << {name, type, size, read_only, write_only} %}
  end

  macro build_methods
    {% pos = 0 %}
    {% read_only_mask = 0 %}
    {% write_only_mask = 0 %}

    {% for field in FIELDS %}
      {%
        name = field[0].id
        type = field[1]
        resolved_type = type.resolve
        size = field[2]
        read_only = field[3]
        write_only = field[4]

        if read_only
          (0...size).each do |i|
            read_only_mask = read_only_mask | 1 << (pos + i)
          end
        end

        if write_only
          (0...size).each do |i|
            write_only_mask = write_only_mask | 1 << (pos + i)
          end
        end
      %}

      def {{name}} : {{type}}
        val = get_val(@value, {{size}}, {{pos}})
        {% if resolved_type == Bool %}
          val > 0
        {% elsif resolved_type <= Enum %}
          {{type}}.new(val)
        {% end %}
      end

      def {{name}}=(val : {{type}}) : Nil
        {% if resolved_type == Bool %}
          val = val ? 1 : 0
        {% elsif resolved_type <= Enum %}
          val = val.value
        {% end %}
        set_val(@value, val, {{size}}, {{pos}})
      end

      {% pos += size %}
    {% end %}

    SIZE = {{pos}}

    def value : T
      @value & ~T.new({{write_only_mask}})
    end

    def value=(value : T)
      @value = (@value & T.new({{read_only_mask}})) | (value & ~T.new({{read_only_mask}}))
    end
  end

  macro def_to_s
    def to_s(io : IO) : Nil
      io << self.class
      io << "("
      io << "0x"
      io << @value.to_s(16).rjust(sizeof(T) * 2, '0').upcase
      io << "; "
      {% for field, idx in FIELDS %}
        {% name = field[0].id %}
        io << "{{name}}: "
        io << self.{{name}}
        {% if idx < FIELDS.size - 1 %}
          io << ", "
        {% end %}
      {% end %}
      io << ")"
    end
  end

  macro get_val(src, size, start)
    ({{src}} >> {{start}} & mask({{size}}))
  end

  macro set_val(dst, src, size, start)
    ({{dst}} = {{dst}} & ~shifted_mask({{size}}, {{start}}) | (T.new({{src}}) & mask({{size}})) << {{start}})
  end

  macro mask(size)
    (~T.new(0) >> (sizeof(T) * 8 - {{size}}))
  end

  macro shifted_mask(size, start)
    (mask({{size}}) << {{start}})
  end
end
