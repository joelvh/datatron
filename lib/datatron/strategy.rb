require 'datatron/transform_methods'
require 'order_tree'

module Datatron
  class Strategy 
    include TransformMethods
    
    attr_accessor :strategy_hash
    
    def initialize strategy, *args, &block
      @strategy_hash = OrderTree::OrderTree.new( {:from => {}, :to => {}} )
      super
    end
  end
end
