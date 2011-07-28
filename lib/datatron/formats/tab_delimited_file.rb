require 'thread'

module Datatron
  module Formats
    class TabDelimitedFile < Datatron::Format
      module TabFileMethods
        def save
          semaphore = Mutex.new
          semaphore.synchronize do
            File.open(self.class.fd,'a+') do |f|
              f.print values.join("\t")
              f << self.class.seperator
            end
          end
        end

        def initialize obj = nil
          __setobj__(obj || HashWithIndifferentAcess[self.class.keys.zip([])])
        end
      end
    end
  end
end
        

module Datatron
  module Formats
    class TabDelimitedFile < Datatron::Format
      class << self
        def from filename, seperator = "\n"
          filename = "data/#{filename}.txt"
          raise DataSourceNotFound, "No such file or directory #{filename}" unless File.exists? filename

          class_name = filename.split(/\/|\./)[-2] #last elements without the extension
          data_class class_name do |c|
            
            c.send :include, TabFileMethods
            @seperator = seperator
            
            define_singleton_method :fd do
              @fd ||= File.open(filename)
            end

            c.data_source = @fd

            class << c
              attr_accessor :seperator

              def keys
                return @keys if @keys
                fd.rewind if fd.lineno != 0
                @keys = fd.readline(self.seperator).chomp.split("\t",-1)
              end

              def each
                return enum_for(:each) unless block_given?
                fd.readlines(self.seperator).each do |l|
                  vals = l.chomp.split("\t",-1)
                  next if vals == keys
                  obj = HashWithIndifferentAccess[self.keys.map(&:intern).zip(vals)]
                  yield self.new(obj)
                end
              end

              def rewind
                fd.rewind
                super
              end

              def _finder *args, &block
                rewind do
                  self.data = Enumerator.new do |y|
                    self.each do |row|
                      r = block.call(row, *args)
                      y << r if r
                    end
                  end
                end
              end
              private :_finder

              def find all = :first, &block
                return enum_for(:_find) unless block_given?
                if all == :first
                  memo = _finder(block).next
                  rewind
                else
                  memo = _finder(block).to_a
                end
                return memo.empty? ? nil : memo
              end
            end
          end
        end
      end
    end
  end
end

