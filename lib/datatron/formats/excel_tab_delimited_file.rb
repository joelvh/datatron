module Datatron
  module Formats 
    class ExcelTabDelimitedFile < TabDelimitedFile
      class << self
        def new filename
          super filename, "\r"
        end
      end
    end
  end
end
