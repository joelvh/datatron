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
        def substrategy parent, klass, *args, &block
          #retrive the strategy if it exists, or create it if it doesn't
          #using the supplied block
          strategy_name = "#{klass.base_name}_for_#{parent.base_name}_#{parent.instance_variable_get :@name}".intern
          begin
            strat_instance = klass.send strategy_name
          rescue NoMethodError => e
            if e.name == strategy_name
              klass.send "#{klass.base_name}_for_#{parent.base_name}_#{parent.instance_variable_get :@name}".intern, *args, &block
              retry
            else
              raise e
            end
          end
          strat_instance.extend SubStrategy
          strat_instance.parent = parent
          strat_instance
        end
      end
    end
  end
end 
