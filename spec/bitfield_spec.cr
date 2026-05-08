require "./spec_helper"

enum MyEnum
  A
  B = 3
  C = 2
  D = 4
end

class Test8 < BitField(UInt8)
  enumeration enum_field, MyEnum
  bool bool
  num four, 4
end

class Test32 < BitField(UInt32)
  num rest, 28
  bool four
  bool three
  bool two
  bool one
end

class TestTooFew < BitField(UInt16)
  num too_few, 15
end

class TestTooMany < BitField(UInt16)
  num too_many, 17
end

class TestMethods < BitField(UInt8)
  num bits, 8

  def double_bits : Nil
    self.bits <<= 1
  end
end

class TestReadOnly < BitField(UInt8)
  num extra, 2
  num read_only_num, 2, read_only: true
  num num, 2
  bool read_only_bool, read_only: true
  bool bool
end

class TestWriteOnly < BitField(UInt8)
  num extra, 2
  num write_only_num, 2, write_only: true
  num num, 2
  bool write_only_bool, write_only: true
  bool bool
end

describe BitField do
  it "gets whole value" do
    bf = Test8.new 0xAF
    bf.value.should eq 0xAF
  end

  it "sets whole value" do
    bf = Test8.new 0xAF
    bf.value = 0xFA
    bf.value.should eq 0xFA
  end

  it "gets upper four" do
    bf = Test8.new 0x9C
    bf.four.should eq 0x9
    bf.value.should eq 0x9C
  end

  it "sets upper four" do
    bf = Test8.new 0x9C
    bf.four = 0x5
    bf.four.should eq 0x5
    bf.value.should eq 0x5C
  end

  it "gets bool" do
    bf = Test8.new 0xF7
    bf.bool.should eq false
    bf.value.should eq 0xF7
  end

  it "sets bool" do
    bf = Test8.new 0xF7
    bf.bool = true
    bf.bool.should eq true
    bf.value.should eq 0xFF
  end

  it "gets enum" do
    bf = Test8.new 0x0F
    bf.enum_field.should eq MyEnum.new(0x7)
    bf.value.should eq 0x0F
  end

  it "sets enum" do
    bf = Test8.new 0x0F
    bf.enum_field = MyEnum::B
    bf.enum_field.should eq MyEnum::B
    bf.value.should eq 0x0B
  end

  it "works on u32" do
    bf = Test32.new 0x5F0000F5
    bf.one.should eq false
    bf.two.should eq true
    bf.three.should eq false
    bf.four.should eq true
    bf.rest.should eq 0xF0000F5
    bf.value.should eq 0x5F0000F5
  end

  it "raises exception on too few" do
    expect_raises(Exception, "You must describe exactly 16 bits (15 bits have been described)") do
      bf = TestTooFew.new 0x0000
    end
  end

  it "raises exception on too many" do
    expect_raises(Exception, "You must describe exactly 16 bits (17 bits have been described)") do
      bf = TestTooMany.new 0x0000
    end
  end

  it "allows new method definitions" do
    bf = TestMethods.new 0b00000001
    bf.double_bits
    bf.bits.should eq 0b00000010
  end

  it "defines equals" do
    bf = Test8.new(0xAF)
    bf.should eq Test8.new(0xAF)
    Test8.new(0xAF).should eq Test8.new(0xAF)
    bf.should_not eq Test8.new(0xFA)
    Test8.new(0xAF).should_not eq Test8.new(0xFA)
  end

  it "defines hash" do
    bf = Test8.new(0xAF)
    bf.hash.should eq Test8.new(0xAF).hash
    Test8.new(0xAF).hash.should eq Test8.new(0xAF).hash
    bf.hash.should_not eq Test8.new(0xFA).hash
    Test8.new(0xAF).hash.should_not eq Test8.new(0xFA).hash
  end

  it "allows read-only values" do
    bf = TestReadOnly.new 0b00000000
    bf.value.should eq 0b00000000
    bf.value = 0xFF
    bf.value.should eq 0b10110011
    bf.read_only_num = 0b01
    bf.value.should eq 0b10110111
    bf.read_only_bool = true
    bf.value.should eq 0b11110111
    bf.value = 0
    bf.value.should eq 0b01000100
  end

  it "allows write-only values" do
    bf = TestWriteOnly.new 0b00000000
    bf.value.should eq 0b00000000
    bf.value = 0xFF
    bf.value.should eq 0b10110011
    bf.write_only_num.should eq 0b11
    bf.write_only_bool.should eq true
    bf.write_only_num = 0b01
    bf.value.should eq 0b10110011
    bf.write_only_num.should eq 0b01
    bf.write_only_bool.should eq true
    bf.write_only_bool = false
    bf.value.should eq 0b10110011
    bf.write_only_num.should eq 0b01
    bf.write_only_bool.should eq false
    bf.value = 0
    bf.value.should eq 0b00000000
    bf.write_only_num.should eq 0b00
    bf.write_only_bool.should eq false
  end

  it "defines to_s" do
    Test8.new(0xAB).to_s.should eq "Test8(0xAB; enum_field: B, bool: true, four: 10)"
    Test32.new(0x5F0000F5).to_s.should eq "Test32(0x5F0000F5; rest: 251658485, four: true, three: false, two: true, one: false)"
  end

  it "works on large u64 bitfields with 32-bit and larger fields" do
    bf = Test64.new(0_u64)
    bf.first_32 = 0x12345678_u64
    bf.rest_32 = 0xABCDEF01_u64
    bf.first_32.should eq 0x12345678_u64
    bf.rest_32.should eq 0xABCDEF01_u64
    bf.value.should eq 0xABCDEF0112345678_u64
  end
end

class Test64 < BitField(UInt64)
  num first_32, 32
  num rest_32, 32
end
