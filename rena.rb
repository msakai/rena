require 'uri'
require 'set'


# XXX

class URI::Generic
  def hash
    to_s.hash
  end

  def eql?(other)
    URI===other and self==other
  end
end


require 'rena/model'
#require 'rena/n3'
require 'rena/xml'
require 'rena/nt'
require 'rena/memmodel'


if $0 == __FILE__

require 'pp'

channel_uri = URI.parse("http://www.tom.sfc.keio.ac.jp/~sakai/rss/sfc-media-center.rdf")

reader = Rena::XMLReader.new
reader.model = Rena::MemModel.new
reader.read(File.open("sfc-media-center.rdf"), channel_uri)

channel = reader.model[channel_uri]
channel["http://purl.org/rss/1.0/items"][0].each_property{|prop, item|
  next unless %r!\Ahttp://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)\Z! =~ prop.to_s
  puts item["http://purl.org/rss/1.0/link"][0]
  puts item["http://purl.org/rss/1.0/title"][0]
  puts item["http://purl.org/dc/elements/1.1/date"][0]
}

end
