# -*- coding: utf-8 -*-
require 'rena'
require 'open-uri'
include Rena

model = MemModel.new
model.load("foaf.rdf",
           :type => 'application/rdf+xml',
           :base => URI.parse(http://web.sfc.keio.ac.jp/~s01397ms/foaf.rdf))

writer = XMLWriter.new
#writer.namespaces["rdf"]  = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#writer.namespaces["rdfs"] = "http://www.w3.org/2000/01/rdf-schema#"
#writer.namespaces["dc"]   = "http://purl.org/dc/elements/1.1/"
#writer.namespaces["foaf"] = "http://xmlns.com/foaf/0.1/"
#writer.namespaces["geo"]  = "http://www.w3.org/2003/01/geo/wgs84_pos#"
#writer.namespaces["wot"]  = "http://xmlns.com/wot/0.1/"

doc = writer.model2rdfxml(model)
#pp doc

doc.write(REXML::Output.new(STDOUT, "utf-8"))

#io = StringIO.new
#doc.write(io)
#Uconv::

