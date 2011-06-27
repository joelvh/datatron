module Datatron
  module ActiveRecordTransform
    attr_accessor :data_row, :strategy, :ar_item

    def translate
      #the basic principle here is that the Translator
      # asks the "Transform" what to do with each key?
      # where do I get the information for this attribute?
      # The transform ansers "get it from here"
      # Or "get it from the column of the samn name"
      # Or "get it from X but run it through this function
      # first
      # Or "Just tell the record item you'd like it populated."
      # or "Different step - ask for it to be done."
      debugger
      1
      ar_item.attribute_names.each do |k|
        source_key = strategy.transform k
        case source_key
          when String
            ar_item.attributes[k] = data_row[source_key]
          when Hash
            ar_item.attributes[k] = source_key.to_a 
          when TrueClass
            ar_item.attributes[k] = data_row[k]
          when FalseClass
            #do nothing
          when Proc
            ar_item.attributes[k] = source_key[data_row[k]]
          when UsingTranslationAction
            # do this one next, but wrap it in the same transaction
            # and 
            debugger
            1
        end
      end
    end

    def translate!
      translate
      if ar_item.valid?
        ar_item.save!
      else
        raise ActiveRecord::RecordInvalid, ar_item 
      end
    end

  end
end
