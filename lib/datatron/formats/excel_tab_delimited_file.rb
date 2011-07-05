module Datatron
  module Formats 
    class ExcelTabDelimitedFile
      class << self
        def for_file filename
          TabDelimtedFile.for_file filename, "\r"
        end
      end
    end
  end
end
