module Rena


class Literal
  def initialize(str)
    @str = str
  end

  def to_s
    @str
  end
  alias to_str to_s
end


class PlainLiteral < Literal
  def initialize(str, lang = nil)
    super(str)
    @lang = lang
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
    s = to_s.inspect # FIXME
    s << "@" + @lang if @lang 
    s
  end
end


class TypedLiteral < Literal
  def initialize(str, type)
    super(str)
    @type = type
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
    s = to_s.inspect
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

  def load(filename, params)
    case params[:type]
    when 'text/ntriples'
      reader = NTReader.new
    #when 'application/rdf+xml', 'text/xml', 'application/xml'
    else
      reader = XMLReader.new
    end
    reader.model = self
    open(filename, 'rb'){|f|
      reader.read(f, params)
    }
    nil
  end

=begin
  def save(filename, params)
    case params[:type]
    when 'text/ntriples'
      writer = NTWriter.new
    #when 'application/rdf+xml', 'text/xml', 'application/xml'
    else
      writer = XMLWriter.new
    end
    open(filename, 'wb'){|f|
      writer.write(f, self, params)
    }
    nil
  end
=end

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
