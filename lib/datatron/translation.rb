module Datatron
  module Translation
    class EmptyTranslator
      include Singleton
      [:source, :destination].each do |op|
        define_method(op) do |field|
          raise DatatronError, "Strategy is not part of a translator!" 
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
      class << self
        def substrategy parent, strat, *args, &block
          klass = Class.new(strat) do
            define_method :initialize do
              super(strat.name)
              @parent = parent
              collected_args = args.collect do |a|
                a.send_to @parent if a.is_a? DeferredMethodCall
              end
              modify collected_args, &block
            end
          end
          # this is not strictly necessary, but it makes it prettier to look at.
          const_set (parent.base_name.singularize.camelize + strat.base_name.singularize.camelize).intern, klass
        end
      end
    end
  end
end 
