#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'pp'
require 'rena'
require 'rena/rss'
require 'rena/dc'
RDF = Rena::RDF
RSS = Rena::RSS
DC  = Rena::DC

model = Rena::MemModel.new
model.load("sfc-media-center.rdf",
           :type => 'application/rdf+xml',
           :base => URI.parse("http://www.tom.sfc.keio.ac.jp/~sakai/rss/sfc-media-center.rdf"))

channel = model.lookup_resource(RSS::Channel)

model.each_resource{|res|
  next unless res[RDF::Type].include?(channel)
  res[RSS::Items][0].each_property{|prop, item|
    next unless %r!\Ahttp://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)\Z! =~ prop.to_s
    puts item[RSS::Link][0]
    puts item[RSS::Title][0]
    puts item[DC::Date][0]
  }
}
