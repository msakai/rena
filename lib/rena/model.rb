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
    s = @str.dup
    s.gsub!(/\\/, "\\\\")
    s.gsub!(/"/, "\\\"")
    s.gsub!(/\n/, "\\n")
    s.gsub!(/\r/, "\\r")
    s.gsub!(/\t/, "\\t")
    '"' + s + '"'
  end
end


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
end


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
end


class Resource
  def initialize(model, uri = nil)
    @model = model
    @uri = uri
  end
  attr_reader :model
  attr_reader :uri

  def add_property(prop, object)
    raise RuntimeError.new("implement this method")
  end

  def [](prop)
    prop = URI.parse(prop) unless prop.is_a?(URI)

    result = []
    each_property{|predicate, object|
      result << object if prop == predicate
    }
    result
  end

  def each_property
    raise RuntimeError.new("implement this method")
  end
end


class Statement
  attr_reader :subject
  attr_reader :predicate
  attr_reader :object

  def initialize(subject, predicate, object)
    unless subject.is_a?(Rena::Resource)
      raise ArgumentError.new(subject.inspect + " is not Rena::Resource")
    end
    unless predicate.is_a?(URI)
      raise ArgumentError.new(predicate.inspect + " is not URI")
    end
    unless object.is_a?(Rena::Resource) or object.is_a?(Rena::Literal)
      raise ArgumentError.new(object.inspect + " is not Rena::Resource nor Rena::Literal")
    end
    @subject   = subject
    @predicate = predicate
    @object    = object
  end
end # class Statement


class Model

  def load(input, params = {})
    if input.respond_to? :gets
      reader = setup_reader(input, params)
      reader.read(input, params)
    else
      open(input, 'rb'){|f|
        reader = setup_reader(f, params)
        reader.read(f, params)
      }
    end

    nil
  end

  private

  def setup_reader(io, params)
    content_type = params[:content_type]
    # for open-uri
    if content_type.nil? and io.respond_to? :content_type
      content_type ||= io.content_type
    end

    case content_type
    when 'text/ntriples'
      reader = NTriples::Reader.new
    when 'application/rdf+xml', 'text/xml', 'application/xml'
      reader = XML::Reader.new
    else
      raise RuntimeError.new("unsupported content-type: " + content_type.inspect)
    end
    reader.model = self

    reader
  end

  public

  def save(output, params = {})
    content_type = params[:content_type]
    
    case content_type
    when 'text/ntriples'
      writer = NTriples::Writer.new
    when 'application/rdf+xml', 'text/xml', 'application/xml'
      writer = XML::Writer.new
    else
      raise RuntimeError.new("unsupported content-type: " + content_type.inspect)
    end

    if output.respond_to? :puts
      writer.write(output, self, params)
    else
      open(output, 'wb'){|f| writer.write(f, self, params) }
    end

    nil
  end

  def statements
    result = []
    each_statement{|s| result << s }
    result
  end

  def create_resource_impl
    raise RuntimeError.new("implement this method")
  end

  def create_resource(uri = nil, type = nil)
    uri = URI.parse(uri) if uri and not uri.is_a?(URI)
    resource = create_resource_impl(uri)

    if type
      type = URI.parse(type) unless type.is_a?(URI)
      resource.add_property(URI.parse("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
			    create_resource(type))
    end

    resource
  end

  def lookup_resource(uri)
    uri = URI.parse(uri) unless uri.is_a?(URI)
    lookup_resource_impl(uri)
  end

  def lookup_resource_impl(uri)
    raise RuntimeError.new("implement this method")
  end

  def [](uri)
    lookup_resource(uri)
  end

  def each_resource
    raise RuntimeError.new("implement this method")
  end

  def each_statement(&block)
    raise RuntimeError.new("implement this method")
  end

=begin
  def add(statement)
    raise RuntimeError.new("implement this method")
  end

  def <<(statement)
    add(statement)
  end
=end
end


end #module Rena
