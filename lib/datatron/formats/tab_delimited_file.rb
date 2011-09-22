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
        def from filename, class_name = nil, seperator = "\n"
          filename << ".txt" unless filename =~ /.\.[a-z]+$/
          filename = Datatron.path ? "#{Datatron.path}/#{filename}" : "#{filename}"

          class_name = filename.split(/\/|\./)[-2] unless class_name

          raise DataSourceNotFound, "No such file or directory #{filename}" unless File.exists? filename

          data_class class_name do |c|
            
            c.send :include, TabFileMethods
            @seperator = seperator
            
            define_singleton_method :fd do
              @fd ||= File.open(filename)
            end

            c.data_source = @fd

            class << c
              attr_accessor :seperator

              def fields line
                line.chomp.split("\t",-1)
              end

              def progress
                @size ||= fd.size 
                fd.pos.fdiv(@size) rescue (0.0 / 0.0) #Nan
              end

              def keys
                return @keys if @keys
                fd.rewind if fd.lineno != 0
                @keys = fields(fd.readline(self.seperator))
              end

              def each
                return enum_for(:each) unless block_given?
                fd.lines(self.seperator) do |l|
                  vals = fields(l) 
                  next if vals == keys
                  obj = HashWithIndifferentAccess[self.keys.zip(vals)]
                  yield self.new(obj)
                end
              end

              def rewind
                fd.rewind
                super
                fd.rewind
              end
            end
          end
        end
      end
    end
  end
end

