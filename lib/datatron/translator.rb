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

      def rewind
        strategy.to_source.rewind
        strategy.from_source.rewind
      end

      def process_field! action 
        case action.value 
          when Symbol, String
            destination[action.destination_field.intern] = source[action.source_field.intern]
          when Hash
            strategy.instance_exec *action.value.first, &action.proc_macro
          when CopyTranslationAction
            destination[action.source_field.intern] = source[action.source_field.intern]
          when DiscardTranslationAction, NilClass
            false
          when Proc
            strategy.instance_exec source[action.source_field.intern], &action.value
          when Strategy
            action.value.parent = self
            Datatron::Translator.with_strategy(action.value).translate
        end
      end
      private :process_field!

      def translate_item
        #destination keys not explicity assigned to
        translation_keys = (strategy.strategy_hash.each_path.to_a + implicit_keys).reject { |p| [[:error], [:to], [:from]].include? p }
        
        id_set = false 
        translation_keys.each do |p|
          v = strategy.strategy_hash[*p]
          
          type, op_field = *p 
          next if op_field == :error
          
          if op_field.is_a? Regexp
            model = type == :from ? :from_source : :to_source
            op_fields = strategy.send(model).keys.select { |vo| op_field.match vo}
          elsif op_field.is_a? Array
            op_fields.concat op_field
          else
            op_fields = [op_field]
          end
          
          
          op_fields.collect do |field|

            action = Action.new

            o_field = ([CopyTranslationAction.instance, DiscardTranslationAction.instance].include? v) ? field : v

            if type == :from
              action.destination_field = o_field.to_s
              action.source_field = field.to_s
              action.proc_macro = lambda do |proc_field, prok|
                destination[proc_field.to_s] = prok.call(source[action.source_field.intern])
              end
            elsif type == :to
              action.destination_field = field.to_s
              action.source_field = o_field.to_s
              action.proc_macro = lambda do |proc_field, prok|
                destination[action.destination_field] = prok.call(source[proc_field.intern])
              end
            end
            action.value = v
           
            # this is basically executed for it's side effects.
            begin
              process_field!(action)
            rescue StandardError => e
              error_loc = strategy.strategy_hash[type][op_field]
              if error_loc.respond_to? :has_key? and error_loc.has_key? :error
                destination[action.destination_field] = strategy.instance_exec e, &error_loc[:error]
              else
                raise e
              end
            end
          end
        end
      end

      def update_progress was_success, error = nil
        self.changed
        @progress ||= {
          :successful => 0,
          :seen => 0,
          :error_count => 0,
          :source_percent => 0.0,
          :dest_percent => 0.0,
          :last_error => ''
        }
        
        @progress[:success] = was_success
        @progress[:successful] += 1 if was_success 
        @progress[:seen] += 1
        @progress[:dest_percent] = strategy.to_source.progress
        @progress[:source_percent] = strategy.from_source.progress
        if error
          @progress[:last_error] = error
          @progress[:error_count] += 1
        end

        self.notify_observers(self)
      end
    
      def translate validate = nil
        self.each.with_index do |(s,d),i|
          # we don't actually need to pass
          # s,d here, since they're available
          # as accessor source, destination
          begin
            translate_item
            if validate and destination.respond_to? :valid?
              raise Datatron::RecordInvalid, destination unless destination.valid?
            end
            strategy.save
            update_progress(true)
          rescue StandardError => e
            if strategy.strategy_hash.has_key? :error
              strategy.instance_exec e, &strategy.strategy_hash[:error]
            else
              raise e
            end
            update_progress(false, e)
          end
        end
      end
    end

    class << self
      
      def with_strategy strat, force_new = false
        klass_name = strat.name.to_s.singularize.camelize + "Translator"
        if const_defined? klass_name and not force_new
          return const_get(klass_name).new
        end
        
        klass = Class.new(self) do |this|
          include Observable
          
          class << self
            attr_accessor :strategy
          end

          include StrategyInterface
          this.strategy = strat.clone
          this.strategy.extend DataInterface
          
          attr_reader :source, :destination, :strategy, :implicit_keys
          attr_reader :progress

          def initialize
            @strategy = self.class.strategy
            @strategy.translator = self
            
            if ((@strategy.strategy_hash.branches(:from).collect {|k,v| k }.map(&:to_s) & @strategy.from_source.keys).empty? and
               (@strategy.strategy_hash.branches(:to).collect {|k,v| k }.map(&:to_s) & @strategy.to_source.keys).empty?) then
               raise Datatron::StrategyError, "Could not find any common keys between strategy and model."
            end
 
            @implicit_keys = @strategy.to_source.keys.reject do |dk|
              @strategy.strategy_hash.find do |v|
                p = v.path
                break true if [:to, :from].include? p[0] and p[1].to_s == dk.to_s
                break true if v.is_a? Hash and v.keys.first.to_s == dk
                break true if v.to_s == dk
              end
            end.collect { |k| [:to, k.intern] }

          end

          def items 
            begin
              @source = self.strategy.next
              @destination = self.strategy.new
            rescue StopIteration => e
              self.rewind 
              raise e
            rescue StandardError => e
              if strategy.strategy_hash.has_key? :error
                strategy.instance_exec e, &strategy.strategy_hash[:error]
              else
                raise e
              end
              update_progress(false,e)
              retry
            end
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
        const_set((klass.strategy.name.to_s.singularize.camelize + "Translator").intern, klass)
        klass.new
      end
    end
  end
end

