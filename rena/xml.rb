# -*- coding: utf-8 -*-
require 'rexml/document'
require 'rena/rdf'

module Rena

class XMLReader
  def initialize
    @model = nil
    @blank_nodes = {}
  end
  attr_accessor :model

  def read(input, base = URI.parse(""))
    doc = REXML::Document.new(input)
    read_from_xml_document(doc, base)
  end

  def read_from_xml_document(doc, base = URI.parse(""))
    root = doc.root
    unless root.is_a? REXML::Element
      # FIXME
      #raise ArgumentError
    else
      if root.namespace == RDF::Namespace and root.name == "RDF"
	parse_rdf(root, base)
      else
	parse_resource(root, base)
      end
    end
  end

  private

  def update_base(old_base, e)
    if v = e.attributes["xml:base"]
      base = old_base + v
      # xmlbase/test013.rdf
      # With an xml:base with fragment the fragment is ignored.
      base.fragment = nil
      base
    else
      old_base
    end
  end

  def update_lang(old_lang, e)
    if v = e.attributes["xml:lang"]
      if v.empty?
	nil
      else
	v
      end
    else
      old_lang
    end
  end

  XMLLiteral_DATATYPE_URI =
    URI.parse("http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")

  def parse_rdf(rdf, base, lang = nil)
    base = update_base(base, rdf)
    lang = update_lang(lang, rdf)

    rdf.elements.each{|e|
      parse_resource(e, base)
    }
  end

  def parse_resource(e, base, lang = nil)
    base = update_base(base, e)
    lang = update_lang(lang, e)

    if about = e.attribute("about", RDF::Namespace)
      subject = @model.create_resource(base + about.value)
    elsif id = e.attribute("ID", RDF::Namespace)
      subject = @model.create_resource(base + ("#" + id.value))
    elsif nodeID = e.attribute("nodeID", RDF::Namespace)
      subject = lookup_nodeID(nodeID.value)
    else
      subject = @model.create_resource
    end

    unless e.namespace == RDF::Namespace and e.name == "Description"
      subject.add_property(RDF::Type,
			   @model.create_resource(URI.parse(e.namespace + e.name)))
    end

    e.attributes.each_attribute{|attr|
      if predicate = attr_as_predicate(e, attr)
	# FIXMR
	if predicate == RDF::Type
	  object = @model.create_resource(URI.parse(attr.value))
	else
	  object = PlainLiteral.new(attr.value, lang)
	end
	subject.add_property(predicate, object)
      end
    }

    parse_predicates(subject, e.elements, base, lang)

    subject
  end

  def parse_predicates(subject, elements, base, lang)
    i = 0

    elements.each{|e|
      new_base = update_base(base, e)
      new_lang = update_lang(lang, e)

      if e.namespace==RDF::Namespace and e.name == "li"
  	predicate = URI.parse(RDF::Namespace + "_#{i+=1}")
      else
  	predicate = URI.parse(e.namespace + e.name)
      end
  
      if resource = e.attribute("resource", RDF::Namespace)
  	object = @model.create_resource(base + resource.value)
      elsif nodeID = e.attribute("nodeID", RDF::Namespace)
  	object = lookup_nodeID(nodeID.value)
      elsif parseType = e.attribute("parseType", RDF::Namespace)
  	case parseType.value
  	when "Resource"
  	  object = @model.create_resource
  	  parse_predicates(object, e.elements, new_base, new_lang)
  	when "Collection"
	  items = e.elements.map{|e2| parse_resource(e2, new_base) }
	  object = items.reverse.inject(@model.create_resource(RDF::Nil)){|result,item|
	    @model.create_resource.
	      add_property(RDF::First, item).
	      add_property(RDF::Rest, result)
	  }
	when "Literal"
	  s = ''
	  e.children.each{|child| child.write(s) }
	  object = TypedLiteral.new(s, XMLLiteral_DATATYPE_URI)
  	else
  	  raise RuntimeError.new
  	end
      else
	if e.elements.size == 1
  	  object = parse_resource(e.elements[1], new_base)
	elsif e.elements.size == 0
	  # FIXME
	  if e.children.any?{|child|
	      child.is_a?(REXML::Text) and /\A\s*\Z/ !~ child.value
	    }
	    flag_blank = false
	  else
	    flag_blank = false
	    e.attributes.each_attribute{|attr|
	      if attr_as_predicate(e, attr)
		flag_blank = true
		break
	      end
	    }
	  end

	  if flag_blank
	    object = @model.create_resource
	  else
	    s = e.children.map{|child|
	      child.is_a?(REXML::Text) ? child.value : ""
	    }.join("")

	    if attr_type = e.attribute("datatype", RDF::Namespace)
	      object = TypedLiteral.new(s, new_base + attr_type.value)
	    else
	      object = PlainLiteral.new(s, new_lang)
	    end
	  end
  	else
  	  raise RuntimeError.new
  	end
      end

      subject.add_property(predicate, object)

      if id = e.attribute("ID", RDF::Namespace)
	@model.create_resource(new_base + ("#" + id.value)).
	  add_property(RDF::Type, @model.create_resource(RDF::Statement)).
	  add_property(RDF::Subject, subject).
	  add_property(RDF::Predicate, @model.create_resource(predicate)).
	  add_property(RDF::Object, object)
      end

      #if object.is_a?(URI) or object.is_a?(BlankNode)
      unless object.is_a?(Rena::Literal)
	e.attributes.each_attribute{|attr|
	  if predicate2 = attr_as_predicate(e, attr)
	    subject2 = object
	    # FIXMR
	    if predicate == RDF::Type
	      object2 = @model.create_resource(URI.parse(attr.value))
	    else
	      object2 = PlainLiteral.new(attr.value, new_lang)
	    end
	    subject2.add_property(predicate2, object2)
	  end
	}
      end
    }
  end

  private
  def lookup_nodeID(nodeID)
    @blank_nodes[nodeID] ||= @model.create_resource
  end

  RDF_SyntaxNames = ['RDF', 'Description', 'ID', 'about', 'parseType', 'resource', 'li', 'nodeID', 'datatype']

  def attr_as_predicate(e, attr)
    # FIXME
    if attr.prefix=='' and attr.local_name=="xmlns"
      nil
    elsif (ns = e.namespace(attr.prefix)) and
	(ns != RDF::Namespace or
	 not RDF_SyntaxNames.member?(attr.local_name))
      URI.parse(ns + attr.local_name)
    else
      nil
    end
  end

end # class XMLReader




class XMLWriter
  def initialize
    @namespaces = Hash.new
    @namespaces["rdf"] = RDF::Namespace
    @ns_counter = 0

    @written = Set[]
    @blank_nodes_to_element = Hash.new
    @blank_counter = 0

    @root = nil
  end
  attr_reader :namespaces

  def have_property?(resource)
    resource.each_property{ return true }
    false
  end

  def write_top_resources(rdf)
    first = true

    parent = rdf
    @model.each_resource{|resource|
      if first
	first = false
	parent << REXML::Text.new("\n")
      end

      if have_property?(resource) and not @written.member?(resource)
	write_resource(parent, resource)
      end
    }
  end

  def write_resource(parent, resource)
    type  = nil
    ename = nil
    resource[RDF::Type].each{|t|
      begin
	ename = fold_uri(t.uri)
	type  = t
	true
      rescue
	false
      end
    }
    
    ename = fold_uri(RDF::Namespace + "Description") unless type
    e = REXML::Element.new(ename)
 
    parent << REXML::Text.new("\n")
    parent << e
    parent << REXML::Text.new("\n")
    if resource.uri
      e.add_attribute(fold_uri(RDF::Namespace + "about"), resource.uri.to_s)
    else
      @blank_nodes_to_element[resource] = e
    end

    unless @written.member?(resource)
      @written << resource
      write_predicates(e, resource, type)
    end

    e
  end

  def write_predicates(parent, resource, type = nil)
    first = true

    resource.each_property{|prop, object|
      next if prop == RDF::Type and object == type

      ename = fold_uri(prop)
      #ename = "rdf:li" if /rdf:_\d+/ =~ ename

      if first
	first = false
	parent << REXML::Text.new("\n")
      end
	
      e = REXML::Element.new(ename)
      parent << e
      parent << REXML::Text.new("\n")
	  
      if object.is_a?(Rena::Literal)
	e << REXML::Text.new(object.to_s)
      else
	unless @written.member?(object) or !have_property?(object)
	  write_resource(e, object)
	else
	  if object.uri
	    e.add_attribute(fold_uri(RDF::Namespace + "resource"),
			    object.uri.to_s)
	  else
	    e.add_attribute(fold_uri(RDF::Namespace + "nodeID"),
			    blank_node_to_nodeID(object))
	  end
	  @written << object
	end
      end
    }
  end

  def fold_uri(uri)
    uri_s = uri.to_s
    @namespaces.each_pair{|prefix, namespace|
      if /\A#{Regexp.quote(namespace)}(.*)\Z/ =~ uri_s
	if prefix.empty?
	  return $1
	else
	  return prefix + ":" + $1
	end
      end
    }

    uri = uri.dup
    if s = uri.fragment
      uri.fragment = nil
    elsif s = uri.query
      uri = uri.query = nil
    elsif path = uri.path
      %r!\A(.*/)([^/]+)\Z! =~ path
      uri.path = $1
      s = $2
    else
      # FIXME
      raise RuntimeError.new("FIXME: no namespace match against #{uri}")
    end

    loop {
      prefix = "ns" + @ns_counter.to_s
      @ns_counter = @ns_counter.succ
      unless @namespaces.has_key?(prefix)
	uri = uri.to_s.freeze
	@namespaces[prefix] = uri
	@root.add_namespace(prefix, uri)
	return prefix + ":" + s
      end
    }
  end

  def blank_node_to_nodeID(resource)
    e = @blank_nodes_to_element[resource]
    if nodeID = e.attribute("nodeID", RDF::Namespace)
      nodeID.value
    else
      v = "blank" + @blank_counter.to_s
      e.add_attribute(fold_uri(RDF::Namespace + "nodeID"), v)
      @blank_counter = @blank_counter.succ
      v
    end
  end

  def model2rdfxml(m)
    doc = REXML::Document.new()
    doc << REXML::Text.new("\n")

    @root = REXML::Element.new(fold_uri(RDF::Namespace + "RDF"))
    doc << @root

    namespaces.each_pair{|prefix, namespace|
      if prefix.empty?
	@root.add_namespace(namespace)
      else
	@root.add_namespace(prefix, namespace)
      end
    }

    @model = m
    write_top_resources(@root)

    doc
  end
end # class XMLWriter


end # module Rena

