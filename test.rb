require 'rena'
require 'rexml/document'
require 'pp'
$KCODE='utf-8'

ARGV.each{|fname|
  if /.nt$/ =~ fname
    reader = Rena::NTReader.new
  else
    reader = Rena::XMLReader.new
  end
  reader.read(File.open(fname),
	      URI.parse("http://www.tom.sfc.keio.ac.jp/~sakai/rss/sfc-media-center.rdf"))
  pp reader.model
}
