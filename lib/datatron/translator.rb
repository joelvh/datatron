module Datatron
  class Translator
    include Translation
   
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

        strategy.strategy_hash.each_pair do |p,v|
          type = p.shift
          next if p.empty?
          
          op_field = p.shift
          if op_field.is_a? Regexp
            model = type == :from ? :from_source : :to_source
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
        
            puts c_field
            case v
              when Symbol, String
                destination[d_field] = source[s_field]
              when Hash
                destination[d_field] = proc_macro.call(*v.first)
              when CopyTranslationAction
                destination[d_field] = source[d_field]
              when DiscardTranslationAction
                next
              when Strategy
                debugger
                1
                Datatron::Translator.with_strategy(v.new).new.translate
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
          self.strategy = strat.dup
          self.strategy.extend DataInterface
               
          def initialize
            @strategy = self.class.strategy
            @strategy.translator = self
          end

          attr_reader :source, :destination

          def items 
            if strategy.finder
              @destination = strategy.to_source.new 
              args, finder_proc = *strategy.finder 
              @source = strategy.from_source.find *args.concat(@destination), finder_proc
            elsif strategy.router
              @source = strategy.from_source.next
              args, router_proc = *strategy.router
              @destination = strategy.to_source.find *args.concat(@source), router_proc
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

