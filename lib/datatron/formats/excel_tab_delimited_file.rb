module Datatron
  module Formats 
    class ExcelTabDelimitedFile < TabDelimitedFile
      class << self
        def from filename, class_name = nil
          super filename, class_name, "\r"
        end
      end
    end
  end
end
