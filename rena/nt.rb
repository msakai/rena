# -*- coding: utf-8 -*-
require 'rexml/document'

module Rena

class NTReader
  def initialize
    @model = nil
    @blank_nodes = {}
  end
  attr_accessor :model

  def read(io, params)
    io.each{|line|
      next if /\A\s*#/ =~ line
      next if /\A\s*\Z/ =~ line

      if line.sub!(/\A\s*<([^>]*)>/, '')
	subject = @model.create_resource(URI.parse($1))
      elsif line.sub!(/\A\s*_:([A-Za-z][A-Za-z0-9]*)/, '')
	subject = lookup_nodeID($1)
      else
	raise RuntimeError.new(line.inspect)
      end

      if line.sub!(/\A\s*<([^>]*)>/, '')
	predicate = URI.parse($1)
      else
	raise RuntimeError.new(line.inspect)
      end

      if line.sub!(/\A\s*<([^>]*)>/, '')
	object = @model.create_resource(URI.parse($1))
      elsif line.sub!(/\A\s*_:([A-Za-z][A-Za-z0-9]*)/, '')
	object = lookup_nodeID($1)
      elsif line.sub!(/\A\s*"((?:\\"|[^"])*)"(?:@([a-zA-Z_\-]*))?(?:\^\^<([^>]*)>)?/, '')
	str  = $1
	lang = $2
	type = $3

	str.gsub!(/\\([^u]|u([0-9a-fA-F]{4}))/){
	  case $1
	  when "\\" #"
	  when '"'
	    $1
	  when "n"
	    "\n"
	  when "r"
	    "\r"
	  when "t"
	    "\t"
	  else
	    if $2
	      [$2.hex].pack("U")
	    else
	      raise RuntimeError.new("\\#{$1} is invalid escape")
	    end
	  end
	}

	if type
	  object = TypedLiteral.new(str, URI.parse(type))
	else
	  object = PlainLiteral.new(str, lang)
	end
      else
	raise RuntimeError.new(line.inspect)
      end

      unless /\A\s*\.\s*\Z/ =~ line
	raise RuntimeError.new(line.inspect)
      end

      subject.add_property(predicate, object)
    }
  end

  private
  def lookup_nodeID(nodeID)
    @blank_nodes[nodeID] ||= @model.create_resource
  end
end



class NTWriter

  def write(io, m, params)
    self.class.write_model(m, io)
  end

  def model2nt(m)
    require 'stringio'
    io = StringIO.new
    self.class.write_model(m, io)
    io.string
  end

  def self.write_model(m, io)
    blank_node_counter = 0
    blank_nodes_to_id = Hash.new
    resource_to_nt = lambda{|resource|
      if resource.uri
        '<' + resource.uri.to_s + '>'
      else
        "_:" + (blank_nodes_to_id[resource] ||= "a" + (blank_node_counter += 1).to_s)
      end
    }

    m.each_resource{|subject|
      subject_str = resource_to_nt[subject]
      subject.each_property{|prop, object|
        io.print subject_str
        io.print " "
        io.print("<", prop.to_s, ">")
        io.print " "
        if object.is_a? Literal
          io.print object.nt
        else
          io.print resource_to_nt[object]
        end
        io.print " .\n"
      }
    }

    nil
  end
end


end #module Rena
