require 'rena'
require 'pp'

model = Rena::MemModel.new
model.load("tests/approved_20031114/rdfms-xml-literal-namespaces/test002.rdf")
model.each_statement{|x|
  pp x
}
