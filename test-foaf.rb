# -*- coding: utf-8 -*-
require 'rena'
include Rena

reader = XMLReader.new
reader.model = MemModel.new
reader.read(File.open("knu/foaf.rdf"), "")
#reader.read(File.open("foaf.rdf"), "")
#require 'open-uri'
#reader.read(StringIO.new(open("http://web.sfc.keio.ac.jp/~s01397ms/foaf.rdf").read), "")

writer = XMLWriter.new
#writer.namespaces["rdf"] = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#writer.namespaces["rdfs"] = "http://www.w3.org/2000/01/rdf-schema#"
#writer.namespaces["dc"]   = "http://purl.org/dc/elements/1.1/"
#writer.namespaces["foaf"] = "http://xmlns.com/foaf/0.1/"
#writer.namespaces["geo"]  = "http://www.w3.org/2003/01/geo/wgs84_pos#"
#writer.namespaces["wot"]  = "http://xmlns.com/wot/0.1/"

doc = writer.model2rdfxml(reader.model)
#pp doc

doc.write(REXML::Output.new(STDOUT, "utf-8"))

#io = StringIO.new
#doc.write(io)
#Uconv::
