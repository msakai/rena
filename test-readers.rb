#!/usr/bin/env ruby
require 'rena'
require 'hyperset'
require 'test/unit'
require 'find'
require 'pp'
$KCODE='utf-8'

module RenaTestUtils
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
end



class TestReaders < Test::Unit::TestCase
  include RenaTestUtils

  def check_rdf(nt_fpath, rdf_fpath)
    reader1 = Rena::NTReader.new
    reader2 = Rena::XMLReader.new

    uri1 = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
                       nt_fpath.sub(/^.*approved_20031114\//, ''))
    uri2 = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
                       rdf_fpath.sub(/^.*approved_20031114\//, ''))

    model1 = Rena::MemModel.new
    model2 = Rena::MemModel.new
          
    reader1.model = model1
    reader2.model = model2

    reader1.read(File.open(nt_fpath), uri1)
    reader2.read(File.open(rdf_fpath), uri2)

    if model1.statements.size != model2.statements.size
      puts "--------------------------------"
      model1.statements.map{|s| p s.predicate }
      puts "--------------------------------"
      model2.statements.map{|s| p s.predicate }
      puts "--------------------------------"
    end

    assert_equal(model1.statements.size,
                 model2.statements.size,
                 "#{nt_fpath} and #{rdf_fpath} have different number of statements")

    s1 = model_to_hyperset(model1)
    s2 = model_to_hyperset(model2)

    assert_equal(s1, s2,
                 "#{nt_fpath} and #{rdf_fpath} are not equal as hyperset")
  end

  

  base = "approved_20031114"
  Dir.entries(base).each{|e|
  #["rdf-containers-syntax-vs-schema"].each{|e|
  #["rdfms-xml-literal-namespaces"].each{|e|
    next if ["..", "."].member?(e)
    fname = File.join(base, e)
    next unless File.directory?(fname)

    Find.find(fname){|rdf_fpath|
      if m = %r!(.*/(test[^/]*))\.rdf$!.match(rdf_fpath) and
          File.exist?(nt_fpath = m[1] + ".nt")
        mname = "test_" + e.gsub(/-/, "_") + "__" + m[2]
        define_method(mname.intern){||
          check_rdf(nt_fpath, rdf_fpath)
        }
      end
    }
  }

end




class TestXMLWriter < Test::Unit::TestCase
  include RenaTestUtils

  def check_rdf(rdf_fpath)
    uri = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
                      rdf_fpath.sub(/^.*approved_20031114\//, ''))    

    model1 = Rena::MemModel.new
    model2 = Rena::MemModel.new

    reader1 = Rena::XMLReader.new
    reader1.model = model1
    reader1.read(File.open(rdf_fpath), uri)

    writer = Rena::XMLWriter.new
    doc = writer.model2rdfxml(model1)

    reader2 = Rena::XMLReader.new
    reader2.model = model2
    reader2.read_from_xml_document(doc, uri)

    if model1.statements.size != model2.statements.size
      puts "--------------------------------"
      model1.statements.map{|s| p s.predicate }
      puts "--------------------------------"
      model2.statements.map{|s| p s.predicate }
      puts "--------------------------------"
    end

    assert_equal(model1.statements.size,
                 model2.statements.size,
                 "#{rdf_fpath} have different number of statements")

    s1 = model_to_hyperset(model1)
    s2 = model_to_hyperset(model2)

    assert_equal(s1, s2,
                 "#{rdf_fpath} are not equal as hyperset")
  end

  base = "approved_20031114"
  Dir.entries(base).each{|e|
  #["rdf-containers-syntax-vs-schema"].each{|e|
  #["rdfms-xml-literal-namespaces"].each{|e|
    next if ["..", "."].member?(e)
    fname = File.join(base, e)
    next unless File.directory?(fname)

    Find.find(fname){|rdf_fpath|
      if m = %r!(.*/(test[^/]*))\.rdf$!.match(rdf_fpath)
        mname = "test_" + e.gsub(/-/, "_") + "__" + m[2]
        define_method(mname.intern){||
          check_rdf(rdf_fpath)
        }
      end
    }
  }

end
