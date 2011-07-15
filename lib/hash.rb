class Hash
 def path val = nil, key_path = [], &block
    raise ArgumentError, "search value or block required" if block.nil? and val.nil?
    self.each do |k,v|
      if (yield v unless block.nil?) or v == val
        key_path << k
        break
      elsif v.respond_to? :path
        if v.path(val, key_path, &block)
          key_path.unshift(k)
          break
        end
      end
    end
    return false if key_path.empty?
    key_path
  end
end
