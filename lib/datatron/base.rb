module Datatron
  class Source 
    class << self
      [:keys, :next_row, :find].map do |meth|
        define_method(meth) { raise NotImplementedError, "Abstract class" }
      end
      alias :column_names :keys
    end
    undef :initialize
  end

  class Destination
    class << self
      [:keys, :next_row, :find].map do |meth|
        define_method(meth) { raise NotImplementedError, "Abstract class" }
    undef :initialize
  end
end
