require 'rena'
require 'pp'
$KCODE='utf-8'

ARGV.each{|fname|
  model = Rena::MemModel.new

  base = URI.parse("http://www.tom.sfc.keio.ac.jp/~sakai/rss/sfc-media-center.rdf")
  if /.nt$/ =~ fname
    model.load(fname,
               :type => 'text/ntriples',
               :base => base)
  else
    model.load(fname,
               :type => 'application/rdf+xml',
               :base => base)
  end

  pp model
}
