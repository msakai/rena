# FIXME
# http://dublincore.org/2003/03/24/dces#
module Rena::DC
  Prefix    = "dc".freeze
  Namespace = "http://purl.org/dc/elements/1.1/".freeze

  # predicate
  Title = URI.parse(Namespace + "title").freeze
  Date  = URI.parse(Namespace + "date").freeze
end
