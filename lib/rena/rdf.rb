# FIXME
module Rena::RDF
  Prefix    = "rdf".freeze
  Namespace = "http://www.w3.org/1999/02/22-rdf-syntax-ns#".freeze

  # class
  Seq       = URI.parse(Namespace + "Seq").freeze
  Statement = URI.parse(Namespace + "Statement").freeze

  # resource
  Nil   = URI.parse(Namespace + "nil").freeze
  First = URI.parse(Namespace + "first").freeze
  Rest  = URI.parse(Namespace + "rest").freeze

  # predicate
  Type      = URI.parse(Namespace + "type").freeze
  Subject   = URI.parse(Namespace + "subject").freeze
  Predicate = URI.parse(Namespace + "predicate").freeze
  Object    = URI.parse(Namespace + "object").freeze
end
