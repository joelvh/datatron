require 'delegate'
require 'securerandom'

class OrderTree < Delegator
  class UniqueProxy < BasicObject
    def initialize obj
      @obj = obj
    end

    def unique_id
      @uuid ||= ::SecureRandom.uuid
    end

    def equal? other
      (@uuid == other.unique_id) rescue false
    end

    def method_missing(method, *args, &block)
      @obj.__send__ method, *args, &block
    end
    
    def !
      !@obj
    end

    def == arg
      @obj == arg
    end

    def != arg
      @obj != arg
    end

    def orig
      @obj
    end
  end
    
  class OrderStore < Array 
    attr_accessor :root
    def initialize(hash_obj)
      @root = hash_obj
    end

    def to_s
      "#<#{self.class}:#{'0x%x' % self.__id__ << 1}>"
    end
  end

  def initialize(constructor = {}, order = nil) 
    @delegate_hash = {} 
    super(@delegate_hash)
    @order = order || OrderStore.new(self)
    constructor.each_with_object(self) do |(k,v),memo|
      memo[k] = v
    end
  end
 
  def each
    return enum_for(:each) unless block_given? 
    @order.each do |v|
      yield [root.path(v), v.orig]
    end
  end

  def order
    each.to_a
  end

  def strict_path val = nil
    __path val, true
  end

  def path val = nil, &block
    __path val, false, [], &block
  end

  def __path val = nil, strict = false, key_path = [], &block
    op = strict ? :equal? : :==
    return true if (yield(val) unless block.nil?) or val == self
    @delegate_hash.each do |k,v|
      if (yield v unless block.nil?) or v.__send__ op, val
        key_path << k 
        break
      elsif v.respond_to? :path
        if v.__path(val, strict, key_path, &block) != @order.root.default
          key_path.unshift(k)
          break
        end
      end
    end
    return @order.root.default if key_path.empty?
    key_path
  end
  private :__path
  
  def root
    @order.root
  end

  def __getobj__
    @delegate_hash
  end

  def __setobj__(obj)
    @delegate_hash = obj
  end

  def to_s
    "#<#{self.class}:#{'0x%x' % self.__id__ << 1}>"
  end

  def at *args
    t = @delegate_hash 
    begin
      args.each do |a|
        t = t[a]
      end
    rescue NoMethodError => e
      if e.method == :[] 
        return @order.root.default
      end
    end
    t
  end

  def == other
    other.order == self.order
  end

  def [] *args
    t = self[*args]
    if t == @order.root.default
      @order.root.default
    else
      t.orig
    end
  end

  def []= key, value
    if value.kind_of? Hash or value.kind_of? OrderTree
      value = OrderTree.new(value, @order)
    end
    @delegate_hash[key] = UniqueProxy.new(value)
    
    puts "insertion of '#{value}' in #{self.to_s} -> #{@order.to_s} (id #{@delegate_hash[key].unique_id})"
    @order << @delegate_hash[key]
    value
  end
end

testhash = {
  :from => {
    :a => {
      :b => 4,
      :c => 4,
    }
  },
  :to => {
    :d => 4,
    :e => 4,
    :to_to => {
      :f => 4,
      :g => 4,
      :h => 4,
    }
  }
}

#testhash.order == [:from], [:from, :a], [:from,:a,:b], [:from, :a,:c]
#                  [:to], [:to,:d], [:to,:e], [:to, :to_to],
#                  [:to,:to_to,:f], [:to,:to_to,:g], [:to, :to_to, :h]

