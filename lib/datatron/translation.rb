module Datatron
  module Translation
    class EmptyTranslator
      include Singleton
      [:source, :destination].each do |op|
        define_method(op) do |field|
          raise DatatronError, "Strategy is not part of a translator so #{op} is not available" 
        end
      end
    end
    
    class TranslationAction
      include ::Singleton
    end
    
    class AwaitingTranslationAction < TranslationAction; end
    class CopyTranslationAction < TranslationAction; end
    class DiscardTranslationAction < TranslationAction; end
    
    class UsingTranslationAction < TranslationAction
      module SubStrategy
        attr_accessor :parent
        def extended obj
          obj.instance_eval do
            @parent = nil
          end
        end
      end
      
      class << self
        def substrategy parent, strat, *args, &block
          #retrive the strategy if it doesn't exist, or create it
          #using the supplied block
          strategy_name = "for_#{parent.base_name}_#{parent.name}".intern
          begin
            strat_instance = strat.send strategy_name
          rescue NoMethodError => e
            if e.name == strategy_name
              strat.send "for_#{parent.base_name}_#{parent.name}".intern, *args, &block
              retry
            else
              raise e
            end
          end
          strat_instance.extend SubStrategy
          strat_instance
        end
      end
    end
  end
end 
