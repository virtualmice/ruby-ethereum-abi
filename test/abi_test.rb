# Had some trouble with encoding (from ASCII-8BIT to UTF-8) 象形字

require 'test_helper'

class ABIFixtureTest < Minitest::Test
  include Ethereum::ABI
  include Ethereum::Utils

  run_fixtures "ABITests"

  def on_fixture_test(name, data)
    run_abi_test data, :verify
  end

  def run_abi_test(params, mode)
    types, args = params['types'], params['args']
    outputs = encode types, args

    assert_equal args, decode(types, outputs)

    case mode
    when :fill
      params['result'] = encode_hex(outputs)
    when :verify
      assert_equal params['result'], encode_hex(outputs)
    when :time
      t1 = Time.now
      encode types, args
      t2 = Time.now
      decode types, outputs
      {encoding: t2-t1, decoding: Time.now-t2}
    else
      raise "invalid mode: #{mode}"
    end
  end
end

class ABITest < Minitest::Test
  include Ethereum::ABI
  include Ethereum::Utils

  def test_use_abi_class_methods
    assert_equal encode(['int256'], [1]), Ethereum::ABI.encode(['int256'], [1])
  end

  def test_abi_encode_var_sized_array
    bytes = "\x00" * 32 * 3
    assert_equal "#{zpad_int(32)}#{zpad_int(3)}#{bytes}", encode(['address[]'], [["\x00" * 20]*3])
  end

  def test_abi_encode_fixed_sized_array
    assert_equal "#{zpad_int(5)}#{zpad_int(6)}", encode(['uint16[2]'], [[5,6]])
  end

  def test_abi_encode_signed_int
    assert_equal 1,  decode(['int8'], encode(['int8'], [1]))[0]
    assert_equal -1, decode(['int8'], encode(['int8'], [-1]))[0]
  end

  def test_abi_encode_primitive_type
    type = Type.parse 'bool'
    assert_equal zpad_int(1), encode_primitive_type(type, true)
    assert_equal zpad_int(0), encode_primitive_type(type, false)

    type = Type.parse 'uint8'
    assert_equal zpad_int(255), encode_primitive_type(type, 255)
    assert_raises(ValueOutOfBounds) { encode_primitive_type(type, 256) }

    type = Type.parse 'int8'
    assert_equal zpad("\x80", 32), encode_primitive_type(type, -128)
    assert_equal zpad("\x7f", 32), encode_primitive_type(type, 127)
    assert_raises(ValueOutOfBounds) { encode_primitive_type(type, -129) }
    assert_raises(ValueOutOfBounds) { encode_primitive_type(type, 128) }

    type = Type.parse 'ureal128x128'
    assert_equal ("\x00"*32), encode_primitive_type(type, 0)
    assert_equal ("\x00"*15 + "\x01\x20" + "\x00"*15), encode_primitive_type(type, 1.125)
    assert_equal ("\x7f" + "\xff"*15 + "\x00"*16), encode_primitive_type(type, 2**127-1)

    type = Type.parse 'real128x128'
    assert_equal ("\xff"*16 + "\x00"*16), encode_primitive_type(type, -1)
    assert_equal ("\x80" + "\x00"*31), encode_primitive_type(type, -2**127)
    assert_equal ("\x7f" + "\xff"*15 + "\x00"*16), encode_primitive_type(type, 2**127-1)
    assert_equal "#{zpad_int(1, 16)}\x20#{"\x00"*15}", encode_primitive_type(type, 1.125)
    assert_equal "#{"\xff"*15}\xfe\xe0#{"\x00"*15}", encode_primitive_type(type, -1.125)
    assert_raises(ValueOutOfBounds) { encode_primitive_type(type, -2**127 - 1) }
    assert_raises(ValueOutOfBounds) { encode_primitive_type(type, 2**127) }

    type = Type.parse 'bytes'
    assert_equal "#{zpad_int(3)}\x01\x02\x03#{"\x00"*29}", encode_primitive_type(type, "\x01\x02\x03")

    type = Type.parse 'bytes8'
    assert_equal "\x01\x02\x03#{"\x00"*29}", encode_primitive_type(type, "\x01\x02\x03")

    type = Type.parse 'hash32'
    assert_equal ("\xff"*32), encode_primitive_type(type, "\xff"*32)
    assert_equal ("\xff"*32), encode_primitive_type(type, "ff"*32)

    type = Type.parse 'address'
    assert_equal zpad("\xff"*20, 32), encode_primitive_type(type, "\xff"*20)
    assert_equal zpad("\xff"*20, 32), encode_primitive_type(type, "ff"*20)
    assert_equal zpad("\xff"*20, 32), encode_primitive_type(type, "0x"+"ff"*20)
  end

  def test_abi_decode_primitive_type
    type = Type.parse 'address'
    assert_equal 'ff'*20, decode_primitive_type(type, encode_primitive_type(type, "0x"+"ff"*20))

    type = Type.parse 'bytes'
    assert_equal "\x01\x02\x03", decode_primitive_type(type, encode_primitive_type(type, "\x01\x02\x03"))

    type = Type.parse 'bytes8'
    assert_equal ("\x01\x02\x03"+"\x00"*5), decode_primitive_type(type, encode_primitive_type(type, "\x01\x02\x03"))

    type = Type.parse 'hash20'
    assert_equal ("\xff"*20), decode_primitive_type(type, encode_primitive_type(type, "ff"*20))

    type = Type.parse 'uint8'
    assert_equal 0, decode_primitive_type(type, encode_primitive_type(type, 0))
    assert_equal 255, decode_primitive_type(type, encode_primitive_type(type, 255))

    type = Type.parse 'int8'
    assert_equal -128, decode_primitive_type(type, encode_primitive_type(type, -128))
    assert_equal 127, decode_primitive_type(type, encode_primitive_type(type, 127))

    type = Type.parse 'ureal128x128'
    assert_equal 0, decode_primitive_type(type, encode_primitive_type(type, 0))
    assert_equal 125.125, decode_primitive_type(type, encode_primitive_type(type, 125.125))
    assert_equal (2**128-1).to_f, decode_primitive_type(type, encode_primitive_type(type, 2**128-1))

    type = Type.parse 'real128x128'
    assert_equal 1, decode_primitive_type(type, encode_primitive_type(type, 1))
    assert_equal -1, decode_primitive_type(type, encode_primitive_type(type, -1))
    assert_equal 125.125, decode_primitive_type(type, encode_primitive_type(type, 125.125))
    assert_equal -125.125, decode_primitive_type(type, encode_primitive_type(type, -125.125))
    assert_equal (2**127-1).to_f, decode_primitive_type(type, encode_primitive_type(type, 2**127-1))
    assert_equal -2**127, decode_primitive_type(type, encode_primitive_type(type, -2**127))

    type = Type.parse 'bool'
    assert_equal true, decode_primitive_type(type, encode_primitive_type(type, true))
    assert_equal false, decode_primitive_type(type, encode_primitive_type(type, false))
  end
end
