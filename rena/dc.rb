# FIXME
# http://dublincore.org/2003/03/24/dces#
module Rena::DC
  Prefix    = "dc"
  Namespace = "http://purl.org/dc/elements/1.1/"

  # predicate
  Title = URI.parse(Namespace + "title")
  Date  = URI.parse(Namespace + "date")
end
