module Datatron
  class Translator
    include Translation
    Action = Struct.new(:value, :destination_field, :source_field, :proc_macro)
    
    
    #this module is mixed into the strategy instance
    #at runtime to provide access to the current source
    #and current destination items via the #source
    #and #destination methods
    module DataInterface
      extend Forwardable

      class << self
        def extended obj
          obj.instance_eval do
            @translator = Datatron::Translation::EmptyTranslator.instance
          end
        end
      end

      attr_accessor :translator
      
      def_delegator :@translator, :source
      def_delegator :@translator, :destination
    end


    # This is mixed into the translator to provide
    # and interface to the strategy object
    module StrategyInterface
      include Translation

      def process_field action 
        case action.value 
          when Symbol, String
            destination[action.destination_field] = source[action.source_field]
          when Hash
            destination[action.destination_field] = action.proc_macro.call(*action.value.first)
          when CopyTranslationAction
            destination[action.destination_field] = source[action.destination_field]
          when DiscardTranslationAction
            return nil
          when Strategy
            action.value.parent = self
            Datatron::Translator.with_strategy(action.value).translate
        end
        true
      end
      private :process_field

      def translate_item
        #the basic principle here is that the Translator
        # asks the "Strategy" what to do with each key?
        # where do I get the information for this attribute?
        # The transform ansers "get it from here"
        # Or "get it from the column of the samn name"
        # Or "get it from X but run it through this function
        # firstkkj
        # Or "Just tell the record item you'd like it populated."
        # or "Different step - ask for it to be done."
        #
        
        strategy.strategy_hash.each_pair do |p,v|
          type = p.shift
          next if p.empty?
          
          op_field = p.shift
          
          if op_field.is_a? Regexp
            model = type == :from ? :from_source : :to_source
            op_fields = strategy.send(model).keys.select { |v| op_field.match v}
          elsif op_field.is_a? Array
            op_fields.concat op_field
          else
            op_fields = [op_field]
          end
          
          
          op_fields.collect do |field|

            action = Action.new
            
            if type == :from
              action.destination_field = v.to_s
              action.source_field = field.to_s
              action.proc_macro = lambda do |proc_field, prok|
                destination[proc_field.to_s] = prok.call(source[action.source_field])
              end
            elsif type == :to
              action.destination_field = field.to_s
              action.source_field = v.to_s
              action.proc_macro = lambda do |proc_field, prok|
                destination[action.source_field] = prok.call(proc_field.to_s)
              end
            end
            action.value = v
           
            # this is basically executed for it's side effects.
            process_field(action) || next
          end
        end

      end
    
      def translate_item!
        translate_item
        if destination.respond_to? :valid? 
          raise Datatron::RecordInvalid, dest unless dest.valid?
        end
        destination.save
      end

      def translate
        self.each do |s,d|
          # we don't actually need to pass
          # s,d here, since they're available
          # as accessor source, destination
          begin
            translate_item
            destination.save
          rescue StandardError => e
            if strategy.strategy_hash.has_key? :error
              strategy.strategy_hash[:error].call(e)
            else
              puts "no error handler provided"
              raise e
            end
          end
        end
      end
    end

    cattr_accessor :strategy
   
    class << self
      
      def with_strategy strat
        klass = Class.new(self) do

          include StrategyInterface
          self.strategy = strat.clone
          self.strategy.extend DataInterface
               
          def initialize
            @strategy = self.class.strategy
            @strategy.translator = self
          end

          attr_reader :source, :destination

          def items 
            strategy.from_source.rewind
            
            if strategy.finder
              args, finder_proc = strategy.finder
              strategy.from_source.send :_finder, *args, &finder_proc
            end

            @destination = strategy.to_source.new 
            
            if strategy.router
              args, dest_proc = strategy.router
              @destination.define_singleton_method :save do |*args|
                args = [@destination].concat args[0..&dest_proc.arity-1]
                strategy.instance_exec *args, &dest_proc
              end
            end
          
            @source = strategy.from_source.next
              
            return @source, @destination
          end

          def each 
            return enum_for(:each) unless block_given?
            loop do
             yield items
            end
          end
        end
        # this will issue a warning if the class already exsists.
        const_set (klass.strategy.base_name.singularize.camelize + "Translator").intern, klass
        klass.new
      end
    end
  end
end

