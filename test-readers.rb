require 'rena'
require 'hyperset'
require 'test/unit'
require 'find'
$KCODE='utf-8'

class TestReaders < Test::Unit::TestCase

  def model_to_hyperset(model)
    blank2var_hash = {}
    blank2var = lambda{|x|
      if Rena::Resource === x
	x.uri || (blank2var_hash[x] ||= Hyperset::Variable.new)
      else
  	x
      end
    }
  
    var2children = {}
  
    pair2 = lambda{|a,b|
      Hyperset[Hyperset[a], Hyperset[a,b]]
    }
    pair3 = lambda{|a,b,c|
      Hyperset[Hyperset[a], Hyperset[a,b], Hyperset[a,b,c]]
    }
  
    items = []
    model.each_statement{|stmt|
      items << pair3[blank2var[stmt.subject], stmt.predicate, blank2var[stmt.object]]
      if stmt.subject.uri.nil?
  	(var2children[blank2var[stmt.subject]] ||= []) << 
  	  pair2[[true, stmt.predicate], blank2var[stmt.object]]
      end
      if Rena::Resource===stmt.object and stmt.object.uri.nil?
  	(var2children[blank2var[stmt.object]] ||= []) <<
  	  pair2[[false, stmt.predicate], blank2var[stmt.subject]]
      end
    }
  
    eqns = {}
    var2children.each_pair{|var, children|
      eqns[var] = Hyperset[*children]
    }
  
    root = Hyperset::Variable.new
    eqns[root] = Hyperset[*items]
  
    Hyperset.solve(eqns)[root]
  end

  def check_dir(dir)
    Find.find(dir){|rdf_fpath|
      if %r!(.*/test[^/]*)\.rdf$! =~ rdf_fpath and File.exist?(nt_fpath = $1 + ".nt")
	reader1 = Rena::XMLReader.new
	reader2 = Rena::NTReader.new

	uri1 = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
			 rdf_fpath.sub(/^.*approved_20031114\//, ''))
	uri2 = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
			 nt_fpath.sub(/^.*approved_20031114\//, ''))
	  
	reader1.model = Rena::MemModel.new
	reader2.model = Rena::MemModel.new
	reader1.read(File.open(rdf_fpath), uri1)
	reader2.read(File.open(nt_fpath), uri2)

=begin
	assert_equal(reader1.model.statements.size,
		     reader2.model.statements.size,
		     "#{rdf_fpath} and #{nt_fpath} have differenet number of statements")
=end

	s1 = model_to_hyperset(reader1.model)
	s2 = model_to_hyperset(reader2.model)

	assert_equal(s1, s2,
		     "#{rdf_fpath} and #{nt_fpath} are not equal as hyperset")
      end
    }
  end

  base = "approved_20031114"
  Dir.entries(base).each{|e|
    next if ["..", "."].member?(e)
    fname = File.join(base, e)
    next unless File.directory?(fname)
    define_method(("test_" + e.gsub(/-/, "_")).intern){||
      check_dir(fname)
    }
  }

end

