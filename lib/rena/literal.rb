#
# Copyright (c) 2004 Masahiro Sakai <sakai@tom.sfc.keio.ac.jp>
# You can redistribute it and/or modify it under the same term as Ruby.
#

module Rena


class Literal
  def initialize(str)
    @str = str
    @str.freeze
  end

  def to_s
    @str
  end
  alias to_str to_s

  def nt
    '"' + NTriples.escape(@str) + '"'
  end
end # class Literal


class PlainLiteral < Literal
  def initialize(str, lang = nil)
    super(str)
    @lang = lang
    @lang.freeze
  end
  attr_reader :lang

  def ==(other)
    PlainLiteral === other and
      to_s == other.to_s and
      @lang == other.lang
  end

  def hash
    to_s.hash
  end
  def eql?(other)
    PlainLiteral === other and
      to_s.eql?(other.to_s) and
      @lang.eql?(other.lang)
  end

  def inspect
    nt
  end

  def nt
    s = super
    s << "@" + @lang if @lang 
    s
  end
end # class PlainLiteral



class TypedLiteral < Literal
  def initialize(str, type)
    super(str)
    @type = type
    @type.freeze
  end
  attr_reader :type

  def ==(other)
    TypedLiteral === other and
      to_s == other.to_s and
      @type == other.type
  end

  def hash
    to_s.hash
  end
  def eql?(other)
    TypedLiteral === other and
      to_s.eql?(other.to_s) and
      @type.eql?(other.type)
  end

  def inspect
    nt
  end

  def nt
    s = super
    s << "^^<" + @type.to_s + ">" if @type
    s
  end
end # class TypedLiteral


end # module Rena
