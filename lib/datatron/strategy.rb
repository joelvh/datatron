module Datatron
  class Strategy 
    include Datatron::TransformDSL

    class << self
      def === obj
        if obj.is_a? self
          return true
        elsif obj < self
          return true
        else
          return false
        end
      end
    end
          
    
    attr_accessor :strategy_hash
    
    def initialize strategy, *args, &block
      @strategy_hash = OrderTree::OrderTree.new( {:from => {}, :to => {}} )
      super
    end
  end
end
