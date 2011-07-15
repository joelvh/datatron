require 'datatron/transform_methods'

module Datatron
  
  class Strategy 
    include TransformMethods
    
    attr_accessor :strategy_hash, :strategy_order
    
    def initialize strategy, *args, &block
      @strategy_order = []
      debugger
      1
      @strategy_hash = HashWithOrderCallback.new()
      @strategy_hash[:from] = HashWithOrderCallback.new
      @strategy_hash[:to] = HashWithOrderCallback.new
      super
    end
    
    class << self
      def concreteize
        StrategyExecutor.new(self)
      end
    end
  end

  #provides a concretized interface to a strategy and 
  #uses the iterators to provide the data rows.
  class StrategyExecutor 
    
    def initialize strategy
    end

    module FuzzyInclude
      def fuzzy_include? v
        self.detect { |p| p === v}
      end
    end

    def transform key
      if (path = path_for_key(key))
        type, location = path
        return lookup[type][location]
      elsif implicit_keys.include? key
        return true
      elsif inferred_keys.include? key
        return lookup[:to][location]
      elsif all_keys.include? key
        # we are aware of the key and want to do nothing withit.
        return false
      else
        raise TranslationKeyError, "Don't know anything about #{key}" 
      end
    end
  end
end
