# -*- coding: utf-8 -*-
#
# Copyright (c) 2004 Masahiro Sakai <sakai@tom.sfc.keio.ac.jp>
# You can redistribute it and/or modify it under the same term as Ruby.
#

require 'rexml/document'
require 'stringio'
require 'rena/rdf'

module Rena

class XMLReader
  def initialize
    @model = nil
    @blank_nodes = {}
    @used_id = []
  end
  attr_accessor :model

  def read(io, params)
    base = params[:base]
    if base.nil? and io.respond_to?(:base_uri) # for open-uri
      base ||= io.base_uri
    end

    doc = REXML::Document.new(REXML::IOSource.new(io)) # XXX
    read_from_xml_document(doc, base)
    nil
  end

  def read_from_xml_document(doc, base = nil)
    if base.nil?
      base = URI.parse("")
    elsif not base.is_a?(URI)
      base = URI.parse(base)
    end
    parse_doc(doc, base)
    nil
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

  def parse_doc(doc, base = URI.parse(""))
    root = doc.root
    unless root.is_a? REXML::Element
      # FIXME
      #raise ArgumentError
    else
      if root.namespace == RDF::Namespace and root.name == 'RDF'
        parse_rdf(root, base)
      else
        parse_nodeElement(root, base) # XXX
      end
    end
  end

  def parse_rdf(rdf, base, lang = nil)
    if rdf.namespace == RDF::Namespace and rdf.name == "RDF"
      base = update_base(base, rdf)
      lang = update_lang(lang, rdf)
      parse_nodeElementList(rdf.elements, base, lang)
    else
      # XXX
      raise TypeError.new
    end
  end

  def parse_nodeElementList(elements, base, lang)
    elements.each{|e|
      parse_nodeElement(e, base, lang)
    }
  end

  def parse_nodeElement(e, base, lang = nil)
    base = update_base(base, e)
    lang = update_lang(lang, e)

    # FIXME: nodeElementURIs であることをチェック

    id     = get_attribute(e, "ID",     RDF::Namespace)
    nodeID = get_attribute(e, "nodeID", RDF::Namespace)
    about  = get_attribute(e, "about",  RDF::Namespace)

    if [id, nodeID, about].compact.size > 1
      raise RuntimeError.new
    end

    if id
      uri = base + ("#" + id.value)
      if @used_id.member?(uri)
        raise RuntimeError.new("two elements cannot use the same ID")
      else
        @used_id.push uri
      end
      subject = @model.create_resource(uri)
    elsif nodeID
      # FIXME: rdfms-syntax-incomplete/error001.rdf
      subject = lookup_nodeID(nodeID.value)
    elsif about
      subject = @model.create_resource(base + about.value)
    else
      subject = @model.create_resource
    end

    # FIXME
    if e.namespace == RDF::Namespace
      if ["RDF","ID","about","parseType","resource","nodeID","datatype","li","aboutEach","aboutEachPrefix","bagID"].member?(e.local_name)
        raise RuntimeError.new
      end
    end

    unless e.namespace == RDF::Namespace and e.name == "Description"
      uri = URI.parse(e.namespace(e.prefix) + e.name)
      subject.add_property(RDF::Type, @model.create_resource(uri))
    end

    e.attributes.each_attribute{|attr|
      if predicate = parse_propertyAttr(e, attr)
        if predicate == RDF::Type
          subject.add_property(predicate,
                               @model.create_resource(URI.parse(attr.value)))
        else
          subject.add_property(predicate,
                               PlainLiteral.new(attr.value, lang))
        end
      end
    }

    parse_propertyEltList(subject, e.elements, base, lang)

    subject
  end

  def parse_propertyEltList(subject, elements, base, lang)
    li_counter = 0

    elements.each{|e|
      # propertyElt
      new_base = update_base(base, e)
      new_lang = update_lang(lang, e)

      # FIXME
      if e.namespace == RDF::Namespace
        if ["RDF","ID","about","parseType","resource","nodeID","datatype","Description","aboutEach","aboutEachPrefix","bagID"].member?(e.local_name)
          raise RuntimeError.new
        end
      end

      if e.namespace==RDF::Namespace and e.name == "li"
        # List Expansion Rules
        predicate = URI.parse(RDF::Namespace + "_#{li_counter+=1}")
      else
        predicate = URI.parse(e.namespace + e.name)
      end

      parseType = get_attribute(e, "parseType", RDF::Namespace)

      if parseType
        # XXX
        if get_attribute(e, "resource", RDF::Namespace)
          raise RuntimeError.new('specifying an rdf:parseType of "Literal" and an rdf:resource attribute at the same time is an error.')
        end

        case parseType.value
        when "Resource"
          object = parse_parseTypeResourcePropertyElt(e, new_base, new_lang)
        when "Collection"
          object = parse_parseTypeCollectionPropertyElt(e, new_base, new_lang)
        when "Literal"
          object = parse_parseTypeLiteralPropertyElt(e, new_base, new_lang)
        else
          object = parse_parseTypeOtherPropertyElt(e, new_base, new_lang)
        end
      elsif e.elements.size == 1
        object = parse_resourcePropertyElt(e, new_base, new_lang)
      elsif e.children.any?{|c| c.is_a? REXML::Text }
        object = parse_literalPropertyElt(e, new_base, new_lang)
      else
        object = parse_emptyPropertyElt(e, new_base, new_lang)
      end

      subject.add_property(predicate, object)

      if id = get_attribute(e, "ID", RDF::Namespace)
        uri = new_base + ("#" + id.value)

        if @used_id.member?(uri)
          raise RuntimeError.new("two elements cannot use the same ID")
        else
          @used_id.push uri
        end

        @model.create_resource(uri).
          add_property(RDF::Type, @model.create_resource(RDF::Statement)).
          add_property(RDF::Subject, subject).
          add_property(RDF::Predicate, @model.create_resource(predicate)).
          add_property(RDF::Object, object)
      end

      # XXX
      unless object.is_a?(Rena::Literal)
        e.attributes.each_attribute{|attr|
          if predicate2 = parse_propertyAttr(e, attr)
            subject2 = object
            # FIXME
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

  def parse_parseTypeResourcePropertyElt(e, base, lang=nil)
    object = @model.create_resource
    parse_propertyEltList(object, e.elements, base, lang)
    object
  end

  def parse_parseTypeCollectionPropertyElt(e, base, lang=nil)
    items = e.elements.map{|e2| parse_nodeElement(e2, base, lang) }
    items.reverse.inject(@model.create_resource(RDF::Nil)){
      |result, item|
      @model.create_resource.
        add_property(RDF::First, item).
        add_property(RDF::Rest, result)
    }
  end

  def parse_parseTypeLiteralPropertyElt(e, base, lang=nil)
    s = exclusive_xml_canonicalization(e)
    TypedLiteral.new(s, XMLLiteral_DATATYPE_URI)
  end

  def parse_parseTypeOtherPropertyElt(e, base, lang=nil)
    parse_parseTypeLiteralPropertyElt(e, base, lang)
  end

  def parse_resourcePropertyElt(e, base, lang=nil)
    parse_nodeElement(e.elements[1], base, lang)
  end

  def parse_literalPropertyElt(e, base, lang=nil)
    s = e.children.select{|c| c.is_a?(REXML::Text) }.map{|c| c.value }.join('')
    if attr_type = get_attribute(e, "datatype", RDF::Namespace)
      TypedLiteral.new(s, base + attr_type.value)
    else
      PlainLiteral.new(s, lang)
    end
  end

  def parse_emptyPropertyElt(e, base, lang=nil)
    # XXX: If there are no attributes or only the optional rdf:ID attribute i.
    flag = true
    e.attributes.each_attribute{|attr|
      if parse_propertyAttr(e,attr)
        flag = false
        break
      end

      if (ns = e.namespace(attr.prefix)) and
          ns == RDF::Namespace and attr.local_name == 'ID'
        next
      else
        flag = false
        break
      end
    }

    if flag
      PlainLiteral.new('', lang)
    else
      if resource = get_attribute(e, "resource", RDF::Namespace)
        @model.create_resource(base + resource.value)
      elsif nodeID = get_attribute(e, "nodeID", RDF::Namespace)
        # FIXME: rdfms-syntax-incomplete/error001.rdf
        lookup_nodeID(nodeID.value)     
      else
        @model.create_resource
      end
    end
  end

=begin
  CoreSyntaxTerms_local_name = [
    "RDF", "ID", "about", "parseType", "resource", "nodeID", "datatype"
  ]
  SyntaxTerms_local_name = CoreSyntaxTerms_local_name + [
    "Description", "li"
  ]
  OldTerms_local_name = ["aboutEach", "aboutEachPrefix", "bagID"]
=end

  def parse_propertyAttr(e, attr)
    if /^xml/i =~ attr.prefix
      nil
    elsif (attr.name==attr.expanded_name) and /^xml/i =~ attr.local_name # XXX
      nil
    else
      ns = e.namespace(attr.prefix)
      return nil unless ns

      if ns==RDF::Namespace
        if ["aboutEach", "aboutEachPrefix", "bagID"].member?(attr.local_name)
          raise RuntimeError.new("rdf:aboutEach, rdf:aboutEachPrefix and rdf:bagID are obsoleted")
        end

        if ["RDF", "li", "Description"].member?(attr.local_name)
          raise RuntimeError.new
        end

        if ["ID", "about", "parseType", "resource", "nodeID", "datatype"].member?(attr.local_name)
          return nil
        end
      end

      URI.parse(ns + attr.local_name)
    end
  end

  private

  def create_xpath(e)
    parent = e.parent
    if parent.nil?
      ''
    else
      create_xpath(parent) + '/*[' + parent.elements.index(e).to_s + ']'
    end
  end

=begin
  # Exclusive XML Canonicalization
  def exclusive_xml_canonicalization(e)
    # FIXME
    begin
      require 'tempfile'

      xmlfile   = Tempfile.new('rena-xml')
      e.document.write(xmlfile)
      xmlfile.close(false)

      xpathfile = Tempfile.new('rena-xpath')
      xpath = create_xpath(e) + '/descendant::node()'
      xpath = "(//@* | //namespace::* | " + xpath + ")"
      xpathfile.puts("<XPath>", xpath, "</XPath>")
      xpathfile.close(false)

      s = `./testC14N --exc-with-comments #{xmlfile.path.sub(%!/cygdrive/c!,"c:")} #{xpathfile.path.sub(%!/cygdrive/c!,"c:")}` # XXX
      s.gsub!(/\r\n/, "\n")
      s
    rescue
      s = ''
      e.children.each{|child| child.write(s) }
      s
    end
  end
=end

  def exclusive_xml_canonicalization(e)
    io = StringIO.new
    c14n = ExecC14N.new(io)
    c14n.run(e)
    io.string
  end

  def lookup_nodeID(nodeID)
    @blank_nodes[nodeID] ||= @model.create_resource
  end

  # to avoid bugs of REXML::Element.
  def get_attribute(e, name, namespace)
    e.prefixes.each{|prefix|
      if e.namespace(prefix) == namespace
        return e.attributes.get_attribute(prefix + ':' + name)
      end
    }
    nil
  end


  # Exclusive XML Canonicalization
  class ExecC14N
    def initialize(output)
      @output = output
    end

    def run(e)
      e.children.each{|child| do_c14n(child, {}) }
    end

    private

    def do_c14n(node, ns_rendered)
      case node
      when REXML::Comment
        @output.print('<!--', node.string, '-->')
      when REXML::Text
        @output.print(escape_text(node.value))
      when REXML::Element
        do_c14n_element(node, ns_rendered)
      when REXML::Instruction
        @output.print('<?', node.target)
        unless node.content.empty?
          @output.print(' ', node.content)
        end
        @output.print('?>')
      end
    end

    def do_c14n_element(node, ns_rendered)
      ns_table   = []
      attr_table = []
      new_ns_rendered = ns_rendered.dup

      if node.prefix != '' and
          node.namespace(node.prefix) != ns_rendered[node.prefix]
        ns = node.namespace(node.prefix)
        ns_table.push [node.prefix, ns]
        new_ns_rendered[node.prefix] = ns
      end

      node.attributes.each{|attr|
        unless "xmlns"==attr.prefix or "xmlns"==attr.expanded_name
          next
        end

        if attr.prefix != '' and ns_rendered[attr.prefix] != attr.namespace
          ns = node.namespace(attr.prefix)
          ns_table.push [attr.prefix, ns]
          new_ns_rendered[attr.prefix] = ns
        end
        attr_table.push attr
      }
      
      @output.print('<', node.fully_expanded_name)
      
      if node.prefix=='' and
          node.namespace!='' and ns_rendered['']!= node.namespace
        @output.print(' ', 'xmlns', '=', '"',
                      escape_attr_value(node.namespace),
                      '"')
        new_ns_rendered[''] = node.namespace
      end
      
      ns_table = ns_table.sort_by{|(prefix,namespace)| prefix }
      ns_table.each{|(prefix,namespace)|
        @output.print(' ', 'xmlns:', prefix, '=', '"',
                      escape_attr_value(namespace),
                      '"')
      }
      
      attr_table = attr_table.sort_by{|attr|
        [attr.prefix.empty? ? '' : attr.namespace, attr.local_name]
      }
      attr_table.each{|attr|
        @output.print(' ', attr.fully_expanded_name, '=', '"',
                     escape_attr_value(attr.value),
                     '"')
      }
      
      @output.print '>'
      
      node.children.each{|child|
        do_c14n(child, new_ns_rendered)
      }
      
      @output.print('</', node.fully_expanded_name, '>')
    end

    def escape_text(s)
      s = s.dup
      s.gsub!(/&/,  '&amp;')
      s.gsub!(/</,  '&lt;')
      s.gsub!(/>/,  '&gt;')
      s.gsub!(/\r/, '&#xD;')
      s
    end

    def escape_attr_value(s)
      s = s.dup
      s.gsub!(/&/,  '&amp;')
      s.gsub!(/</,  '&lt;')
      s.gsub!(/>/,  '&gt;')
      s.gsub!(/"/,  '&quot;')
      s.gsub!(/\t/, '&#x9;')
      s.gsub!(/\n/, '&#xA;')
      s.gsub!(/\r/, '&#xD;')      
      s
    end
  end # class ExecC14N

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

  private

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
      #ename = "rdf:li" if /rdf:_\d+/u =~ ename

      if first
        first = false
        parent << REXML::Text.new("\n")
      end
        
      e = REXML::Element.new(ename)
      parent << e
      parent << REXML::Text.new("\n")

      if object.is_a?(Rena::Literal)
        if object.is_a?(Rena::PlainLiteral) and object.lang
          e.add_attribute("xml:lang", object.lang.to_s)
        end
        if object.is_a?(Rena::TypedLiteral)
          e.add_attribute(fold_uri(RDF::Namespace + "datatype"),
                          object.type.to_s)
        end
        e << REXML::Text.new(object.to_s, true)
      else
        if @written.member?(object)
          if object.uri
            e.add_attribute(fold_uri(RDF::Namespace + "resource"),
                            object.uri.to_s)
          else
            e.add_attribute(fold_uri(RDF::Namespace + "nodeID"),
                            blank_node_to_nodeID(object))
          end
        else
          if object.uri
            if have_property?(object)
              write_resource(e, object)
            else
              e.add_attribute(fold_uri(RDF::Namespace + "resource"),
                              object.uri.to_s)
            end
          else
            write_resource(e, object) # XXX
          end

          @written << object
        end
      end
    }
  end

  def fold_uri(uri)
    uri_s = uri.to_s
    @namespaces.each_pair{|prefix, namespace|
      if /\A#{Regexp.quote(namespace)}(.*)\Z/u =~ uri_s
        if prefix.empty?
          return $1
        else
          return prefix + ":" + $1
        end
      end
    }

    uri = uri.dup
    if s = uri.fragment
      uri.fragment = ''
    elsif s = uri.query
      uri = uri.query = ''
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

    # XXX
=begin
    unless e
      e = REXML::Element.new(fold_uri(RDF::Namespace + "Description"))
      @root << e
    end
=end

    if nodeID = e.attribute("nodeID", RDF::Namespace)
      nodeID.value
    else
      v = "blank" + @blank_counter.to_s
      e.add_attribute(fold_uri(RDF::Namespace + "nodeID"), v)
      @blank_counter = @blank_counter.succ
      v
    end
  end

  public

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

  def write(io, m, params)
    doc = model2rdfxml(m)
    doc.write(REXML::Output.new(io, params[:charset] || 'utf-8'))
    nil
  end
end # class XMLWriter


end # module Rena

