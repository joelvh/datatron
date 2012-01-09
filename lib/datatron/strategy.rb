module Datatron
  class Strategy 
    include Datatron::TransformDSL

    class << self
      def === obj
        obj.kind_of? self
      end
    end
    
    attr_accessor :strategy_hash
    
    def initialize strategy, *args, &block
      @strategy_hash = OrderTree::OrderTree.new( {:from => {}, :to => {}} )
      super
    end

    # retrieve the next source record
    # if there is a +find+ block specified in the strategy, then
    # call the find block for each record, executing the strategy if the block
    # returns true or an instance of the source class is returned.
    def next
      if @finder
        self.from_source.data ||= Enumerator.new do |y|
          args, finder_proc = @finder
          self.from_source.each do |row|
            args = [row].concat args[0 .. (finder_proc.arity - 1)]
            r = self.instance_exec *args, &finder_proc
            y.yield(case r
              when FalseClass, NilClass then next
              when self.from_source then r 
              else row
            end)
            break if r and args.include? :first
          end
        end
      end    
      self.from_source.next
    end

    # save the current destination record. 
    # if there is a +route+ block specified in the strategy, then
    # execute the block, which should call save, etc.
    def save
      if @router
        args, router_proc = @router
        args = [self.destination].concat args[0 .. (router_proc.arity - 1)]
        self.instance_exec *args, &router_proc
      else
        self.destination.save
      end
    end

    #custom validation block for the destionation
    def valid?
      if @validator
        args, validator_proc = @validator
        args = [self.destination].concat args[0 .. (validator_proc.arity - 1)]
        self.instance_exec *args, &validator_proc
      else
        self.destination.valid?
      end
    end

    # create a new destination record
    # if there is an +append+ block specified in the strategy,
    # then use the record returned by that block as the the
    # destination.
    def new
      if @appender
        args, appender_proc = @appender
        args = [self.destination].concat args[0 .. (appender_proc.arity - 1)]
        self.instance_exec *args, &appender_proc
      else
        self.to_source.new
      end
    end
  end
end
