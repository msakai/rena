# FIXME
module Rena::RDF
  Prefix    = "rdf"
  Namespace = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

  # class
  Seq       = URI.parse(Namespace + "Seq")
  Statement = URI.parse(Namespace + "Statement")

  # resource
  Nil   = URI.parse(Namespace + "nil")
  First = URI.parse(Namespace + "first")
  Rest  = URI.parse(Namespace + "rest")

  # predicate
  Type      = URI.parse(Namespace + "type")
  Subject   = URI.parse(Namespace + "subject")
  Predicate = URI.parse(Namespace + "predicate")
  Object    = URI.parse(Namespace + "object")
end
