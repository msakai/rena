# -*- coding: utf-8 -*-
require 'rena'
require 'open-uri'
include Rena

model = MemModel.new
# model.load("foaf.rdf",
#            :type => 'application/rdf+xml',
#            :base => URI.parse("http://web.sfc.keio.ac.jp/~s01397ms/foaf.rdf"))
model.load("http://web.sfc.keio.ac.jp/~s01397ms/foaf.rdf")
model.save(STDOUT, :content_type => 'application/rdf+xml')
