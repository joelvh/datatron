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
          when Proc
            action.value.call(source[action.source_field])
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
        # Or "Just tell the record item you'd likke it populated."
        # or "Different step - ask for it to be done."
       
        #destination keys not explicity assigned to
        strategy.strategy_hash.each_pair do |p,v|
          
          type = p.shift
          next if p.empty?
          
          op_field = p.shift
          next if op_field == :error
          
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
            begin
              process_field(action) || next
            rescue StandardError => e
              error_loc = strategy.strategy_hash[type][op_field]
              if error_loc.respond_to? :has_key? and error_loc.has_key? :error
                destination[action.destination_field] = error_loc[:error].call(e)
              else
                raise e
              end
            end
          end
        end

      end
    
      def translate_item!
        translate_item
        if destination.respond_to? :valid? 
          raise Datatron::RecordInvalid, dest unless dest.valid?
        end
        strategy.save
      end

      def translate
        self.each do |s,d|
          # we don't actually need to pass
          # s,d here, since they're available
          # as accessor source, destination
          begin
            translate_item
            strategy.save
          rescue StandardError => e
            if strategy.strategy_hash.has_key? :error
              puts strategy.strategy_hash[:error].call(e)
            else
              puts "no error handler provided"
              raise e
            end
          end
        end
      end
    end

    class << self
      
      def with_strategy strat
        klass = Class.new(self) do |this|
          
          class << self
            attr_accessor :strategy
          end

          include StrategyInterface
          this.strategy = strat.clone
          this.strategy.extend DataInterface
          
          attr_reader :source, :destination, :strategy

          def initialize
            @strategy = self.class.strategy
            @strategy.translator = self
            
            destination.class.keys.reject do |dk|
              true if dk == "id"
              strategy.strategy_hash.find do |v|
                p = v.path
                break true if p[0] == :to and p[1].to_s == dk.to_s
                break true if v.is_a? Hash and v.keys.first.to_s == dk
                break true if v.to_s == dk
              end
            end.collect { |k| [:to, k]}

            #default destinations

        end

          end

          def items 
            @destination = self.strategy.new #that's actually an instance method
            @source = self.strategy.next 
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

