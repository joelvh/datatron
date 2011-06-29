class Datatron
  module Sources
    class TabDelimitedFile
      class << self
        def for_file filename, seperator = "\n"
          klass = Class.new(self) do |c|
            @seperator = seperator
            
            define_singleton_method :fd do
              @fd ||= File.open(filename)
            end

            class << c
              attr_accessor :seperator
              def keys 
                return @keys if @keys
                fd.rewind if fd.lineno != 0
                @keys = fd.readline(self.seperator).chomp.split("\t",-1)
              end

              def next_row
                @data ||= Enumerator.new do |y|
                  fd.readlines(self.seperator).each do |l|
                    vals = l.chomp.split("\t",-1)
                    next if vals == keys
                    obj = Hash[self.keys.zip(vals)]
                    y.yield HashWithIndifferentAccess.new obj
                  end
                end
                @data.next
              end

              def find &block
                @data = nil
                fd.rewind

                found = loop do
                  data = self.next_row
                  break data if block.call(data)
                end
                found

              ensure
                @data = nil
                fd.rewind
              end
              
              alias_method :column_names, :keys
            end

            def initialize
              @data = Hash[self.class.keys.zip([])] 
            end
          end
        end
        Datatron::Sources.const_set filename.camelize.intern, klass
      end
      undef :initialize
    end
  end
end

