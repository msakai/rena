
# http://www.purl.org/rss/1.0/spec
module Rena::RSS
  Prefix    = "rss"
  Namespace = "http://purl.org/rss/1.0/"

  # class
  Channel = URI.parse(Namespace + "channel")
  Item    = URI.parse(Namespace + "item")
  Image   = URI.parse(Namespace + "image")

  # predicates
  Title       = URI.parse(Namespace + "title")
  Link        = URI.parse(Namespace + "link")
  Description = URI.parse(Namespace + "description")
  #Image       = URI.parse(Namespace + "image")
  Items       = URI.parse(Namespace + "items")
  TextInput   = URI.parse(Namespace + "textinput")
  Name        = URI.parse(Namespace + "name")
end
