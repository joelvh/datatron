module Datatron
  class Translator
    include Translation

    module DataInterface
      include Translation
      extend Forwardable

      @translator = EmptyTranslator.instance
      attr_accessor :translator
      
      def_delegator :@translator, :source
      def_delegator :@translator, :destination
    end

    module StrategyInterface
      attr_accessor :source_item, :strategy, :dest_item
      def translate
        #the basic principle here is that the Translator
        # asks the "Strategy" what to do with each key?
        # where do I get the information for this attribute?
        # The transform ansers "get it from here"
        # Or "get it from the column of the samn name"
        # Or "get it from X but run it through this function
        # first
        # Or "Just tell the record item you'd like it populated."
        # or "Different step - ask for it to be done."
        source_item.attribute_names.each do |k|
          source_key = strategy.transform k
          case source_key
            when String
              source_item.attributes[k] = data_row[source_key]
            when Hash
              source_item.attributes[k] = source_key.to_a 
            when TrueClass
              source_item.attributes[k] = data_row[k]
            when FalseClass
              #do nothing
            when Proc
              source_item.attributes[k] = source_key[data_row[k]]
            when UsingTranslationAction
              # do this one next, but wrap it in the same transaction
              # and 
              debugger
              1
          end
        end
      end
    
      def translate!
        translate
        if dest_item.respond_to? :valid? and dest_item.valid?
          dest_item.save
        else
          raise Datatron::RecordInvalid, ar_item 
        end
      end
    end

    cattr_accessor :strategy
   
    class << self
      
      def with_strategy strat
        klass = Class.new(self) do
          
          include StrategyInterface
          self.strategy = strat
          self.strategy.extend DataInterface
               
          def initialize
            @strategy = self.class.strategy

            @strategy.translator = self

            @source = @strategy.from_source.next unless strategy.finder 
            @destination = @strategy.to_source.new unless strategy.router
            
            @source = @strategy.from_source.finder.call(@dest_item) if strategy.finder
            @destination = @strategy.to_source.destination.call(@source_item) if strategy.router
          end
        end
        # this will issue a warning if the class already exsists.
        debugger
        1
        const_set (klass.strategy.base_name.singularize.camelize + "Translator").intern, klass
        klass
      end
    end
  end
end

