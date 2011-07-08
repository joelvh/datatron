module Datatron
  class Transform
    def self.const_missing const
      Datatron::Formats.const_get const
    end

    include TransformMethods

    module FuzzyInclude
      def fuzzy_include? v
        self.detect { |p| p === v}
      end
    end

    attr_accessor :finder

    def initialize strategy, *args, &block 
      strat = self.class.strategies[strategy]
      options = (args.pop if args.last.is_a? Hash) || {}
      @current = :ready
      @strategy_hash = HashWithIndifferentAccess.new(:from => {}, :to => {}) 

      init_blocks = [strat[:block]]
      init_blocks << block unless block.nil?
      init_blocks.each do |b|
        instance_exec args.slice(0,b.arity), &b
      end

      options.reverse_merge!({:to => @to_source, 
                              :keys => :keys,
                              :from => @from_source,
                              :from_keys => :keys})


      [:to, :from].each do |op|
        model, source = ["model","source"].collect { |s| "#{op}_#{s}".intern }
        unless(options[op] == __send__(source)) then
          __send__ source, options[op]
          unless __send__ source
            raise ArgumentError, "Couldn't find #{model} subclass for #{self.class}"
          end
        end
      end
  
      #remove the DSL state tracking variables
      [:@current, :@current_field].each do |i|
        remove_instance_variable i
      end
    end

    def modify *args, &block
      @current = :ready
      instance_exec args.slice(0,block.arity), &block
      remove_instance_variable :@current
    end

    def transform key
      if (path = path_for_key(key))
        type, location = path
        return lookup[type][location]
      elsif implicit_keys.include? key
        return true
      elsif inferred_keys.include? key
        return lookup[:to][location]
      elsif all_keys.include? key
        # we are aware of the key and want to do nothing withit.
        return false
      else
        raise TranslationKeyError, "Don't know anything about #{key}" 
      end
    end
    
    def all_keys
      #all key values that I know how do something with.
      @origin_fields | @destination_fields 
    end

    private
    def lookup
      return @lookup if @lookup
      @lookup = @strategy_hash.each_pair.each_with_object({}) do |(k,v), memo|
        unless k == :to
          memo[k] = v 
        else
          memo[k] = v.each_pair.collect { |i| i.last.is_a?(String) ? i.reverse : i }
        end
      end
    end

    def path_for_key key
      if (location = to_field.fuzzy_include?(key))
        return :to, location
      elsif (location = from_field.fuzzy_include?(key)) 
        return :from, location 
      end
      false
    end
    
    #keys where you say 'to this field from this other field'
    #ie, you specifiy the from field precisiely
    def to_field
      return @to_fields if @to_fields
      @to_fields = @strategy_hash[:to].values.collect do |v|
        next v if String === v
        next v.keys.first if Hash === v
        nil
      end.compact
      @to_fields.extend FuzzyInclude
      @to_fields
    end
    
    #keys where you say 'from this field to this other field'
    #generally when you specifiy the from field less precisely
    def from_field
      return @from_keys if @from_keys
      @from_keys = @strategy_hash[:from].keys
      @from_keys.extend FuzzyInclude
      @from_keys
    end

    #keys where you know how to created it, even if there's
    #no data field in the import file
    def inferred_keys 
      return @unspecified_keys if @unspecified_keyt
      @unspecificed_keys = @destination_fields.reject do |v|
        @origin_fields.any? { |ak| ak === v } && to_fields.any? { |kp| kp == v }
      end
    end

    #keys which are implicitly converted from tab delimted column to AR attribute
    #like "name" data field to "name" data field
    def implicit_keys
      return @implicit_keys if @implicit_keys
      @implicit_keys = all_keys.reject do |v|
       from_field.any? { |kp| kp === v } || to_field.values.any? { |kp| kp === v }
      end
    end
   
    def self.transition_valid? from, to
      unless @transition_table
        @transition_table = {  
          :ready => [:to, :from],
          :to => [:from, :through, :using, :ready],
          :from => [:to, :through, :ready]
        }
        @transition_table.default = [:ready]
      end
        
      @transition_table[from].include?(to) ? true : false
    end
  end
end
