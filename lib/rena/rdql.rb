# -*- coding: utf-8 -*-
#
# Copyright (c) 2004 Masahiro Sakai <sakai@tom.sfc.keio.ac.jp>
# You can redistribute it and/or modify it under the same term as Ruby.
#

require 'rena/rdql-parser'

module Rena
module RDQL

class Query
  def initialize(select, source, patterns, constraints, prefixes)
    @select      = select
    @source      = source
    @patterns    = patterns
    @constraints = constraints
    @prefixes    = prefixes
  end

  attr_accessor :select
  attr_accessor :source
  attr_accessor :patterns
  attr_accessor :constraints
  attr_accessor :prefixes

end # class Query



class ConditionalAnd
  def initialize(*args)
    @args = args
  end
  attr_accessor :args

  def eval(binding)
    @args.inject(true){|result,item|
      result and item.eval(binding)
    }
  end
end

class ConditionalOr
  def initialize(*args)
    @args = args
  end
  attr_accessor :args

  def eval(binding)
    @args.inject(false){|result,item|
      result or item.eval(binding)
    }
  end
end


class StringEqual
  def initialize(a,b)
    @a = a
    @b = b
  end
end

class StringNotEqual
  def initialize(a,b)
    @a = a
    @b = b
  end
end


class BitOR
  def initialize(*args)
    @args = args
  end
  attr_accessor :args

  def eval(binding)
    @args.inject(0){|result,item|
      result || item.eval(binding)
    }
  end
end

class BitXOR
  def initialize(*args)
    @args = args
  end
  attr_accessor :args

  def eval(binding)
    @args.inject(0){|result,item|
      result ^ item.eval(binding)
    }
  end
end

class BitAND
  def initialize(*args)
    @args = args
  end
  attr_accessor :args

  def eval(binding)
    @args.inject(0){|result,item|
      result & item.eval(binding)
    }
  end
end


class EqualityExpression
end

class Eq < EqualityExpression
  def initialize(a,b)
    @a = a
    @b = b
  end
end

class NEq < EqualityExpression
  def initialize(a,b)
    @a = a
    @b = b
  end
end


class RelationalExpression
end

class BinaryRel < RelationalExpression
  def initialize(rel,a,b)
    @rel = rel
    @a = a
    @b = b
  end
end


class UnaryOp
  def initialize(op,a)
    @op = op
    @a = a
  end
end

class BinaryOp
  def initialize(op,a,b)
    @op = op
    @a = a
    @b = b
  end
end


end #RDQL
end #Rena




if __FILE__ == $0
require 'pp'

# Query example 1: Retrieve the value of a known property of a known resource
parser = Rena::RDQL::Parser.new
pp parser.parse <<END
SELECT ?x
WHERE  (<http://somewhere/res1>, <http://somewhere/pred1>, ?x)
END

# Query example 2: constraints
parser = Rena::RDQL::Parser.new
pp parser.parse <<END
SELECT ?a, ?b
WHERE  (?a, <http://somewhere/pred1>, ?b)
AND    ?b < 5
END

# Query example 3: paths in the graph
parser = Rena::RDQL::Parser.new
pp parser.parse <<END
SELECT ?a, ?b
WHERE (?a, <http://somewhere/pred1>, ?c) ,
      (?c, <http://somewhere/pred2>, ?b)
END

# Query example 3: paths in the graph
parser = Rena::RDQL::Parser.new
pp parser.parse <<END
SELECT ?x, ?y
WHERE (<http://never/bag>, ?x, ?y)
AND ! ( ?x eq <rsyn:type> && ?y eq <rsyn:Bag>)
USING
rsyn FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
END
  
end
