module Datatron
  class Translator
    module StrategyInterface
      attr_accessor :source_item, :strategy, :dest_item
      def translate
        #the basic principle here is that the Translator
        # asks the "Transform" what to do with each key?
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
          raise ActiveRecord::RecordInvalid, ar_item 
        end
      end
    end
   
    class << self
      attr_accessor :strategy

      def with_strategy strategy
        klass = Class.new(self) do
          include StrategyInterface
          @strategy = strategy

          def initialize
            @strategy = self.class.strategy

            @source_item = strategy.from_source.next unless strategy.finder 
            @dest_item = strategy.to_source.new unless strategy.router
            
            @source_item = strategy.from_source.finder.call(@dest_item) if strategy.finder
            @dest_item = strategy.to_source.destination.call(@source_item) if strategy.router
          end
        end
        # this will raise an error if the class already exsists.
        const_set (klass.strategy.base_name.singularize.camelize + "Translator").intern, klass
        klass
      end
    end
  end
end

