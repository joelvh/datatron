module Datatron
  class Translator
    include Translation
    
    module StrategyInterface
      include Translation
      def translate_item
        #the basic principle here is that the Translator
        # asks the "Strategy" what to do with each key?
        # where do I get the information for this attribute?
        # The transform ansers "get it from here"
        # Or "get it from the column of the samn name"
        # Or "get it from X but run it through this function
        # first
        # Or "Just tell the record item you'd like it populated."
        # or "Different step - ask for it to be done."

        strategy.strategy_hash.each_pair do |p,v|
          type = p.shift
          next if p.empty?
          
          op_field = p.shift
          if op_field.is_a? Regexp
            model = type == :from ? :from_model : :to_model
            op_fields = strategy.send(model).keys.select { |v| op_field.match v}
          else
            op_fields = [op_field]
          end

          strat_process_lambda = lambda do |c_field|
            if type == :from
              d_field = v.to_s
              s_field = c_field.to_s
              proc_macro = lambda do |field, prok|
                destination[field.to_s] = prok.call(source[s_field])
              end
            elsif type == :to
              d_field = c_field.to_s
              s_field = v.to_s
              proc_macro = lambda do |field, prok|
                destination[s_field] = prok.call(field.to_s)
              end
            end
            
            case v
              when SymbolString
                destination[d_field] = source[s_field]
              when Hash
                proc_macro[*v.first].call
              when CopyTranslationAction
                destination[d_field] = source[d_field]
              when DiscardTranslationAction
                next
              when Proc
                v.call(source[c_field])
              when v.substrategy?
                debugger
            end
          end
              

          op_fields.collect do |field|
            strat_process_lambda.call field
          end
        end

      end
    
      def translate_item!
        translate_item
        if dest.respond_to? :valid? 
          raise Datatron::RecordInvalid, dest unless dest.valid?
        end
        dest.save
      end

      def translate
        self.each do |s,d|
          # we don't actually need to pass
          # s,d here, since they're available
          # as accessor source, destination
          translate_item
        end
      end
    end

    cattr_accessor :strategy
   
    class << self
      
      def with_strategy strat
        klass = Class.new(self) do
          include StrategyInterface
          self.strategy = strat
               
          def initialize
            @strategy = self.class.strategy.dup
          end

          attr_reader :source, :destination

          def items 
            puts strategy.to_source
            puts strategy.from_source

            if strategy.finder
              @destination = strategy.to_source.new 
              @source = strategy.from_source.finder.call(@destination)
            elsif strategy.router
              @source = strategy.from_source.next
              @destination = strategy.to_source.destination.call(@source)
            else
              @destination = strategy.to_source.new 
              @source = strategy.from_source.next
            end
              
            return @source, @destination
          end

          def each 
            return enum_for(:each) unless block_given?
            while ia = items 
             yield ia
            end
          end
        end
        # this will issue a warning if the class already exsists.
        const_set (klass.strategy.base_name.singularize.camelize + "Translator").intern, klass
        klass
      end
    end
  end
end

