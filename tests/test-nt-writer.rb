#!/usr/bin/env ruby
$KCODE='utf-8'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..")
require 'rena'
require 'rena-test-utils'

require 'hyperset'
require 'test/unit'
require 'find'
require 'pp'
require 'tempfile'

class TestNTWriter < Test::Unit::TestCase
  include RenaTestUtils

  def check_rdf(rdf_fpath)
    uri = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/" +
                      rdf_fpath.sub(/^.*approved_20031114\//, ''))    

    model1 = Rena::MemModel.new
    model1.load(rdf_fpath, :type => 'text/ntriples', :base => uri)

    tmpfile = Tempfile.new('rena-test-nt-writer')
    writer = Rena::NTWriter.new
    tmpfile.write(writer.model2nt(model1))
    tmpfile.close(false)

    model2 = Rena::MemModel.new
    model2.load(tmpfile.path, :type => 'text/ntriples', :base => uri)

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

  base = File.join(File.dirname(__FILE__), "approved_20031114")
  Dir.entries(base).each{|e|
  #["rdf-containers-syntax-vs-schema"].each{|e|
  #["rdfms-xml-literal-namespaces"].each{|e|
    next if ["..", "."].member?(e)
    fname = File.join(base, e)
    next unless File.directory?(fname)

    Find.find(fname){|nt_fpath|
      if m = %r!(.*/(test[^/]*))\.nt$!.match(nt_fpath)
        mname = "test_" + e.gsub(/-/, "_") + "__" + m[2]
        define_method(mname.intern){||
          check_rdf(nt_fpath)
        }
      end
    }
  }

end
