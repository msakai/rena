require 'stringio'

module Rena

class N3Writer
  def initialize(model)
    @model    = model
    @prefixes = {}
  end

  def add_prefix(prefix, uri)
    uri = URI.parse(uri.to_s) unless uri.is_a? URI
    @prefixes[prefix] = uri
  end

  def each_prefix(&block)
    @prefixes.each{|(prefix,uri)|
      yield(prefix, uri)
    }
  end

  def write(out)
    uri_to_n3 = lambda{
      prefix_re_table = @prefixes.map{|(prefix,uri)|
	[Regexp.compile("\\A" + Regexp.escape(uri.to_s) + "(.*)\\Z"), prefix]
      }

      lambda{|uri|
	(_, prefix) = prefix_re_table.find{|re,prefix|
	  re =~ uri.to_s
	}
	if prefix
	  prefix + ":" + $1
	else
	  "<#{uri}>"
	end
      }
    }[]

    node_to_n3 = lambda{
      node_to_n3_table = {}
      i = 0

      lambda{|node|
        node_to_n3_table[node] ||=
          begin
	    case node
	    when URI
	      uri_to_n3[node]
	    when AnonymousNode
              "_:" + (i+=1).to_s
	    when String
	      '"' + node + '"'
	    end
          end
      }
    }[]

    each_prefix{|prefix, uri|
      out.puts "@prefix #{prefix}: <#{uri}> ."
    }

    @model.statements.classify{|s|
      s.subject
    }.each_pair{|subject, tmp|
      out.print(node_to_n3[subject])
      out.print(tmp.size == 1 ? " " : "\n")

      out.print tmp.classify{|s|
	s.predicate
      }.map{|(predicate, statements)|
	uri_to_n3[predicate] + " " +
	  statements.map{|s| node_to_n3[s.object] }.join(', ')
      }.join(" ;\n")

      out.print(" .\n")
    }
  end # def to_n3

end # class Model

end # module Rena
