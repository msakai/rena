require 'rena'

base = URI.parse("http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfms-xml-literal-namespaces/test001.rdf")

model = Rena::MemModel.new
model.load("tests/approved_20031114/rdfms-xml-literal-namespaces/test001.rdf",
           :type => 'application/rdf+xml',
           :base => base)
model.save("hogehoge.rdf")
