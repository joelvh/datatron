module Datatron
  module Formats 
    class ExcelTabDelimitedFile < TabDelimitedFile
      class << self
        def for filename
          super filename, "\r"
        end
      end
    end
  end
end
