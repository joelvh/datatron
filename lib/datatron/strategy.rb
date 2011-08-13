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

    def next 
      return @source_enumerator.next if @source_enumerator
      if @finder
        args, finder_proc = @finder
        @source_enumerator = _finder *args, &finder_proc
      else
        @source_enumerator = self.from_source
      end
      # and one more time for the ladies!
      @source_enumerator.next
    end

    def save
      if @router
        args, router_proc = @router
        args = [self.destination].concat args[0..router_proc.arity - 1]
        self.instance_exec *args, &router_proc
      else
        self.destination.save
      end
    end

    def new
      self.to_source.new
    end

    private
    def _finder *args, &block
      self.from_source.rewind
      Enumerator.new do |y|
        self.from_source.each do |row|
          r = block.call(row, *args)
          y << row if r
        end
      end
    end

    def _router *args, &block
      this = self
      args, router_proc = @router
      self.destination.define_singleton_method :save do
        args = [this.destination].concat args[0 .. router_proc.arity - 1]
        this.instance_exec *args, &router_proc
      end
    end
  end
end
